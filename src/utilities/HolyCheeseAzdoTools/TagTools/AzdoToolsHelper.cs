using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;
using System.Linq;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace HolyCheeseAzdoTools.TagTools;

/// <summary>
/// High-level operations for managing tags on Azure DevOps work items.
/// Delegates data access to ITagDataProvider for flexibility and testability.
/// </summary>
public class AzdoToolsHelper : IAzdoToolsHelper
{
    private readonly ILogger _log;
    private readonly ITagDataProvider _provider;

    /// <summary>
    /// Initializes the tag helper with logging and data provider dependencies.
    /// </summary>
    public AzdoToolsHelper(ILoggerFactory loggerFactory, ITagDataProvider provider)
    {
        _log = loggerFactory.CreateLogger("AzdoToolsHelper");
        _provider = provider ?? throw new ArgumentNullException(nameof(provider));
    }

    /// <summary>
    /// Adds a tag to a work item if it doesn't already exist.
    /// Returns null on success, or an error message if something fails.
    /// </summary>
    public async Task<string?> AddTag(int workItemId, string tag)
    {
        try
        {
            var (tags, hasTagsField) = await _provider.GetExistingTags(workItemId);

            if (tags.Any(t => t.Equals(tag, StringComparison.OrdinalIgnoreCase)))
            {
                _log.LogDebug("Work item {WorkItemId}: Tag '{Tag}' already exists. No update.", workItemId, tag); return null;
            }

            await _provider.PatchTags(workItemId, [.. tags, tag], hasTagsField);
            return null;
        }
        catch (HttpRequestException ex)
        {
            _log.LogError(ex, "Error connecting to Azure DevOps while adding tag '{Tag}' to work item {WorkItemId}.", tag, workItemId);
            return "Error connecting to Azure DevOps. Please check your network connection and credentials.";
        }
        catch (InvalidOperationException ex)
        {
            _log.LogError(ex, "Work item {WorkItemId} not found or invalid operation while adding tag '{Tag}'.", workItemId, tag);
            return $"Work item {workItemId} not found or invalid operation.";
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Unexpected error while adding tag '{Tag}' to work item {WorkItemId}.", tag, workItemId);
            return "An unexpected error occurred while adding the tag.";
        }
    }

    /// <summary>
    /// Removes a tag from a work item if it exists.
    /// Returns null on success, or an error message if something fails.
    /// </summary>
    public async Task<string?> RemoveTag(int workItemId, string tag)
    {
        try
        {
            var (tags, hasTagsField) = await _provider.GetExistingTags(workItemId);
            var updatedTags = tags
                .Where(t => !t.Equals(tag, StringComparison.OrdinalIgnoreCase))
                .ToArray();

            _log.LogDebug("Work item {WorkItemId}: Attempting to remove tag '{Tag}'.", workItemId, tag);
            await _provider.PatchTags(workItemId, updatedTags, hasTagsField);
            return null;
        }
        catch (HttpRequestException ex)
        {
            _log.LogError(ex, "Error connecting to Azure DevOps while removing tag '{Tag}' from work item {WorkItemId}.", tag, workItemId);
            return "Error connecting to Azure DevOps. Please check your network connection and credentials.";
        }
        catch (InvalidOperationException ex)
        {
            _log.LogError(ex, "Work item {WorkItemId} not found or invalid operation while removing tag '{Tag}'.", workItemId, tag);
            return $"Work item {workItemId} not found or invalid operation.";
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Unexpected error while removing tag '{Tag}' from work item {WorkItemId}.", tag, workItemId);
            return "An unexpected error occurred while removing the tag.";
        }
    }
}