using HolyCheeseAzdoTools.TagTools;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System.Net.Http;

// Create and configure Azure Functions app
var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

builder.Services
    .AddApplicationInsightsTelemetryWorkerService()
    .ConfigureFunctionsApplicationInsights()
    .AddHttpClient() // Registers IHttpClientFactory

    // Register TagDataProvider as ITagDataProvider using environment variables
    .AddScoped<ITagDataProvider>(sp =>
    {
        var loggerFactory = sp.GetRequiredService<Microsoft.Extensions.Logging.ILoggerFactory>();
        var httpClientFactory = sp.GetRequiredService<IHttpClientFactory>();
        var client = httpClientFactory.CreateClient();

        var org = Environment.GetEnvironmentVariable("DevOpsOrgName")
            ?? throw new InvalidOperationException("DevOpsOrgName missing");
        var pat = Environment.GetEnvironmentVariable("DevOpsPAT")
            ?? throw new InvalidOperationException("DevOpsPAT missing");

        return new TagDataProvider(client, loggerFactory, org, pat);
    })

    // Register AzdoToolsHelper using injected ITagDataProvider
    .AddScoped<AzdoToolsHelper>(sp =>
    {
        var loggerFactory = sp.GetRequiredService<Microsoft.Extensions.Logging.ILoggerFactory>();
        var tagProvider = sp.GetRequiredService<ITagDataProvider>();
        return new AzdoToolsHelper(loggerFactory, tagProvider);
    })

    // Register function handlers
    .AddScoped<AddTagHandler>()
    .AddScoped<RemoveTagHandler>();

builder.Build().Run();
