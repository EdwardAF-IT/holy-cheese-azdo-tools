using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace HolyCheeseAzdoTools.TagTools
{
    public interface ITagDataProvider
    {
        Task<(string[] Tags, bool HasTagsField)> GetExistingTags(int workItemId);
        Task PatchTags(int workItemId, string[] tags, bool hasTagsField);
    }
}
