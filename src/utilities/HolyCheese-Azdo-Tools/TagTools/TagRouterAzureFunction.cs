using Azure;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.DependencyInjection;
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
    public class TagRouterAzureFunction
    {
        private readonly Azdo_Tools_Helper _tools;
        private readonly AddTagHandler _addHandler;
        private readonly RemoveTagHandler _removeHandler;

        public TagRouterAzureFunction(
            Azdo_Tools_Helper tools,
            AddTagHandler addHandler,
            RemoveTagHandler removeHandler)
        {
            _tools = tools;
            _addHandler = addHandler;
            _removeHandler = removeHandler;
        }

        [Function("TagRouter")]
        public async Task<HttpResponseData> Run(
            [HttpTrigger("post", Route = "TagOps/{action}")] HttpRequestData req,
            string action)
        {
            HttpResponseData response;
            try
            {
                var body = await ReadRequestBody(req);
                if (body == null)
                    return await CreateBadRequest(req, "Request body cannot be null or empty.");

                var data = DeserializeRequestBody(body);
                if (data == null)
                    return await CreateBadRequest(req, "Invalid JSON in request body.");

                int workItemId = ExtractWorkItemId(data);
                string tag = ExtractTag(data);
                if (!ValidateTagParams(workItemId, tag))
                    return await CreateBadRequest(req, "Invalid work item ID or tag.");

                var handler = GetHandler(action);
                if (handler == null)
                    return await CreateBadRequest(req, $"Unsupported action '{action}'. Use 'add' or 'remove'.");

                var azdoChangeTagMessage = CreateAzdoChangeTagMessage(req);

                var azdoChangeTagResponse = await handler.ExecuteAsync(azdoChangeTagMessage, workItemId, tag);

                return await SerializeResponseMessage(req, azdoChangeTagResponse);
            }
            catch (Exception ex)
            {
                response = req.CreateResponse(HttpStatusCode.InternalServerError);
                await response.WriteStringAsync($"TagRouter failed: {ex.Message}");
                return response;
            }
        }

        private async Task<string?> ReadRequestBody(HttpRequestData req)
        {
            if (req is null || req.Body == null)
                return null;

            using var reader = new StreamReader(req.Body);
            var body = await reader.ReadToEndAsync();
            return string.IsNullOrWhiteSpace(body) ? null : body;
        }

        private dynamic? DeserializeRequestBody(string body)
        {
            return JsonConvert.DeserializeObject(body);
        }

        private int ExtractWorkItemId(dynamic data)
        {
            return data?.workItemId ?? 0;
        }

        private string ExtractTag(dynamic data)
        {
            return (data?.tag ?? "").ToString().Trim();
        }

        private bool ValidateTagParams(int workItemId, string tag)
        {
            return workItemId > 0 && !string.IsNullOrEmpty(tag);
        }

        private ITagAction? GetHandler(string? action)
        {
            return action?.ToLowerInvariant() switch
            {
                "add" => (ITagAction)_addHandler,
                "remove" => (ITagAction)_removeHandler,
                _ => null
            };
        }

        private HttpRequestMessage CreateAzdoChangeTagMessage(HttpRequestData req)
        {
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

            return httpRequestMessage;
        }

        private async Task<HttpResponseData> SerializeResponseMessage(HttpRequestData req, HttpResponseMessage responseMessage)
        {
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

        private async Task<HttpResponseData> CreateBadRequest(HttpRequestData req, string message)
        {
            var badRequestResponse = req.CreateResponse(HttpStatusCode.BadRequest);
            await badRequestResponse.WriteStringAsync(message);
            return badRequestResponse;
        }
    }
}
