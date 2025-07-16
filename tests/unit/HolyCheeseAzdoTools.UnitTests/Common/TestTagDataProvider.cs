using HolyCheeseAzdoTools.TagTools;
using System;
using System.Threading.Tasks;

namespace HolyCheeseAzdoTools.UnitTests.Common
{

    /// <summary>
    /// Flexible test stub for ITagDataProvider used in unit tests.
    /// Behavior for GetExistingTags and PatchTags can be injected via delegates per test case.
    /// </summary>
    public class TestTagDataProvider : ITagDataProvider
    {
        /// <summary>
        /// Delegate to simulate tag retrieval per work item.
        /// Can return fixed values or throw exceptions based on test needs.
        /// </summary>
        public Func<int, Task<(string[] Tags, bool HasTagsField)>>? GetTagsFunc { get; set; }

        /// <summary>
        /// Delegate to simulate patch behavior.
        /// Useful for validating input or simulating failures.
        /// </summary>
        public Func<int, string[], bool, Task>? PatchTagsFunc { get; set; }

        public Task<(string[] Tags, bool HasTagsField)> GetExistingTags(int workItemId)
            => GetTagsFunc?.Invoke(workItemId)
               ?? Task.FromResult((Array.Empty<string>(), true)); // Defaults to no tags, field available

        public Task PatchTags(int workItemId, string[] tags, bool hasTagsField)
            => PatchTagsFunc?.Invoke(workItemId, tags, hasTagsField)
               ?? Task.CompletedTask; // Default is a successful no-op
    }
}