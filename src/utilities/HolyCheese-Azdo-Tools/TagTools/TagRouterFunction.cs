using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using HttpTriggerAttribute = Microsoft.Azure.Functions.Worker.HttpTriggerAttribute;

namespace HolyCheese_Azdo_Tools.TagTools
{
    /// <summary>
    /// Azure Function that routes tag actions via /TagOps/{action} using strategy handlers.
    /// </summary>
    public static class TagRouterFunction
    {
        [FunctionName("TagRouter")]
        public static async Task<HttpResponseMessage> Run(
            [HttpTrigger("post", Route = "TagOps/{action}")] HttpRequestMessage req,
            string action,
            ILoggerFactory loggerFactory)
        {
            // Initialize utility helper class with shared logger and HttpClient
            using var httpClient = new HttpClient();
            var tools = new Azdo_Tools_Helper(loggerFactory, httpClient);

            // Extract work item ID and tag from POST body
            if (req is null || req.Content == null)
            {
                return req.CreateResponse(System.Net.HttpStatusCode.BadRequest,
                    "Request body cannot be null or empty.");
            }

            var body = await req.Content.ReadAsStringAsync();

            if (string.IsNullOrWhiteSpace(body))
            {
                return req.CreateResponse(System.Net.HttpStatusCode.BadRequest,
                    "Request body cannot be null or empty.");
            }

            dynamic? data = JsonConvert.DeserializeObject(body);
            if (data == null)
            {
                return req.CreateResponse(System.Net.HttpStatusCode.BadRequest,
                    "Invalid JSON in request body.");
            }

            int workItemId = data?.workItemId ?? 0;
            string tag = (data?.tag ?? "").ToString().Trim();

            // Validate required inputs
            if (workItemId <= 0 || string.IsNullOrEmpty(tag))
            {
                return req.CreateResponse(System.Net.HttpStatusCode.BadRequest,
                    "Invalid work item ID or tag.");
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
                return req.CreateResponse(System.Net.HttpStatusCode.BadRequest,
                    $"Unsupported action '{action}'. Use 'add' or 'remove'.");
            }

            // Execute tag operation and return result
            return await handler.ExecuteAsync(req, workItemId, tag);
        }
    }
}
