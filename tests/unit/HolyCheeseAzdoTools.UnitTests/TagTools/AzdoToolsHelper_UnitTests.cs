using HolyCheeseAzdoTools.TagTools;
using HolyCheeseAzdoTools.UnitTests.Common;
using Microsoft.Extensions.Logging;
using Xunit;

namespace HolyCheeseAzdoTools.UnitTests.TagTools;

/// <summary>
/// Unit tests for Azdo_Tools_Helper using delegate-based TestTagDataProvider.
/// Ensures AddTag and RemoveTag behave correctly under various conditions.
/// </summary>
public class AzdoToolsHelper_UnitTests
{
    /// <summary>
    /// Helper factory to create Azdo_Tools_Helper with injected test stub and logger.
    /// </summary>
    private static AzdoToolsHelper CreateHelperWithProvider(TestTagDataProvider provider)
    {
        var loggerFactory = LoggerFactory.Create(builder => builder.AddDebug());
        return new AzdoToolsHelper(loggerFactory, provider);
    }

    /// <summary>
    /// Groups of tags that can be used in tests.
    /// </summary>
    private static readonly Dictionary<string, string[]> TagSets = new()
    {
        { "urgent", new[] { "urgent" } },
        { "alerts", new[] { "urgent", "critical" } },
        { "completed", new[] { "done", "reviewed" } }
    };

    /// <summary>
    /// Retrieves a predefined set of tags based on the given context string.
    /// Used to simulate tag classification or labeling behavior in test scenarios.
    /// Returns a tuple containing the tag array and a success flag.  The tuple is 
    /// returned rather than just the tags because that is what the users of this method need.
    /// Intended for use in unit tests or mock implementations where fixed tag sets improve predictability.
    /// </summary>
    /// <param name="context">A key representing the tag category (e.g., "urgent", "alerts", "completed").</param>
    /// <returns>A tuple of (string[] tags, bool success).</returns>
    private static (string[] tags, bool success) GetTags(string context)
    {
        return context switch
        {
            "urgent" => (["urgent"], true),
            "alerts" => (["urgent", "critical"], true),
            "completed" => (["done", "reviewed"], true),
            _ => (Array.Empty<string>(), false)
        };
    }

    /// <summary>
    /// Confirms that AddTag skips update when tag already exists.
    /// </summary>
    [Fact]
    [Trait("Category", "Unit")]
    public async Task AddTag_TagAlreadyExists_ReturnsNull()
    {
        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => Task.FromResult(GetTags("urgent"))
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.AddTag(123, "urgent");

        Assert.Null(result); // No error, tag is already present
    }

    /// <summary>
    /// Confirms that AddTag appends new tags and calls PatchTags.
    /// Multiple combinations tested using [Theory].
    /// </summary>
    [Theory]
    [InlineData(101, "critical", new[] { "existing" })]
    [InlineData(202, "new-feature", new[] { "done", "reviewed" })]
    [InlineData(303, "enhancement", new string[0])]
    [Trait("Category", "Unit")]
    public async Task AddTag_NewTag_AppendsTagAndCallsPatch(int workItemId, string newTag, string[] existingTags)
    {
        bool patchCalled = false;
        string[] patchedTags = [];

        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => Task.FromResult((existingTags, true)),
            PatchTagsFunc = (id, tags, hasField) =>
            {
                patchCalled = true;
                patchedTags = tags;
                return Task.CompletedTask;
            }
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.AddTag(workItemId, newTag);

        Assert.Null(result);                          // No error expected
        Assert.True(patchCalled);                     // Patch should be triggered
        Assert.Contains(newTag, patchedTags);         // Tag must be appended
        Assert.Equal(existingTags.Length + 1, patchedTags.Length);
    }

    /// <summary>
    /// Simulates network failure during tag fetch and expects a user-friendly error.
    /// </summary>
    [Fact]
    [Trait("Category", "Unit")]
    public async Task AddTag_HttpRequestException_ReturnsNetworkError()
    {
        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => throw new HttpRequestException("network fail")
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.AddTag(999, "tag");

        Assert.NotNull(result);
        Assert.Contains("Error connecting to Azure DevOps", result);
    }

    /// <summary>
    /// Simulates an invalid work item and expects a specific error message.
    /// </summary>
    [Fact]
    [Trait("Category", "Unit")]
    public async Task AddTag_InvalidOperationException_ReturnsNotFoundMessage()
    {
        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => throw new InvalidOperationException("not found")
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.AddTag(999, "tag");

        Assert.NotNull(result);
        Assert.Contains("not found or invalid operation", result);
    }

