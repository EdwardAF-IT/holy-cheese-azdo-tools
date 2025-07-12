using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Net.Http.Json;

namespace HolyCheeseAzdoTools.TagTools
{

    /// <summary>
    /// Handles adding a tag to a work item using AzdoToolsHelper.
    /// </summary>
    public class AddTagHandler : ITagAction
    {
        private readonly IAzdoToolsHelper _tools;

        public AddTagHandler(IAzdoToolsHelper tools)
        {
            _tools = tools;
        }

        public async Task<HttpResponseMessage> ExecuteAsync(HttpRequestMessage req, int workItemId, string tag)
        {
            await _tools.AddTag(workItemId, tag);

            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = JsonContent.Create(new
                {
                    Message = $"Tag '{tag}' added to work item {workItemId}."
                })
            };

            return response;
        }
    }
}