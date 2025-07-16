using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System.Net;
using System.Net.Http.Headers;
using System.Text;

namespace HolyCheeseAzdoTools.TagTools
{
    /// <summary>
    /// Handles low-level HTTP operations for retrieving and updating tags on Azure DevOps work items.
    /// </summary>
    public class TagDataProvider : ITagDataProvider
    {
        private readonly HttpClient _client;
        private readonly ILogger _log;
        private readonly string _org;

        /// <summary>
        /// Initializes the TagDataProvider with HTTP authentication and diagnostic logging.
        /// </summary>
        public TagDataProvider(HttpClient client, ILoggerFactory loggerFactory, string org, string pat)
        {
            _client = client;
            _org = org;
            _log = loggerFactory.CreateLogger("TagDataProvider");

            // Configure basic authentication using a PAT (Personal Access Token)
            _client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
                "Basic", Convert.ToBase64String(Encoding.ASCII.GetBytes($":{pat}"))
            );
        }

        /// <summary>
        /// Fetches existing tags on a given work item and indicates whether the System.Tags field is present.
        /// </summary>
        public async Task<(string[] Tags, bool HasTagsField)> GetExistingTags(int workItemId)
        {
            var url = GetWorkItemUrl(workItemId);
            var response = await _client.GetAsync(url);
            await EnsureSuccessOrThrow(response, "fetch", workItemId);

            var content = await response.Content.ReadAsStringAsync();
            dynamic? item = null;

            try
            {
                item = JsonConvert.DeserializeObject(content);
            }
            catch (JsonException ex)
            {
                // If the response content is malformed or unparseable, treat this as a soft failure.
                // Returning an empty result allows the system to recover gracefully from transient or schema drift issues.
                LogJsonError("fetch", workItemId, ex.Message);
                return (Array.Empty<string>(), false);
            }

            // Check whether fields exist and determine tag presence
            if (item?.fields == null)
            {
                // If the parsed JSON lacks expected structure (e.g., missing 'fields'), treat this as a hard failure.
                // Throwing ensures contract violations or unexpected API responses aren't silently ignored.
                _log.LogWarning("Work item {WorkItemId} fetch failed — fields missing.", workItemId);
                throw new HttpRequestException($"Work item {workItemId} fetch failed: {(int)response.StatusCode} {response.StatusCode}");
            }

            bool hasTagsField = item.fields["System.Tags"] != null;
            string rawTags = hasTagsField ? item.fields["System.Tags"]?.ToString() ?? "" : "";

            var tags = rawTags.Split(';')
                .Select(t => t.Trim())
                .Where(t => !string.IsNullOrWhiteSpace(t))
                .ToArray();

            return (tags, hasTagsField);
        }

        /// <summary>
        /// Sends a PATCH request to update the System.Tags field on a work item.
        /// </summary>
        public async Task PatchTags(int workItemId, string[] tags, bool hasTagsField)
        {
            var content = CreateTagPatchContent(tags, hasTagsField);
            var url = GetWorkItemUrl(workItemId);
            var response = await _client.PatchAsync(url, content);
            var responseText = await response.Content.ReadAsStringAsync();

            if (response.IsSuccessStatusCode)
            {
                _log.LogDebug("Work item {WorkItemId} patched successfully with tags: {Tags}", workItemId, string.Join(", ", tags));
            }
            else
            {
                _log.LogWarning("Work item {WorkItemId} patch failed. Status: {StatusCode}. Response: {Response}", workItemId, response.StatusCode, responseText);
                throw new HttpRequestException($"Work item {workItemId} patch failed: {response.StatusCode}");
            }
        }

        /// <summary>
        /// Centralized error handler for non-success HTTP responses.
        /// Logs the error and throws an HttpRequestException.
        /// </summary>
        private async Task EnsureSuccessOrThrow(HttpResponseMessage response, string operation, int workItemId)
        {
            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadAsStringAsync();
                LogRequestFailure(operation, workItemId, response.StatusCode, error);
                throw new HttpRequestException($"Work item {workItemId} {operation} failed: {response.StatusCode}");
            }
        }

        /// <summary>
        /// Logs a consistent error message for failed HTTP interactions.
        /// </summary>
        private void LogRequestFailure(string operation, int workItemId, HttpStatusCode statusCode, string response)
        {
            _log.LogError("Work item {WorkItemId} {Operation} failed. Status: {StatusCode}. Response: {Response}",
                workItemId, operation, statusCode, response);
        }

        /// <summary>
        /// Logs structured warning message when deserialization fails.
        /// </summary>
        private void LogJsonError(string operation, int workItemId, string errorMessage)
        {
            _log.LogWarning("Work item {WorkItemId} {Operation} JSON error. Message: {ErrorMessage}",
                workItemId, operation, errorMessage);
        }

        /// <summary>
        /// Builds a consistent work item API URL using org name and ID.
        /// </summary>
        private string GetWorkItemUrl(int workItemId)
            => $"https://dev.azure.com/{_org}/_apis/wit/workitems/{workItemId}?api-version=7.0";

        /// <summary>
        /// Builds the PATCH content for System.Tags update using JSON Patch format.
        /// </summary>
        private static StringContent CreateTagPatchContent(string[] tags, bool hasTagsField)
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

            return new StringContent(
                JsonConvert.SerializeObject(patch),
                Encoding.UTF8,
                "application/json-patch+json"
            );
        }
    }
}
