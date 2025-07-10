using HolyCheese_Azdo_Tools.TagTools;
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

    // Register Azdo_Tools_Helper using injected ITagDataProvider
    .AddScoped<Azdo_Tools_Helper>(sp =>
    {
        var loggerFactory = sp.GetRequiredService<Microsoft.Extensions.Logging.ILoggerFactory>();
        var tagProvider = sp.GetRequiredService<ITagDataProvider>();
        return new Azdo_Tools_Helper(loggerFactory, tagProvider);
    })

    // Register function handlers
    .AddScoped<AddTagHandler>()
    .AddScoped<RemoveTagHandler>();

builder.Build().Run();
