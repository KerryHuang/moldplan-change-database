using NSubstitute;
using NSubstitute.ExceptionExtensions;
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class FeatureReportServiceTests
{
    private readonly IConnectionSourceService _connectionSource;
    private readonly IFeatureQueryService _featureQuery;
    private readonly FeatureReportService _sut;

    public FeatureReportServiceTests()
    {
        _connectionSource = Substitute.For<IConnectionSourceService>();
        _featureQuery = Substitute.For<IFeatureQueryService>();
        _sut = new FeatureReportService(_connectionSource, _featureQuery);
    }

    [Fact]
    public async Task QueryAllCustomerFeaturesAsync_ReturnsAllCustomerData()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma-staging", Username = "u", Password = "p" },
            new() { Name = "WayDoSoft01-Test", Server = "2.2.2.2", Database = "wd01-test", Username = "u", Password = "p" }
        };
        _connectionSource.LoadAllConnections().Returns(profiles);

        var gmaFeatures = new List<FeatureEntry>
        {
            new() { SysType = "刀具", ItemId = "TOL010", ItemDesc = "刀具基本資料作業", AppFile = "TOL010", OpenYn = "Y" }
        };
        var wd01Features = new List<FeatureEntry>
        {
            new() { SysType = "刀具", ItemId = "TOL010", ItemDesc = "刀具基本資料作業", AppFile = "TOL010", OpenYn = "Y" },
            new() { SysType = "外包", ItemId = "PUR050", ItemDesc = "外包出廠作業", AppFile = "PUR050", OpenYn = "N" }
        };
        _featureQuery.QueryFeaturesAsync(profiles[0]).Returns(gmaFeatures);
        _featureQuery.QueryFeaturesAsync(profiles[1]).Returns(wd01Features);

        var result = await _sut.QueryAllCustomerFeaturesAsync();

        Assert.Equal(2, result.Customers.Count);
        Assert.Equal("Gma", result.Customers[0].Code);
        Assert.Equal("WayDoSoft01", result.Customers[1].Code);
        Assert.Single(result.Customers[0].Features);
        Assert.Equal(2, result.Customers[1].Features.Count);
        Assert.Empty(result.FailedConnections);
    }

    [Fact]
    public async Task QueryAllCustomerFeaturesAsync_PartialFailure_ReturnsSuccessAndFailures()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma-staging", Username = "u", Password = "p" },
            new() { Name = "Bad-Staging", Server = "0.0.0.0", Database = "bad", Username = "u", Password = "p" }
        };
        _connectionSource.LoadAllConnections().Returns(profiles);

        _featureQuery.QueryFeaturesAsync(profiles[0]).Returns(new List<FeatureEntry>
        {
            new() { SysType = "刀具", ItemId = "TOL010", ItemDesc = "刀具", AppFile = "TOL010", OpenYn = "Y" }
        });
        _featureQuery.QueryFeaturesAsync(profiles[1]).ThrowsAsync(new Exception("Connection failed"));

        var result = await _sut.QueryAllCustomerFeaturesAsync();

        Assert.Single(result.Customers);
        Assert.Single(result.FailedConnections);
        Assert.Equal("Bad-Staging", result.FailedConnections[0]);
    }

    [Fact]
    public async Task QueryAllCustomerFeaturesAsync_AllFailure_ReturnsEmpty()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Bad-Staging", Server = "0.0.0.0", Database = "bad", Username = "u", Password = "p" }
        };
        _connectionSource.LoadAllConnections().Returns(profiles);
        _featureQuery.QueryFeaturesAsync(profiles[0]).ThrowsAsync(new Exception("fail"));

        var result = await _sut.QueryAllCustomerFeaturesAsync();

        Assert.Empty(result.Customers);
        Assert.Single(result.FailedConnections);
    }

    [Fact]
    public async Task QueryAllCustomerFeaturesAsync_EmptyFeatures_ExcludedFromCustomers()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "WDMIS", Server = "1.1.1.1", Database = "MoldPlanDataModel", Username = "u", Password = "p" },
            new() { Name = "Gma-Staging", Server = "2.2.2.2", Database = "gma-staging", Username = "u", Password = "p" }
        };
        _connectionSource.LoadAllConnections().Returns(profiles);

        // WDMIS 的 SYS013 為空
        _featureQuery.QueryFeaturesAsync(profiles[0]).Returns(new List<FeatureEntry>());
        _featureQuery.QueryFeaturesAsync(profiles[1]).Returns(new List<FeatureEntry>
        {
            new() { SysType = "刀具", ItemId = "TOL010", ItemDesc = "刀具", AppFile = "TOL010", OpenYn = "Y" }
        });

        var result = await _sut.QueryAllCustomerFeaturesAsync();

        Assert.Single(result.Customers);
        Assert.Equal("Gma", result.Customers[0].Code);
        Assert.Single(result.SkippedConnections);
        Assert.Equal("WDMIS", result.SkippedConnections[0]);
    }

    [Fact]
    public async Task QueryAllCustomerFeaturesAsync_ReportsProgress()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" }
        };
        _connectionSource.LoadAllConnections().Returns(profiles);
        _featureQuery.QueryFeaturesAsync(profiles[0]).Returns(new List<FeatureEntry>());

        var messages = new List<string>();
        var progress = new Progress<string>(msg => messages.Add(msg));

        await _sut.QueryAllCustomerFeaturesAsync(progress);

        // Progress 是異步回調，給一點時間
        await Task.Delay(100);
        Assert.NotEmpty(messages);
    }
}
