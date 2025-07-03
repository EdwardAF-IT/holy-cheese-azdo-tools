using Azure;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;

using HttpTriggerAttribute = Microsoft.Azure.Functions.Worker.HttpTriggerAttribute;

namespace HolyCheese_Azdo_Tools.TagTools
{
    /// <summary>
    /// Azure Function that routes tag actions via /TagOps/{action} using strategy handlers.
    /// </summary>
    public class TagRouterFunction
    {
        [Function("TagRouter")]
        public async Task<HttpResponseData> Run(
            [HttpTrigger("post", Route = "TagOps/{action}")] HttpRequestData req,
            string action,
            ILoggerFactory loggerFactory)
        {
            HttpResponseData response;
            try
            {
                // Initialize utility helper class with shared logger and HttpClient
                using var httpClient = new HttpClient();
                var tools = new Azdo_Tools_Helper(loggerFactory, httpClient);

                // Extract work item ID and tag from POST body
                if (req is null || req.Body == null)
                {
                    var badRequestResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badRequestResponse.WriteStringAsync("Request body cannot be null or empty.");
                    return badRequestResponse;
                }

                using var reader = new StreamReader(req.Body);
                var body = await reader.ReadToEndAsync();

                if (string.IsNullOrWhiteSpace(body))
                {
                    var badRequestResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badRequestResponse.WriteStringAsync("Request body cannot be null or empty.");
                    return badRequestResponse;
                }

                dynamic? data = JsonConvert.DeserializeObject(body);
                if (data == null)
                {
                    var badRequestResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badRequestResponse.WriteStringAsync("Invalid JSON in request body.");
                    return badRequestResponse;
                }

                int workItemId = data?.workItemId ?? 0;
                string tag = (data?.tag ?? "").ToString().Trim();

                // Validate required inputs
                if (workItemId <= 0 || string.IsNullOrEmpty(tag))
                {
                    var badRequestResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badRequestResponse.WriteStringAsync("Invalid work item ID or tag.");
                    return badRequestResponse;
                }

                // Dynamically route to tag action handler
                ITagAction? handler = action?.ToLowerInvariant() switch
                {
                    "add" => new AddTagHandler(tools),
                    "remove" => new RemoveTagHandler(tools),
                    _ => null
                };

                // Return error if no valid handler found
                if (handler == null)
                {
                    var badRequestResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badRequestResponse.WriteStringAsync($"Unsupported action '{action}'. Use 'add' or 'remove'.");
                    return badRequestResponse;
                }

                // Convert HttpRequestData to HttpRequestMessage
                var httpRequestMessage = new HttpRequestMessage
                {
                    Method = new HttpMethod(req.Method),
                    RequestUri = req.Url,
                    Content = new StreamContent(req.Body)
                };

                foreach (var header in req.Headers)
                {
                    httpRequestMessage.Headers.TryAddWithoutValidation(header.Key, header.Value);
                }

                // Execute tag operation and return result
                var responseMessage = await handler.ExecuteAsync(httpRequestMessage, workItemId, tag);

                // Convert HttpResponseMessage to HttpResponseData
                var responseData = req.CreateResponse(responseMessage.StatusCode);
                foreach (var header in responseMessage.Headers)
                {
                    responseData.Headers.Add(header.Key, string.Join(",", header.Value));
                }

                if (responseMessage.Content != null)
                {
                    var content = await responseMessage.Content.ReadAsStringAsync();
                    await responseData.WriteStringAsync(content);
                }

                return responseData;
            }
            catch (Exception ex)
            {
                response = req.CreateResponse(HttpStatusCode.InternalServerError);
                await response.WriteStringAsync($"TagRouter failed: {ex.Message}");
                return response;
            }
        }
    }
}
