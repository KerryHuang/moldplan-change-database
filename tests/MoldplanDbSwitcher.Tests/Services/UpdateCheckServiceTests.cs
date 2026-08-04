using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Tests.TestHelpers;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class UpdateCheckServiceTests
{
    private static UpdateCheckService Create(
        FakeHttpMessageHandler? handler = null,
        Version? currentVersion = null)
    {
        var http = new HttpClient(handler ?? FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, "{}"));
        return new UpdateCheckService(http, currentVersion ?? new Version(1, 0, 0));
    }

    [Fact]
    public async Task CheckAsync_NullToken_ReturnsNull()
    {
        var sut = Create();
        var result = await sut.CheckAsync(null);
        Assert.Null(result);
    }

    [Fact]
    public async Task CheckAsync_EmptyToken_ReturnsNull()
    {
        var sut = Create();
        Assert.Null(await sut.CheckAsync(""));
        Assert.Null(await sut.CheckAsync("   "));
    }

    [Fact]
    public async Task CheckAsync_NewerVersionAvailable_ReturnsInfo()
    {
        var json = """
            {
                "tag_name": "v2.0.0",
                "html_url": "https://github.com/owner/repo/releases/tag/v2.0.0",
                "body": "release notes here"
            }
            """;
        var handler = FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json);
        var sut = Create(handler, currentVersion: new Version(1, 1, 2));

        var result = await sut.CheckAsync("dummy-token");

        Assert.NotNull(result);
        Assert.Equal("2.0.0", result!.LatestVersion);
        Assert.Equal("https://github.com/owner/repo/releases/tag/v2.0.0", result.ReleaseUrl);
        Assert.Equal("release notes here", result.ReleaseNotes);
    }

    [Fact]
    public async Task CheckAsync_SendsBearerTokenAndUserAgent()
    {
        var json = "{}";
        var handler = FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json);
        var sut = Create(handler);

        await sut.CheckAsync("my-token");

        var req = handler.Requests.Single();
        Assert.Equal("Bearer", req.Headers.Authorization?.Scheme);
        Assert.Equal("my-token", req.Headers.Authorization?.Parameter);
        Assert.NotEmpty(req.Headers.UserAgent);
        Assert.Contains(req.Headers.Accept, h => h.MediaType == "application/vnd.github+json");
    }

    [Fact]
    public async Task CheckAsync_SameVersion_ReturnsNull()
    {
        var json = """{"tag_name":"v1.1.2","html_url":"https://x","body":""}""";
        var sut = Create(FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json),
            currentVersion: new Version(1, 1, 2));
        Assert.Null(await sut.CheckAsync("t"));
    }

    [Fact]
    public async Task CheckAsync_OlderVersion_ReturnsNull()
    {
        var json = """{"tag_name":"v1.0.0","html_url":"https://x","body":""}""";
        var sut = Create(FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json),
            currentVersion: new Version(1, 1, 2));
        Assert.Null(await sut.CheckAsync("t"));
    }

    [Theory]
    [InlineData(System.Net.HttpStatusCode.Unauthorized)]
    [InlineData(System.Net.HttpStatusCode.NotFound)]
    [InlineData(System.Net.HttpStatusCode.InternalServerError)]
    public async Task CheckAsync_HttpError_ReturnsNull(System.Net.HttpStatusCode status)
    {
        var sut = Create(FakeHttpMessageHandler.Json(status, ""));
        Assert.Null(await sut.CheckAsync("t"));
    }

    [Fact]
    public async Task CheckAsync_NetworkException_ReturnsNull()
    {
        var sut = Create(FakeHttpMessageHandler.Throws(new HttpRequestException("boom")));
        Assert.Null(await sut.CheckAsync("t"));
    }

    [Fact]
    public async Task CheckAsync_InvalidTagFormat_ReturnsNull()
    {
        var json = """{"tag_name":"release-foo","html_url":"https://x","body":""}""";
        var sut = Create(FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json));
        Assert.Null(await sut.CheckAsync("t"));
    }

    [Fact]
    public async Task CheckAsync_MalformedJson_ReturnsNull()
    {
        var sut = Create(FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, "not json"));
        Assert.Null(await sut.CheckAsync("t"));
    }

    [Fact]
    public async Task CheckAsync_MissingFields_ReturnsNull()
    {
        var json = """{"tag_name":"v2.0.0"}""";
        var sut = Create(FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json));
        Assert.Null(await sut.CheckAsync("t"));
    }

    [Fact]
    public async Task DownloadAsync_NotificationOnlyMode_ThrowsInvalidOperationException()
    {
        var service = new UpdateCheckService();
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.DownloadAsync());
    }

    [Fact]
    public void ApplyAndRestart_NotificationOnlyMode_ThrowsInvalidOperationException()
    {
        var service = new UpdateCheckService();
        Assert.Throws<InvalidOperationException>(() => service.ApplyAndRestart());
    }
}
