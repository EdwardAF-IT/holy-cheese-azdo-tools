using HolyCheeseAzdoTools.TagTools;
using HolyCheeseAzdoTools.UnitTests.Common;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Moq;
using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Xunit;

namespace HolyCheeseAzdoTools.UnitTests.TagTools;

/// <summary>
/// Unit tests for TagRouterAzureFunction that verify handler routing,
/// request validation, and response serialization.
/// </summary>
public class TagRouterAzureFunction_UnitTests
{
    private readonly ILoggerFactory _loggerFactory = LoggerFactory.Create(builder => builder.AddProvider(new NullLoggerProvider()));
    private readonly ITagDataProvider _mockProvider = Mock.Of<ITagDataProvider>();

    /// <summary>
    /// Creates an instance of TagRouterAzureFunction with optional handlers.
    /// </summary>
    private TagRouterAzureFunction CreateFunction(
        ITagAction? add = null,
        ITagAction? remove = null) =>
        new(
            new AzdoToolsHelper(_loggerFactory, _mockProvider),
            add ?? Mock.Of<ITagAction>(),
            remove ?? Mock.Of<ITagAction>(),
            _loggerFactory.CreateLogger<TagRouterAzureFunction>());

    /// <summary>
    /// Creates a simulated HttpRequestData with the specified JSON payload and method.
    /// </summary>
    private static HttpRequestData CreateHttpRequest(string json, string method = "POST")
    {
        var context = new Mock<FunctionContext>();
        var reqMock = new Mock<HttpRequestData>(context.Object);
        reqMock.SetupGet(r => r.Method).Returns(method);
        reqMock.SetupGet(r => r.Url).Returns(new Uri("https://localhost/TagOps/add"));
        reqMock.SetupGet(r => r.Headers).Returns([]);
        reqMock.SetupGet(r => r.Body).Returns(new MemoryStream(Encoding.UTF8.GetBytes(json)));
        reqMock.Setup(r => r.CreateResponse(It.IsAny<HttpStatusCode>()))
               .Returns((HttpStatusCode code) => new TestHttpResponseData(context.Object, code));
        return reqMock.Object;
    }

    /// <summary>
    /// Validates that the "add" route correctly invokes AddTagHandler for valid input.
    /// </summary>
    [Fact]
    [Trait("Route", "Add")]
    [Trait("Behavior", "Success")]
    [Trait("Category", "Unit")]
    public async Task Run_AddAction_ValidPayload_InvokesHandler()
    {
        var handlerMock = new Mock<ITagAction>();
        handlerMock.Setup(h => h.ExecuteAsync(It.IsAny<HttpRequestMessage>(), 123, "urgent"))
            .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("Tag added")
            });

        var function = CreateFunction(add: handlerMock.Object);

        // Replace Moq-based request with concrete Stub
        var context = Mock.Of<FunctionContext>();
        var req = new StubHttpRequestData(context, "{ \"workItemId\": 123, \"tag\": \"urgent\" }", "POST");

        var response = await function.Run(req, "add");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    /// <summary>
    /// UnitTests various invalid request scenarios to confirm BadRequest responses.
    /// </summary>
    [Theory]
    [InlineData("modify", "{ \"workItemId\": 123, \"tag\": \"urgent\" }")] // Unsupported route
    [InlineData("add", "{ \"tag\": \"\" }")] // Missing workItemId
    [InlineData("add", "{ \"workItemId\": 123, ")] // Malformed JSON
    [Trait("Route", "Add")]
    [Trait("Behavior", "Validation")]
    [Trait("Category", "Unit")]
    public async Task Run_InvalidPayload_ReturnsBadRequest(string action, string payload)
    {
        var function = CreateFunction();
        var context = Mock.Of<FunctionContext>();
        var req = new StubHttpRequestData(context, payload);
        var response = await function.Run(req, action);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    /// <summary>
    /// Verifies that the function returns BadRequest when the request body is null.
    /// </summary>
    [Fact]
    [Trait("Route", "Add")]
    [Trait("Behavior", "Validation")]
    [Trait("Category", "Unit")]
    public async Task Run_NullBody_ReturnsBadRequest()
    {
        var context = new Mock<FunctionContext>().Object;
        var req = new StubHttpRequestData(context, "", "POST");
        req.OverrideBody(null);

        var function = CreateFunction();
        var response = await function.Run(req, "add");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
