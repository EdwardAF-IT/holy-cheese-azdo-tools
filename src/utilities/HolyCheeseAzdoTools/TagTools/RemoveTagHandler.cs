using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using System.Net.Http.Json;

namespace HolyCheeseAzdoTools.TagTools
{

    /// <summary>
    /// Handles removing a tag from a work item using AzdoToolsHelper.
    /// </summary>
    public class RemoveTagHandler : ITagAction
    {
        private readonly IAzdoToolsHelper _tools;

        public RemoveTagHandler(IAzdoToolsHelper tools)
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