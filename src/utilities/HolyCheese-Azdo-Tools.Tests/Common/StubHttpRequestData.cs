using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using System.Net;
using System.Security.Claims;
using System.Text;

namespace HolyCheese_Azdo_Tools.Tests.Common
{
    public class StubHttpRequestData : HttpRequestData
    {
        private readonly FunctionContext _context;
        private MemoryStream? _body;
        private readonly Uri _url;

        /// <summary>
        /// Initializes a stub request with test JSON content and HTTP method.
        /// </summary>
        /// <param name="context">FunctionContext to associate with the request.</param>
        /// <param name="json">The JSON payload to place in the request body.</param>
        /// <param name="method">The HTTP method to simulate (e.g., "POST").</param>
        public StubHttpRequestData(FunctionContext context, string json, string method = "POST")
            : base(context)
        {
            _context = context;
            _url = new Uri("https://localhost/TagOps/add"); // Simulated request URL
            _body = new MemoryStream(Encoding.UTF8.GetBytes(json)); // Encoded body stream
            Headers = new HttpHeadersCollection(); // Empty header collection for testing
            Method = method;
        }

        /// <summary>
        /// The request body containing the JSON payload.
        /// </summary>
        public override Stream Body => _body ?? MemoryStream.Null;

        public void OverrideBody(MemoryStream? newBody) => _body = newBody;

        /// <summary>
        /// Headers collection (empty by default for tests).
        /// </summary>
        public override HttpHeadersCollection Headers { get; }

        /// <summary>
        /// Simulated request URL, used for routing and diagnostics.
        /// </summary>
        public override Uri Url => _url;

        /// <summary>
        /// The HTTP method (e.g., "POST", "GET").
        /// </summary>
        public override string Method { get; }

        /// <summary>
        /// Cookies dictionary — empty for this stub.
        /// </summary>
        public override IReadOnlyCollection<IHttpCookie> Cookies => Array.Empty<IHttpCookie>();

        /// <summary>
        /// Simulated claims — not used in this stub.
        /// </summary>
        public override IEnumerable<ClaimsIdentity> Identities => Enumerable.Empty<ClaimsIdentity>();

        public override HttpResponseData CreateResponse()
        {
            // Default to 200 OK for parameterless requests
            return new TestHttpResponseData(_context, HttpStatusCode.OK);
        }

    }
}