    /// <summary>
    /// Simulates an unexpected exception to confirm fallback error messaging.
    /// </summary>
    [Fact]
    [Trait("Category", "Unit")]
    public async Task AddTag_UnexpectedException_ReturnsGenericError()
    {
        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => throw new Exception("random failure")
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.AddTag(999, "tag");

        Assert.NotNull(result);
        Assert.Contains("unexpected error occurred", result);
    }

    /// <summary>
    /// Validates that RemoveTag removes the correct tag and triggers PatchTags with reduced tag arrays.
    /// Covers multiple tag arrangements using [Theory].
    /// </summary>
    [Theory]
    [InlineData(101, "done", new[] { "done", "reviewed" }, new[] { "reviewed" })]
    [InlineData(202, "urgent", new[] { "urgent" }, new string[0])]
    [InlineData(303, "feature", new[] { "critical", "feature", "enhancement" }, new[] { "critical", "enhancement" })]
    [InlineData(404, "reviewed", new[] { "done", "reviewed", "reviewed" }, new[] { "done" })] // Handles duplicate tags
    [Trait("Category", "Unit")]
    public async Task RemoveTag_TagExists_RemovesTagAndCallsPatch(int workItemId, string tagToRemove, string[] existingTags, string[] expectedTags)
    {
        bool patchCalled = false;
        string[] patchedTags = [];

        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => Task.FromResult((existingTags, true)),
            PatchTagsFunc = (id, tags, hasField) =>
            {
                patchCalled = true;
                patchedTags = tags;
                return Task.CompletedTask;
            }
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.RemoveTag(workItemId, tagToRemove);

        Assert.Null(result);                      // No error expected
        Assert.True(patchCalled);                 // Patch should occur
        Assert.DoesNotContain(tagToRemove, patchedTags);         // Tag must be removed
        Assert.Equal(expectedTags.Length, patchedTags.Length);   // Verify final tag count
        Assert.Equal(expectedTags, patchedTags);                 // Verify correct tags remain
    }

    /// <summary>
    /// Skips patch if the tag is not present on the work item.
    /// </summary>
    [Fact]
    [Trait("Category", "Unit")]
    public async Task RemoveTag_TagDoesNotExist_ReturnsNull()
    {
        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => Task.FromResult(GetTags("completed"))
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.RemoveTag(123, "urgent");

        Assert.Null(result); // No error expected; nothing to patch
    }

    /// <summary>
    /// Removes the tag if present and triggers PatchTags with updated tag array.
    /// </summary>
    [Fact]
    [Trait("Category", "Unit")]
    public async Task RemoveTag_TagExists_PatchCalledWithReducedTags()
    {
        bool patchCalled = false;
        string[] patchedTags = [];

        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => Task.FromResult(GetTags("alerts")),
            PatchTagsFunc = (id, tags, hasField) =>
            {
                patchCalled = true;
                patchedTags = tags;
                return Task.CompletedTask;
            }
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.RemoveTag(456, "urgent");

        Assert.Null(result);                     // No error expected
        Assert.True(patchCalled);                // Patch should occur
        Assert.DoesNotContain("urgent", patchedTags); // Tag should be removed
        Assert.Single(patchedTags);     // Tag count should decrease
    }

    /// <summary>
    /// Simulates a network error during tag retrieval.
    /// </summary>
    [Fact]
    [Trait("Category", "Unit")]
    public async Task RemoveTag_HttpRequestException_ReturnsNetworkError()
    {
        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => throw new HttpRequestException("network fail")
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.RemoveTag(999, "tag");

        Assert.NotNull(result);
        Assert.Contains("Error connecting to Azure DevOps", result);
    }

    /// <summary>
    /// Simulates a missing or invalid work item.
    /// </summary>
    [Fact]
    [Trait("Category", "Unit")]
    public async Task RemoveTag_InvalidOperationException_ReturnsNotFoundMessage()
    {
        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => throw new InvalidOperationException("not found")
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.RemoveTag(999, "tag");

        Assert.NotNull(result);
        Assert.Contains("not found or invalid operation", result);
    }

    /// <summary>
    /// Catches and returns a generic fallback error.
    /// </summary>
    [Fact]
    [Trait("Category", "Unit")]
    public async Task RemoveTag_UnexpectedException_ReturnsGenericError()
    {
        var provider = new TestTagDataProvider
        {
            GetTagsFunc = id => throw new Exception("unexpected fail")
        };

        var helper = CreateHelperWithProvider(provider);
        var result = await helper.RemoveTag(999, "tag");

        Assert.NotNull(result);
        Assert.Contains("unexpected error occurred", result);
    }
}