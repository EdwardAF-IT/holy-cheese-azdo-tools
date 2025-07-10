using HolyCheese_Azdo_Tools.TagTools;
using HolyCheese_Azdo_Tools.UnitTests.Common;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using Xunit;

namespace HolyCheese_Azdo_Tools.UnitTests.TagTools
{

    /// <summary>
    /// Unit tests for TagDataProvider using mocked HttpClient and silent logging.
    /// Validates tag parsing and patching logic with simulated payloads.
    /// </summary>
    public class TagDataProviderTests
    {
        /// <summary>
        /// Creates a TagDataProvider instance with a mock HttpClient and silent logger.
        /// Allows injection of custom response logic per test case.
        /// </summary>
        private TagDataProvider CreateProvider(Func<HttpRequestMessage, Task<HttpResponseMessage>> httpResponder)
        {
            var handler = new MockHttpMessageHandler { SendAsyncFunc = httpResponder };
            var client = new HttpClient(handler);
            var loggerFactory = LoggerFactory.Create(builder => builder.AddProvider(new NullLoggerProvider()));
            return new TagDataProvider(client, loggerFactory, "mockorg", "mockpat");
        }

        /// <summary>
        /// Parses a valid tag response and verifies tag extraction logic.
        /// </summary>
        [Fact]
        public async Task GetExistingTags_ValidResponse_ReturnsTags()
        {
            var provider = CreateProvider(req =>
            {
                var json = TagPayloads.ValidTags;
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(json)
                });
            });

            var (tags, hasTagsField) = await provider.GetExistingTags(100);

            Assert.True(hasTagsField);
            Assert.Equal(new[] { "critical", "urgent" }, tags);
        }

        /// <summary>
        /// Simulates missing System.Tags field to verify empty tag fallback.
        /// </summary>
        [Fact]
        public async Task GetExistingTags_TagsFieldMissing_ReturnsEmpty()
        {
            var provider = CreateProvider(req =>
            {
                var json = TagPayloads.MissingTagsField;
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(json)
                });
            });

            var (tags, hasTagsField) = await provider.GetExistingTags(200);

            Assert.False(hasTagsField);
            Assert.Empty(tags);
        }

        /// <summary>
        /// UnitTests robustness when JSON content is malformed and cannot be parsed.
        /// </summary>
        [Fact]
        public async Task GetExistingTags_MalformedJson_ReturnsEmpty()
        {
            var provider = CreateProvider(req =>
            {
                var brokenJson = TagPayloads.MalformedJson;
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(brokenJson)
                });
            });

            var (tags, hasTagsField) = await provider.GetExistingTags(300);

            Assert.False(hasTagsField);
            Assert.Empty(tags);
        }

        /// <summary>
        /// Simulates null fields in a valid response structure.
        /// Verifies fallback to empty tag array.
        /// </summary>
        [Fact]
        public async Task GetExistingTags_NullFields_ReturnsEmpty()
        {
            var provider = CreateProvider(req =>
            {
                var json = TagPayloads.NullFields;
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(json)
                });
            });

            var (tags, hasTagsField) = await provider.GetExistingTags(350);

            Assert.False(hasTagsField);
            Assert.Empty(tags);
        }

        /// <summary>
        /// Simulates HTTP failure and verifies proper exception is thrown.
        /// </summary>
        [Fact]
        public async Task GetExistingTags_HttpFailure_ThrowsException()
        {
            var provider = CreateProvider(req =>
            {
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound)
                {
                    Content = new StringContent("Not Found")
                });
            });

            var ex = await Assert.ThrowsAsync<HttpRequestException>(() => provider.GetExistingTags(404));

            Assert.Contains("404", ex.Message);
        }

        /// <summary>
        /// Verifies that the PATCH method is used correctly in a tag update.
        /// </summary>
        [Fact]
        public async Task PatchTags_ValidRequest_Succeeds()
        {
            bool patchReceived = false;

            var provider = CreateProvider(req =>
            {
                patchReceived = req.Method == HttpMethod.Patch;
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK));
            });

            await provider.PatchTags(500, new[] { "enhancement" }, true);

            Assert.True(patchReceived);
        }

        /// <summary>
        /// Verifies graceful handling of a failed PATCH request.
        /// No exceptions should be thrown; warning logged silently.
        /// </summary>
        [Fact]
        public async Task PatchTags_HttpFailure_LogsWarning()
        {
            var provider = CreateProvider(req =>
            {
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.BadRequest)
                {
                    Content = new StringContent("Bad Request")
                });
            });

            var ex = await Assert.ThrowsAsync<HttpRequestException>(() =>
                provider.PatchTags(600, new[] { "experimental" }, false));

            Assert.Contains("BadRequest", ex.Message);
        }

        /// <summary>
        /// Verifies ability to process a large number of tags without crashing.
        /// Confirms PATCH payload includes final tag entry.
        /// </summary>
        [Fact]
        public async Task PatchTags_LargeTagSet_CompletesSuccessfully()
        {
            string[] largeTagList = Enumerable.Range(1, 100).Select(i => $"tag{i}").ToArray();
            string? serializedContent = null;

            var provider = CreateProvider(async req =>
            {
                Assert.NotNull(req.Content);
                serializedContent = await req.Content.ReadAsStringAsync();
                return new HttpResponseMessage(HttpStatusCode.OK);
            });

            await provider.PatchTags(999, largeTagList, true);

            Assert.NotNull(serializedContent);
            Assert.Contains("tag100", serializedContent); // Last tag must be present
            Assert.Contains("replace", serializedContent); // PATCH operation indicator
        }
    }
}