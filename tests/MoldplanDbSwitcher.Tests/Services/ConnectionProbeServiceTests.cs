using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class ConnectionProbeServiceTests
{
    private readonly IConnectionTester _tester = Substitute.For<IConnectionTester>();

    private static ConnectionProfile P(string name) =>
        new() { Name = name, Server = "s", Database = "d" };

    [Fact]
    public async Task ProbeAsync_全部可連線_Unreachable為空()
    {
        _tester.CanConnectAsync(Arg.Any<ConnectionProfile>(), Arg.Any<CancellationToken>())
            .Returns(true);
        var sut = new ConnectionProbeService(_tester);

        var result = await sut.ProbeAsync([P("甲"), P("乙")]);

        Assert.Equal(2, result.Reachable.Count);
        Assert.Empty(result.Unreachable);
    }

    [Fact]
    public async Task ProbeAsync_部分不可連線_正確分成兩堆()
    {
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "通"), Arg.Any<CancellationToken>())
            .Returns(true);
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "不通"), Arg.Any<CancellationToken>())
            .Returns(false);
        var sut = new ConnectionProbeService(_tester);

        var result = await sut.ProbeAsync([P("通"), P("不通")]);

        Assert.Single(result.Reachable);
        Assert.Equal("通", result.Reachable[0].Name);
        Assert.Single(result.Unreachable);
        Assert.Equal("不通", result.Unreachable[0]);
    }

    [Fact]
    public async Task ProbeAsync_Reachable順序與輸入一致()
    {
        _tester.CanConnectAsync(Arg.Any<ConnectionProfile>(), Arg.Any<CancellationToken>())
            .Returns(true);
        var sut = new ConnectionProbeService(_tester);

        var result = await sut.ProbeAsync([P("甲"), P("乙"), P("丙"), P("丁")]);

        Assert.Equal(new[] { "甲", "乙", "丙", "丁" },
            result.Reachable.Select(p => p.Name).ToArray());
    }

    [Fact]
    public async Task ProbeAsync_完成順序與輸入相反_Reachable仍保序()
    {
        // 模擬不同延遲：第一個最久、最後一個最快完成
        // 藉此驗證即使完成順序相反，輸出仍保持輸入順序
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "甲"), Arg.Any<CancellationToken>())
            .Returns(_ => DelayedAsync(40, true));
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "乙"), Arg.Any<CancellationToken>())
            .Returns(_ => DelayedAsync(30, true));
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "丙"), Arg.Any<CancellationToken>())
            .Returns(_ => DelayedAsync(20, true));
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "丁"), Arg.Any<CancellationToken>())
            .Returns(_ => DelayedAsync(10, true));
        var sut = new ConnectionProbeService(_tester);

        var result = await sut.ProbeAsync([P("甲"), P("乙"), P("丙"), P("丁")]);

        // 即使丁、丙、乙、甲依序完成，輸出仍應維持輸入順序：甲、乙、丙、丁
        Assert.Equal(new[] { "甲", "乙", "丙", "丁" },
            result.Reachable.Select(p => p.Name).ToArray());
    }

    [Fact]
    public async Task ProbeAsync_回報可連線與跳過的數量()
    {
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "通"), Arg.Any<CancellationToken>())
            .Returns(true);
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "不通"), Arg.Any<CancellationToken>())
            .Returns(false);
        var sut = new ConnectionProbeService(_tester);
        var progress = new SyncProgress();

        await sut.ProbeAsync([P("通"), P("不通")], progress);

        Assert.Contains(progress.Messages, m => m.Contains("正在檢查 2 個連線"));
        Assert.Contains(progress.Messages, m => m.Contains("1 個可連線，跳過 1 個"));
    }

    /// <summary>建立延遲一段時間後回傳結果的 Task。用於驗證完成順序與輸入順序無關。</summary>
    private static async Task<bool> DelayedAsync(int milliseconds, bool result)
    {
        await Task.Delay(milliseconds);
        return result;
    }

    /// <summary>同步收集回報內容。用 Progress&lt;T&gt; 會經由 SynchronizationContext 非同步排程，
    /// 測試得靠 delay 等待，不穩定。</summary>
    private sealed class SyncProgress : IProgress<string>
    {
        public List<string> Messages { get; } = [];
        public void Report(string value) => Messages.Add(value);
    }
}
