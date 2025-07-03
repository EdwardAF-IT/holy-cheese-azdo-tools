using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using System.Net;

namespace HolyCheese_Azdo_Tools.TagTools
{

    /// <summary>
    /// Handles removing a tag from a work item using Azdo_Tools_Helper.
    /// </summary>
    public class RemoveTagHandler : ITagAction
    {
        private readonly Azdo_Tools_Helper _tools;

        public RemoveTagHandler(Azdo_Tools_Helper tools)
        {
            _tools = tools;
        }

        public async Task<HttpResponseMessage> ExecuteAsync(HttpRequestMessage req, int workItemId, string tag)
        {
            await _tools.RemoveTagAsync(workItemId, tag);
            return req.CreateResponse(HttpStatusCode.OK,
                $"Tag '{tag}' removed from work item {workItemId}.");
        }
    }
}