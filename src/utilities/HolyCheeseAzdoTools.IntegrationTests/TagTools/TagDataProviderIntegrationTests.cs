using Xunit;
using Microsoft.Extensions.Logging;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using HolyCheeseAzdoTools.TagTools;

namespace HolyCheeseAzdoTools.IntegrationTests.TagTools;

public class TagDataProviderIntegrationTests
{
    /// <summary>
    /// Builds a live TagDataProvider using secrets from Azure Key Vault.
    /// Requires valid DefaultAzureCredential with access to vault: https://holycheese-azdo.vault.azure.net/.
    /// </summary>
    private static async Task<TagDataProvider> CreateLiveProvider()
    {
        var vaultUri = new Uri("https://holycheese-azdo.vault.azure.net/");
        var kvClient = new SecretClient(vaultUri, new DefaultAzureCredential());

        // Fetch secrets: DevOps organization and Personal Access Token (PAT)
        KeyVaultSecret orgSecret = await kvClient.GetSecretAsync("DevOpsOrgName");
        KeyVaultSecret patSecret = await kvClient.GetSecretAsync("DevOpsPAT");

        string org = orgSecret.Value;
        string pat = patSecret.Value;

        // Set up real HttpClient and logger for live API calls
        var client = new HttpClient();
        var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());

