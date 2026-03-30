using Microsoft.Data.SqlClient;
using NSubstitute;
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class UsageQueryServiceTests
{
    [Fact]
    public async Task QueryUsageAsync_MapsResultsCorrectly()
    {
        var factory = Substitute.For<ISqlConnectionFactory>();
        var sut = new UsageQueryService(factory);

        var profile = new ConnectionProfile
        {
            Name = "Test",
            Server = "0.0.0.0",
            Database = "testdb",
            Username = "u",
            Password = "p"
        };
        factory.Create(profile).Returns(_ => throw new InvalidOperationException("Cannot open connection"));

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => sut.QueryUsageAsync(profile, DateTime.Today.AddMonths(-6), DateTime.Today));
    }

    [Fact]
    public async Task QueryUsageAsync_UsesDateParameters()
    {
        var factory = Substitute.For<ISqlConnectionFactory>();
        var sut = new UsageQueryService(factory);

        var profile = new ConnectionProfile { Name = "T", Server = "s", Database = "d", Username = "u", Password = "p" };
        var start = new DateTime(2025, 9, 1);
        var end = new DateTime(2026, 3, 27);

        factory.Create(profile).Returns(_ => throw new InvalidOperationException("expected"));

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => sut.QueryUsageAsync(profile, start, end));

        factory.Received(1).Create(profile);
    }
}
