namespace HolyCheese_Azdo_Tools.TagTools
{

    /// <summary>
    /// Interface for tag operations handled by specific strategies.
    /// </summary>
    public interface ITagAction
    {
        Task<HttpResponseMessage> ExecuteAsync(HttpRequestMessage req, int workItemId, string tag);
    }
}