        return new TagDataProvider(client, loggerFactory, org, pat);
    }

    /// <summary>
    /// Verifies that the live API successfully returns tags from work item 482.
    /// Confirms that the response contains expected fields and real data.
    /// </summary>
    [Fact]
    [Trait("Category", "Integration")]
    public async Task GetExistingTags_LiveWorkItem_ReturnsTags()
    {
        var provider = await CreateLiveProvider();

        // Call Azure DevOps API using real credentials
        var (tags, hasTagsField) = await provider.GetExistingTags(482);

        Assert.True(hasTagsField);     // System.Tags field must exist
        Assert.NotNull(tags);          // Tag array must be initialized
        Assert.NotEmpty(tags);         // Work item 482 should have tags assigned
    }

    /// <summary>
    /// Appends a test-specific tag to work item 482 and verifies that the update succeeds.
    /// This confirms PATCH behavior and field-level write access in Azure DevOps.
    /// </summary>
    [Fact]
    [Trait("Category", "Integration")]
    public async Task PatchTags_LiveWorkItem_AddsNewTag()
    {
        var provider = await CreateLiveProvider();

        // Step 1: Read current tags
        var (existingTags, hasTagsField) = await provider.GetExistingTags(482);
        string tempTag = "integration-test-tag";

        // Step 2: Append the temporary tag (avoid duplicates)
        var updatedTags = existingTags.Append(tempTag).Distinct().ToArray();

        // Step 3: Patch the work item using the updated tag list
        await provider.PatchTags(482, updatedTags, hasTagsField);

        // Step 4: Re-read the tags to confirm the test tag was applied
        var (newTags, _) = await provider.GetExistingTags(482);
        Assert.Contains(tempTag, newTags); // Integration tag must now be present
    }

    /// <summary>
    /// Validates graceful handling when a non-existent work item is queried.
    /// Should throw HttpRequestException due to 404 Not Found.
    /// </summary>
    [Fact]
    [Trait("Category", "Integration")]
    public async Task GetExistingTags_NonExistentWorkItem_ReturnsError()
    {
        var provider = await CreateLiveProvider();

        var ex = await Assert.ThrowsAsync<HttpRequestException>(
            () => provider.GetExistingTags(999999)
        );

        // Accept either the numeric status code or its reason phrase for flexibility
        Assert.Matches("404|NotFound", ex.Message);
    }

    /// <summary>
    /// Simulates unauthorized access by using an invalid PAT.
    /// Verifies that auth failure results in a meaningful exception.
    /// </summary>
    [Fact]
    [Trait("Category", "Integration")]
    public async Task PatchTags_UnauthorizedAccess_ThrowsException()
    {
        var client = new HttpClient();
        var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());

        // Create provider with fake token
        var provider = new TagDataProvider(client, loggerFactory, "DevOpsOrgName", "invalid-pat");

        var ex = await Assert.ThrowsAsync<HttpRequestException>(() =>
            provider.PatchTags(482, ["auth-failure-tag"], true)
        );

        Assert.Matches("401|Unauthorized", ex.Message);        // Unauthorized status expected
    }

    /// <summary>
    /// Removes the test tag after it has been added.
    /// Ensures the integration test does not leave residual data on work item 482.
    /// </summary>
    [Fact]
    [Trait("Category", "Integration")]
    public async Task PatchTags_RemoveTestTag_CleansUpAfterWrite()
    {
        var provider = await CreateLiveProvider();
        string cleanupTag = "integration-cleanup-tag";

        var (tagsBefore, hasTagsField) = await provider.GetExistingTags(482);

        // Inject tag for cleanup
        var injected = tagsBefore.Append(cleanupTag).Distinct().ToArray();
        await provider.PatchTags(482, injected, hasTagsField);

        // Remove the tag afterward
        var cleaned = injected.Where(tag => tag != cleanupTag).ToArray();
        await provider.PatchTags(482, cleaned, true);

        var (tagsAfter, _) = await provider.GetExistingTags(482);
        Assert.DoesNotContain(cleanupTag, tagsAfter); // Confirm cleanup succeeded
    }

    /// <summary>
    /// Validates that duplicate tags are filtered during patching.
    /// Ensures the system enforces uniqueness automatically.
    /// </summary>
    [Fact]
    [Trait("Category", "Integration")]
    public async Task PatchTags_DuplicateTags_MaintainsUniqueness()
    {
        var provider = await CreateLiveProvider();
        string tag = "integration-duplicate-tag";

        var (_, hasTagsField) = await provider.GetExistingTags(482);

        // Submit duplicated tags
        var duplicated = new[] { tag, tag, tag };
        await provider.PatchTags(482, duplicated, hasTagsField);

        var (tagsAfter, _) = await provider.GetExistingTags(482);
        int count = tagsAfter.Count(t => t == tag);

        Assert.True(count == 1); // Should appear only once
    }

    /// <summary>
    /// Confirms parsing behavior when special characters are used in tags.
    /// Validates handling of symbols, punctuation, and edge strings.
    /// </summary>
    [Fact]
    [Trait("Category", "Integration")]
    public async Task GetExistingTags_MultipleTagsWithSpecialChars_ParsesCorrectly()
    {
        var provider = await CreateLiveProvider();
        string[] weirdTags = ["#urgent", "critical@prod", "review-ready!"];

        var (existingTags, hasTagsField) = await provider.GetExistingTags(482);

        // Inject special character tags
        var updated = existingTags.Concat(weirdTags).Distinct().ToArray();
        await provider.PatchTags(482, updated, hasTagsField);

        var (tagsAfter, _) = await provider.GetExistingTags(482);

        foreach (var tag in weirdTags)
        {
            Assert.Contains(tag, tagsAfter); // Confirm each tag was accepted
        }
    }

    /// <summary>
    /// Validates parsing behavior when System.Tags field is explicitly removed.
    /// Confirms fallback to empty array and absence indicator.
    /// </summary>
    [Fact]
    [Trait("Category", "Integration")]
    public async Task GetExistingTags_FieldMissing_ReturnsFalse()
    {
        var provider = await CreateLiveProvider();

        // Remove System.Tags by patching with an empty array
        await provider.PatchTags(482, [], true);

        var (tagsAfter, hasField) = await provider.GetExistingTags(482);

        Assert.False(tagsAfter.Length != 0);  // Expect no tags
        Assert.False(hasField);          // Field should be gone if there are no tags
    }
}
