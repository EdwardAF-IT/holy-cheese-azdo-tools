using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using System.Net;

/// <summary>
/// A concrete test stub for HttpResponseData used in Azure Function unit tests.
/// This class avoids Moq and overrides necessary members to simulate response behavior.
/// </summary>
public class TestHttpResponseData : HttpResponseData, IDisposable
{
    private MemoryStream _stream = new MemoryStream(); // Holds response body content
    private HttpHeadersCollection _headers = new HttpHeadersCollection(); // Simulated response headers

    /// <summary>
    /// Constructs a test response with a specified status code.
    /// </summary>
    /// <param name="functionContext">The mocked FunctionContext passed to the base class.</param>
    /// <param name="statusCode">The HTTP status code to simulate in the test.</param>
    public TestHttpResponseData(FunctionContext functionContext, HttpStatusCode statusCode = HttpStatusCode.OK)
        : base(functionContext)
    {
        StatusCode = statusCode;
    }

    /// <summary>
    /// Gets or sets the status code of the response.
    /// </summary>
    public override HttpStatusCode StatusCode { get; set; }

    /// <summary>
    /// Provides access to the headers collection for the simulated response.
    /// </summary>
    public override HttpHeadersCollection Headers
    {
        get => _headers;
        set => _headers = value ?? new HttpHeadersCollection(); // Defensive fallback
    }

    /// <summary>
    /// Stream representing the response body. Can be inspected after writing.
    /// </summary>
    public override Stream Body
    {
        get => _stream;
        set => _stream = (MemoryStream)(value ?? new MemoryStream()); // fallback to safe stream
    }
    /// <summary>
    /// Placeholder cookie collection (not used in current tests but required by interface).
    /// </summary>
    public override HttpCookies Cookies => null!; // Not used in tests; null suppressed intentionally

    /// <summary>
    /// Writes a string to the response body stream.
    /// Allows inspection of result in test assertions.
    /// </summary>
    /// <param name="content">The string content to write.</param>
    /// <param name="cancellationToken">Optional cancellation token (default ignored).</param>
    public Task WriteStringAsync(string content, CancellationToken cancellationToken = default)
    {
        var writer = new StreamWriter(_stream, leaveOpen: true);
        writer.Write(content);
        writer.Flush();

        // Reset stream position so test code can read from it
        _stream.Position = 0;

        return Task.CompletedTask;
    }

    public void Dispose()
    {
        throw new NotImplementedException();
    }
}
