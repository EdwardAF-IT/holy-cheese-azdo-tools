using Azure;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System.Net.Http.Headers;
using System.Text;

namespace HolyCheese_Azdo_Tools.TagTools
{
    /// <summary>
    /// Low-level implementation of ITagDataProvider that interacts with Azure DevOps API.
    /// Responsible for fetching and updating tags on work items.
    /// </summary>
    public class TagDataProvider : ITagDataProvider
    {
        private readonly HttpClient _client;
        private readonly ILogger _log;
        private readonly string _org;

        /// <summary>
        /// Sets up HttpClient with authorization and injects required dependencies.
        /// </summary>
        public TagDataProvider(HttpClient client, ILoggerFactory loggerFactory, string org, string pat)
        {
            _log = loggerFactory.CreateLogger("TagDataProvider");
            _org = org;
            _client = client;
            _client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
                "Basic", Convert.ToBase64String(Encoding.ASCII.GetBytes($":{pat}"))
            );
        }

        /// <summary>
        /// Retrieves current tags for the specified Azure DevOps work item.
        /// Handles HTTP errors and deserialization issues gracefully.
        /// </summary>
        public async Task<(string[] Tags, bool HasTagsField)> GetExistingTags(int workItemId)
        {
            // Construct Azure DevOps URL for the target work item
            var url = $"https://dev.azure.com/{_org}/_apis/wit/workitems/{workItemId}?api-version=7.0";

            // Make HTTP GET request to fetch the work item's metadata
            var response = await _client.GetAsync(url);

            // Handle non-successful responses (e.g., 404, 401, 500)
            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadAsStringAsync();
                _log.LogError($"Failed to fetch work item {workItemId}. Status: {response.StatusCode}. Response: {error}");
                throw new HttpRequestException($"Failed to fetch work item {workItemId}: {response.StatusCode}");
            }

            // Read the JSON payload returned from Azure DevOps
            var content = await response.Content.ReadAsStringAsync();

            dynamic? item = null;

            // Safely attempt to deserialize the payload into a dynamic object
            try
            {
                item = JsonConvert.DeserializeObject(content);
            }
            catch (JsonException ex)
            {
                // If deserialization fails (e.g., malformed JSON), log and return empty results
                _log.LogWarning($"Deserialization failed for work item {workItemId}: {ex.Message}");
                return (Array.Empty<string>(), false);
            }

            // If deserialization succeeded but required fields are missing, fallback gracefully
            if (item == null || item?.fields == null)
            {
                _log.LogWarning($"Work item {workItemId} does not contain expected fields.");
                return (Array.Empty<string>(), false);
            }

            // Determine if System.Tags field is available in the work item
            bool hasTagsField = item?.fields["System.Tags"] != null;

            // If present, extract the tag string and sanitize it; else use an empty string
            string tagString = hasTagsField ? item?.fields["System.Tags"].ToString() ?? "" : "";

            // Split tags by semicolon, trim each, and filter out empties
            var tags = tagString.Split(';')
                .Select(t => t.Trim())
                .Where(t => !string.IsNullOrEmpty(t))
                .ToArray();

            // Return parsed tag array and availability indicator
            return (tags, hasTagsField);
        }

        /// <summary>
        /// Applies updated tags to a work item using PATCH semantics.
        /// </summary>
        public async Task PatchTags(int workItemId, string[] tags, bool hasTagsField)
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

            if (!result.IsSuccessStatusCode)
            {
                var error = await result.Content.ReadAsStringAsync();
                _log.LogError($"Failed to patch work item {workItemId}. Status: {result.StatusCode}. Response: {error}");
                throw new HttpRequestException($"Patch failed for work item {workItemId}: {result.StatusCode}");
            }

            if (result.IsSuccessStatusCode)
                _log.LogDebug($"Work item {workItemId}: Tags updated to [{string.Join(", ", tags)}].");
            else
                _log.LogWarning($"Work item {workItemId}: Failed to update tags. Status {result.StatusCode}. Response: {await result.Content.ReadAsStringAsync()}");
        }
    }
}
