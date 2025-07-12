
namespace HolyCheeseAzdoTools.TagTools
{
    public interface IAzdoToolsHelper
    {
        Task<string?> AddTag(int workItemId, string tag);
        Task<string?> RemoveTag(int workItemId, string tag);
    }
}