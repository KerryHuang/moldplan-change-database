using NSubstitute;
using NSubstitute.ExceptionExtensions;
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class UsageReportServiceTests
{
    private readonly IUsageQueryService _usageQuery;
    private readonly UsageReportService _sut;

    public UsageReportServiceTests()
    {
        _usageQuery = Substitute.For<IUsageQueryService>();
        _sut = new UsageReportService(_usageQuery);
    }

    [Fact]
    public async Task QueryAllAsync_ReturnsRowsForAllCustomers()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" },
            new() { Name = "WayDoSoft01-Test", Server = "2.2.2.2", Database = "wd01", Username = "u", Password = "p" }
        };

        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>
            {
                new() { ProgNo = "TOL010", ProgName = "刀具基本資料", UsageMinutes = 120.5m, Count = 30 }
            });
        _usageQuery.QueryUsageAsync(profiles[1], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>
            {
                new() { ProgNo = "PUR050", ProgName = "外包出廠", UsageMinutes = 60.0m, Count = 15 },
                new() { ProgNo = "TOL010", ProgName = "刀具基本資料", UsageMinutes = 45.0m, Count = 10 }
            });

        var result = await _sut.QueryAllAsync(profiles);

        Assert.Equal(3, result.Rows.Count);
        Assert.Empty(result.FailedConnections);
        Assert.Empty(result.SkippedConnections);
        Assert.Equal("Gma-Staging", result.Rows[0].CustomerName);
    }

    [Fact]
    public async Task QueryAllAsync_FailedConnection_RecordsFailure()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" },
            new() { Name = "Bad-Staging", Server = "0.0.0.0", Database = "bad", Username = "u", Password = "p" }
        };

        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>
            {
                new() { ProgNo = "TOL010", ProgName = "刀具", UsageMinutes = 10m, Count = 5 }
            });
        _usageQuery.QueryUsageAsync(profiles[1], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .ThrowsAsync(new Exception("Connection failed"));

        var result = await _sut.QueryAllAsync(profiles);

        Assert.Single(result.Rows);
        Assert.Single(result.FailedConnections);
        Assert.Equal("Bad-Staging", result.FailedConnections[0]);
    }

    [Fact]
    public async Task QueryAllAsync_EmptyResult_RecordsSkipped()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Empty-Staging", Server = "1.1.1.1", Database = "empty", Username = "u", Password = "p" }
        };
        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>());

        var result = await _sut.QueryAllAsync(profiles);

        Assert.Empty(result.Rows);
        Assert.Single(result.SkippedConnections);
        Assert.Equal("Empty-Staging", result.SkippedConnections[0]);
    }

    [Fact]
    public async Task QueryAllAsync_ReportsProgress()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" }
        };
        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>());

        var messages = new List<string>();
        var progress = new Progress<string>(msg => messages.Add(msg));

        await _sut.QueryAllAsync(profiles, progress);
        await Task.Delay(100);

        Assert.NotEmpty(messages);
    }

    [Fact]
    public async Task QueryAllAsync_UsesDateRangeOfSixMonths()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" }
        };
        _usageQuery.QueryUsageAsync(Arg.Any<ConnectionProfile>(), Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>());

        await _sut.QueryAllAsync(profiles);

        await _usageQuery.Received(1).QueryUsageAsync(
            profiles[0],
            Arg.Is<DateTime>(d => d <= DateTime.Today.AddMonths(-6).AddDays(1)),
            Arg.Is<DateTime>(d => d.Date == DateTime.Today));
    }
}
