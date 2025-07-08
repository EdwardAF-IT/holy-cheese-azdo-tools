using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;
using System.Linq;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace HolyCheese_Azdo_Tools.TagTools
{
    /// <summary>
    /// Encapsulates logic for fetching and updating Azure DevOps tags on work items.
    /// </summary>
    public class Azdo_Tools_Helper
    {
        private readonly ILogger _log;
        private readonly HttpClient _client;
        private readonly string _org;
        private readonly string _pat;

        /// <summary>
        /// Initializes shared resources: logger, organization details, and HTTP client.
        /// </summary>
        public Azdo_Tools_Helper(ILoggerFactory loggerFactory, HttpClient client)
        {
            _log = loggerFactory.CreateLogger("Azdo_Tools_Helper");

            // Initialize _org and _pat directly from environment variables
            _org = Environment.GetEnvironmentVariable("DevOpsOrgName")
                ?? throw new InvalidOperationException("DevOpsOrgName environment variable is not set in Key Vault.");
            _pat = Environment.GetEnvironmentVariable("DevOpsPAT")
                ?? throw new InvalidOperationException("DevOpsPAT environment variable is not set in Key Vault.");

            _client = client ?? throw new ArgumentNullException(nameof(client));
            _client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
                "Basic", Convert.ToBase64String(Encoding.ASCII.GetBytes($":{_pat}"))
            );
        }

        /// <summary>
        /// Retrieves current tags on a work item.
        /// </summary>
        private async Task<(string[] tags, bool hasTagsField)> GetExistingTags(int workItemId)
        {
            var url = $"https://dev.azure.com/{_org}/_apis/wit/workitems/{workItemId}?api-version=7.0";
            var response = await _client.GetAsync(url);
            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadAsStringAsync();
                _log.LogError($"Failed to fetch work item {workItemId}. Status: {response.StatusCode}. Response: {error}");
                throw new HttpRequestException($"Failed to fetch work item {workItemId}: {response.StatusCode}");
            }

            var content = await response.Content.ReadAsStringAsync();
            dynamic? item = JsonConvert.DeserializeObject(content);

            // Ensure item and fields are not null before accessing them
            if (item == null || item?.fields == null)
            {
                _log.LogWarning($"Work item {workItemId} does not contain expected fields.");
                return (Array.Empty<string>(), false);
            }

            bool hasTagsField = item?.fields["System.Tags"] != null;
            string tagString = hasTagsField ? item?.fields["System.Tags"].ToString() ?? "" : "";

            var tags = tagString
                .Split(';')
                .Select(t => t.Trim())
                .Where(t => !string.IsNullOrEmpty(t))
                .ToArray();

            return (tags, hasTagsField);
        }

        /// <summary>
        /// Updates the tag field of a work item using PATCH operation.
        /// </summary>
        private async Task PatchTags(int workItemId, string[] tags, bool hasTagsField)
        {
            var patch = new[]
            {
                new
                {
                    op = hasTagsField ? "replace" : "add",
                    path = "/fields/System.Tags",
                    value = string.Join(";", tags)
                }
            };

            var content = new StringContent(JsonConvert.SerializeObject(patch), Encoding.UTF8, "application/json-patch+json");
            var url = $"https://dev.azure.com/{_org}/_apis/wit/workitems/{workItemId}?api-version=7.0";
            var result = await _client.PatchAsync(url, content);

            if (result.IsSuccessStatusCode)
                _log.LogDebug($"Work item {workItemId}: Tags updated to [{string.Join(", ", tags)}].");
            else
                _log.LogWarning($"Work item {workItemId}: Failed to update tags. Status {result.StatusCode}. Response: {await result.Content.ReadAsStringAsync()}");
        }

        /// <summary>
        /// Adds a tag to a work item, avoiding case-insensitive duplicates.
        /// Returns null on success, or an error message string on failure.
        /// </summary>
        public async Task<string?> AddTag(int workItemId, string tag)
        {
            try
            {
                var (tags, hasTagsField) = await GetExistingTags(workItemId);

                if (tags.Any(t => t.Equals(tag, StringComparison.OrdinalIgnoreCase)))
                {
                    _log.LogDebug($"Work item {workItemId}: Tag '{tag}' already exists. No update.");
                    return null;
                }

                await PatchTags(workItemId, tags.Append(tag).ToArray(), hasTagsField);
                return null;
            }
            catch (HttpRequestException ex)
            {
                _log.LogError(ex, $"Error connecting to Azure DevOps while adding tag to work item {workItemId}.");
                return "Error connecting to Azure DevOps. Please check your network connection and credentials.";
            }
            catch (InvalidOperationException ex)
            {
                _log.LogError(ex, $"Work item {workItemId} not found or invalid operation while adding tag.");
                return $"Work item {workItemId} not found or invalid operation.";
            }
            catch (Exception ex)
            {
                _log.LogError(ex, $"Unexpected error while adding tag to work item {workItemId}.");
                return "An unexpected error occurred while adding the tag.";
            }
        }

        /// <summary>
        /// Removes a tag from a work item if it exists.
        /// Returns null on success, or an error message string on failure.
        /// </summary>
        public async Task<string?> RemoveTag(int workItemId, string tag)
        {
            try
            {
                var (tags, hasTagsField) = await GetExistingTags(workItemId);
                var updatedTags = tags
                    .Where(t => !t.Equals(tag, StringComparison.OrdinalIgnoreCase))
                    .ToArray();

                _log.LogDebug($"Work item {workItemId}: Attempting to remove tag '{tag}'.");
                await PatchTags(workItemId, updatedTags, hasTagsField);
                return null;
            }
            catch (HttpRequestException ex)
            {
                _log.LogError(ex, $"Error connecting to Azure DevOps while removing tag from work item {workItemId}.");
                return "Error connecting to Azure DevOps. Please check your network connection and credentials.";
            }
            catch (InvalidOperationException ex)
            {
                _log.LogError(ex, $"Work item {workItemId} not found or invalid operation while removing tag.");
                return $"Work item {workItemId} not found or invalid operation.";
            }
            catch (Exception ex)
            {
                _log.LogError(ex, $"Unexpected error while removing tag from work item {workItemId}.");
                return "An unexpected error occurred while removing the tag.";
            }
        }
    }
}