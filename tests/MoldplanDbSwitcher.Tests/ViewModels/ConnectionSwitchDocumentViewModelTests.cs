using System.Collections.Generic;
using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Services.AnsibleSync;
using MoldplanDbSwitcher.ViewModels.Documents;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ConnectionSwitchDocumentViewModelTests
{
    private static ConnectionSwitchDocumentViewModel Create(
        IConnectionSourceService? source = null,
        IActiveConnectionService? active = null)
    {
        source ??= Substitute.For<IConnectionSourceService>();
        source.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>());
        source.LoadCustomConnections().Returns(new List<ConnectionProfile>());

        var serverTxt = Substitute.For<IServerTxtService>();
        serverTxt.DiscoverPaths().Returns(new List<string>());

        var settings = Substitute.For<ISettingsService>();
        var featureReport = Substitute.For<IFeatureReportService>();
        var export = Substitute.For<IConnectionExportService>();
        var usage = Substitute.For<IUsageReportService>();
        var ansible = Substitute.For<IAnsibleSyncService>();
        var appSettings = Substitute.For<IAppSettingsService>();
        appSettings.Load().Returns(new AppSettings());
        var appDev = Substitute.For<IAppSettingsDevService>();
        var factory = Substitute.For<ISqlConnectionFactory>();
        factory.Create(Arg.Any<ConnectionProfile>()).Returns(
            new SqlConnection("Server=localhost;Database=test;User Id=sa;Password=pass;"));
        active ??= new ActiveConnectionService();

        return new ConnectionSwitchDocumentViewModel(
            source, serverTxt, settings, featureReport, export, usage,
            ansible, appSettings, appDev, factory, active);
    }

    [Fact]
    public void DocumentType_IsConnectionSwitch_AndCannotClose()
    {
        var vm = Create();
        Assert.Equal("ConnectionSwitch", vm.DocumentType);
        Assert.False(vm.CanClose);
        Assert.Equal("連線切換", vm.Title);
    }

    [Fact]
    public void SelectingConnection_PushesToActiveConnectionService()
    {
        var source = Substitute.For<IConnectionSourceService>();
        source.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "A", Server = "S", Database = "DB1" }
        });
        source.LoadCustomConnections().Returns(new List<ConnectionProfile>());

        var factory = Substitute.For<ISqlConnectionFactory>();
        factory.Create(Arg.Any<ConnectionProfile>()).Returns(
            new SqlConnection("Server=S;Database=DB1;User Id=sa;Password=pass;"));

        var serverTxt = Substitute.For<IServerTxtService>();
        serverTxt.DiscoverPaths().Returns(new List<string>());

        var settings = Substitute.For<ISettingsService>();
        var featureReport = Substitute.For<IFeatureReportService>();
        var export = Substitute.For<IConnectionExportService>();
        var usage = Substitute.For<IUsageReportService>();
        var ansible = Substitute.For<IAnsibleSyncService>();
        var appSettings = Substitute.For<IAppSettingsService>();
        appSettings.Load().Returns(new AppSettings());
        var appDev = Substitute.For<IAppSettingsDevService>();

        var active = new ActiveConnectionService();
        ActiveConnection? pushed = null;
        active.Changed += c => pushed = c;

        var vm = new ConnectionSwitchDocumentViewModel(
            source, serverTxt, settings, featureReport, export, usage,
            ansible, appSettings, appDev, factory, active);

        Assert.NotNull(pushed);
        Assert.Equal("DB1", pushed!.Database);
    }
}
