namespace HolyCheeseAzdoTools.TagTools;

/// <summary>
/// ITagDataProvider for tag operations handled by specific strategies.
/// </summary>
public interface ITagAction
{
    Task<HttpResponseMessage> ExecuteAsync(HttpRequestMessage req, int workItemId, string tag);
}