
namespace HolyCheese_Azdo_Tools.TagTools
{
    public interface IAzdo_Tools_Helper
    {
        Task<string?> AddTag(int workItemId, string tag);
        Task<string?> RemoveTag(int workItemId, string tag);
    }
}