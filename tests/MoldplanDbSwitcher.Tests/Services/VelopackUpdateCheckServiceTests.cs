using System.Threading;
using Xunit;
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class VelopackUpdateCheckServiceTests
{
    private readonly IUpdateCheckService _fallback = Substitute.For<IUpdateCheckService>();

    // 測試環境不是 Velopack 安裝（IsInstalled=false），CheckAsync 應委派 fallback
    [Fact]
    public async Task CheckAsync_NotVelopackInstalled_DelegatesToFallback()
    {
        var expected = new UpdateInfo("9.9.9", "https://example.com", "notes");
        _fallback.CheckAsync("tok", Arg.Any<CancellationToken>()).Returns(expected);
        var service = new VelopackUpdateCheckService(_fallback);

        var result = await service.CheckAsync("tok");

        Assert.Equal(expected, result);
        await _fallback.Received(1).CheckAsync("tok", Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task DownloadAsync_NoUpdateDetected_ThrowsInvalidOperationException()
    {
        var service = new VelopackUpdateCheckService(_fallback);
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.DownloadAsync());
    }

    [Fact]
    public void ApplyAndRestart_NoUpdateDetected_ThrowsInvalidOperationException()
    {
        var service = new VelopackUpdateCheckService(_fallback);
        Assert.Throws<InvalidOperationException>(() => service.ApplyAndRestart());
    }
}
