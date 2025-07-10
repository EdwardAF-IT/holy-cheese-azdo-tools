using System.Net;

namespace HolyCheese_Azdo_Tools.UnitTests.Common
{
    public class MockHttpMessageHandler : HttpMessageHandler
    {
        public Func<HttpRequestMessage, Task<HttpResponseMessage>> SendAsyncFunc { get; set; } = _ =>
            Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK));

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => SendAsyncFunc(request);
    }
}
