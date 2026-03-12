using Xunit;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class FeatureModelsTests
{
    [Fact]
    public void CustomerFeatureData_ParseCode_RemovesStagingSuffix()
    {
        var data = CustomerFeatureData.FromConnectionName("Gma-Staging", "gma-staging");
        Assert.Equal("Gma", data.Code);
        Assert.Equal("Gma", data.CustomerName);
        Assert.Equal("gma-staging", data.Database);
    }

    [Fact]
    public void CustomerFeatureData_ParseCode_RemovesTestSuffix()
    {
        var data = CustomerFeatureData.FromConnectionName("WayDoSoft01-Test", "waydosoft01-test");
        Assert.Equal("WayDoSoft01", data.Code);
        Assert.Equal("WayDoSoft01", data.CustomerName);
    }

    [Fact]
    public void CustomerFeatureData_ParseCode_NoSuffix_ReturnsAsIs()
    {
        var data = CustomerFeatureData.FromConnectionName("WDMIS", "MoldPlanDataModel");
        Assert.Equal("WDMIS", data.Code);
    }

    [Fact]
    public void FeatureEntry_Properties_SetCorrectly()
    {
        var entry = new FeatureEntry
        {
            SysType = "刀具",
            ItemId = "TOL010",
            ItemDesc = "刀具基本資料作業",
            AppFile = "TOL010",
            OpenYn = "Y"
        };

        Assert.Equal("刀具", entry.SysType);
        Assert.Equal("TOL010", entry.ItemId);
        Assert.Equal("Y", entry.OpenYn);
    }

    [Fact]
    public void FeatureReportData_EmptyByDefault()
    {
        var report = new FeatureReportData();
        Assert.Empty(report.Customers);
        Assert.Empty(report.FailedConnections);
    }
}
