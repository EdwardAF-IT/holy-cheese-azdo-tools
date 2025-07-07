using HolyCheese_Azdo_Tools.TagTools;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System.Net.Http;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

builder.Services
    .AddApplicationInsightsTelemetryWorkerService()
    .ConfigureFunctionsApplicationInsights()
    .AddHttpClient() // Register IHttpClientFactory
    .AddScoped<Azdo_Tools_Helper>(sp =>
    {
        var loggerFactory = sp.GetRequiredService<Microsoft.Extensions.Logging.ILoggerFactory>();
        var httpClientFactory = sp.GetRequiredService<IHttpClientFactory>();
        return new Azdo_Tools_Helper(loggerFactory, httpClientFactory.CreateClient());
    })
    .AddScoped<AddTagHandler>()
    .AddScoped<RemoveTagHandler>();

builder.Build().Run();
