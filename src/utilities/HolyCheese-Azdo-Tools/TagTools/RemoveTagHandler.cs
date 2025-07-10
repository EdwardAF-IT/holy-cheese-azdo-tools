using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using System.Net.Http.Json;

namespace HolyCheese_Azdo_Tools.TagTools
{

    /// <summary>
    /// Handles removing a tag from a work item using Azdo_Tools_Helper.
    /// </summary>
    public class RemoveTagHandler : ITagAction
    {
        private readonly IAzdo_Tools_Helper _tools;

        public RemoveTagHandler(IAzdo_Tools_Helper tools)
        {
            _tools = tools;
        }

        public async Task<HttpResponseMessage> ExecuteAsync(HttpRequestMessage req, int workItemId, string tag)
        {
            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = JsonContent.Create(new
                {
                    Message = $"Tag '{tag}' removed from work item {workItemId}."
                })
            };
            await _tools.RemoveTag(workItemId, tag);
            return response;
        }
    }
}