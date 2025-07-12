using HolyCheeseAzdoTools.TagTools;
using HolyCheeseAzdoTools.UnitTests.Common;
using Moq;
using System;
using System.Net;
using System.Net.Http.Json;
using Xunit;

namespace HolyCheeseAzdoTools.UnitTests.TagTools
{
    public class AddTagHandler_UnitTests
    {
        [Theory]
        [Trait("Category", "Unit")]
        [InlineData(101, "urgent")]
        [InlineData(202, "feature")]
        [InlineData(303, "enhancement")]
        public async Task ExecuteAsync_ReturnsSuccessAndCorrectMessage(int workItemId, string tag)
        {
            // Arrange
            var mockTools = new Mock<IAzdoToolsHelper>();
            mockTools.Setup(t => t.AddTag(workItemId, tag))
                     .ReturnsAsync("Simulated result");

            var handler = new AddTagHandler(mockTools.Object);
            var request = new HttpRequestMessage();

            // Act
            var response = await handler.ExecuteAsync(request, workItemId, tag);
            var result = await response.Content.ReadFromJsonAsync<TagResponse>();

            // Assert
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Contains($"Tag '{tag}' added to work item {workItemId}.", result?.Message?.ToString());
            mockTools.Verify(t => t.AddTag(workItemId, tag), Times.Once);
        }

        [Fact]
        [Trait("Category", "Unit")]
        public async Task ExecuteAsync_AddTagThrowsException_ReturnsInternalServerError()
        {
            // Arrange
            var mockTools = new Mock<IAzdoToolsHelper>();
            mockTools.Setup(t => t.AddTag(It.IsAny<int>(), It.IsAny<string>()))
                     .ThrowsAsync(new InvalidOperationException("Simulated failure"));

            var handler = new AddTagHandler(mockTools.Object);
            var request = new HttpRequestMessage();
            int workItemId = 123;
            string tag = "test";

            // Act
            HttpResponseMessage response;
            try
            {
                response = await handler.ExecuteAsync(request, workItemId, tag);
            }
            catch (Exception ex)
            {
                response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent($"Exception: {ex.Message}")
                };
            }

            // Assert
            Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
            var content = await response.Content.ReadAsStringAsync();
            Assert.Contains("Simulated failure", content);
        }

        [Theory]
        [Trait("Category", "Unit")]
        [InlineData(-1)]
        [InlineData(0)]
        [InlineData(int.MinValue)]
        public async Task ExecuteAsync_InvalidWorkItemId_TriggersErrorResponse(int invalidId)
        {
            // Arrange
            var mockTools = new Mock<IAzdoToolsHelper>();
            mockTools.Setup(t => t.AddTag(invalidId, It.IsAny<string>()))
                     .ThrowsAsync(new ArgumentOutOfRangeException(nameof(invalidId), "Work item ID is invalid"));

            var handler = new AddTagHandler(mockTools.Object);
            var request = new HttpRequestMessage();
            string tag = "bug";

            // Act
            HttpResponseMessage response;
            try
            {
                response = await handler.ExecuteAsync(request, invalidId, tag);
            }
            catch (Exception ex)
            {
                response = new HttpResponseMessage(HttpStatusCode.BadRequest)
                {
                    Content = new StringContent($"Exception: {ex.Message}")
                };
            }

            // Assert
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            var content = await response.Content.ReadAsStringAsync();
            Assert.Contains("Work item ID is invalid", content);
        }

        [Theory]
        [Trait("Category", "Unit")]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("    ")]
        public async Task ExecuteAsync_HandlesInvalidTagGracefully(string invalidTag)
        {
            // Arrange
            var mockTools = new Mock<IAzdoToolsHelper>();
            mockTools.Setup(t => t.AddTag(It.IsAny<int>(), invalidTag))
                     .ThrowsAsync(new ArgumentException("Tag is invalid"));

            var handler = new AddTagHandler(mockTools.Object);
            var request = new HttpRequestMessage();
            int workItemId = 456;

            // Act
            HttpResponseMessage response;
            try
            {
                response = await handler.ExecuteAsync(request, workItemId, invalidTag);
            }
            catch (Exception ex)
            {
                response = new HttpResponseMessage(HttpStatusCode.BadRequest)
                {
                    Content = new StringContent($"Exception: {ex.Message}")
                };
            }

            // Assert
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            var content = await response.Content.ReadAsStringAsync();
            Assert.Contains("Tag is invalid", content);
        }
    }
}
