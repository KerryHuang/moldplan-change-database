using Xunit;
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Services.AnsibleSync;
using MoldplanDbSwitcher.ViewModels;
using Microsoft.Data.SqlClient;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class MainWindowViewModelTests
{
    private readonly IConnectionSourceService _connectionSource;
    private readonly IServerTxtService _serverTxtService;
    private readonly ISettingsService _settingsService;
    private readonly IFeatureReportService _featureReportService;
    private readonly IConnectionExportService _connectionExportService;
    private readonly IUsageReportService _usageReportService;
    private readonly IAnsibleSyncService _ansibleSyncService;
    private readonly IAppSettingsService _appSettingsService;
    private readonly IAppSettingsDevService _appSettingsDevService;
    private readonly ISqlConnectionFactory _connectionFactory;
    private readonly ReportingQueryViewModel _reportingQuery;
    private readonly ReportingDeployViewModel _reportingDeploy;

    public MainWindowViewModelTests()
    {
        _connectionSource = Substitute.For<IConnectionSourceService>();
        _serverTxtService = Substitute.For<IServerTxtService>();
        _settingsService = Substitute.For<ISettingsService>();
        _featureReportService = Substitute.For<IFeatureReportService>();
        _connectionExportService = Substitute.For<IConnectionExportService>();
        _usageReportService = Substitute.For<IUsageReportService>();
        _ansibleSyncService = Substitute.For<IAnsibleSyncService>();
        _appSettingsService = Substitute.For<IAppSettingsService>();
        _appSettingsService.Load().Returns(new AppSettings());
        _appSettingsDevService = Substitute.For<IAppSettingsDevService>();
        _connectionFactory = Substitute.For<ISqlConnectionFactory>();
        _connectionFactory.Create(Arg.Any<ConnectionProfile>()).Returns(
            new SqlConnection("Server=localhost;Database=test;User Id=sa;Password=pass;"));
        _reportingQuery = new ReportingQueryViewModel(
            _ => Substitute.For<IReportingObjectService>(),
            _ => Substitute.For<IReportingQueryService>(),
            "");
        _reportingDeploy = new ReportingDeployViewModel(
            _ => Substitute.For<IReportingObjectService>(),
            _ => Substitute.For<IReportingDeployService>(),
            "", "");

        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Source = "Specurai" }
        });
        _connectionSource.LoadCustomConnections().Returns(new List<ConnectionProfile>());
        _serverTxtService.DiscoverPaths().Returns(new List<string>());
    }

    private MainWindowViewModel CreateVm() => new(
        _connectionSource, _serverTxtService, _settingsService,
        _featureReportService, _connectionExportService, _usageReportService,
        _ansibleSyncService, _appSettingsService, _appSettingsDevService,
        _connectionFactory, _reportingQuery, _reportingDeploy);

    [Fact]
    public void Constructor_LoadsConnections()
    {
        var vm = CreateVm();
        Assert.Single(vm.Connections);
        Assert.Equal("dev", vm.Connections[0].Name);
    }

    [Fact]
    public void Constructor_SetsFirstConnectionAsSelected()
    {
        var vm = CreateVm();
        Assert.NotNull(vm.SelectedConnection);
        Assert.Equal("dev", vm.SelectedConnection!.Name);
    }

    [Fact]
    public void ApplyChanges_NoSelection_SetsErrorStatus()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>());
        var vm = CreateVm();
        vm.SelectedConnection = null;

        vm.ApplyChangesCommand.Execute(null);

        Assert.Contains("請先選擇", vm.StatusMessage);
    }

    [Fact]
    public void ApplyChanges_NoServerTxtSelected_SetsErrorStatus()
    {
        var vm = CreateVm();

        vm.ApplyChangesCommand.Execute(null);

        Assert.Contains("請至少選擇", vm.StatusMessage);
    }

    [Fact]
    public void ApplyChanges_Success_SetsSuccessStatus()
    {
        _serverTxtService.DiscoverPaths().Returns(new List<string> { @"C:\WDMIS\SERVER.txt" });
        _serverTxtService.Apply(Arg.Any<string>(), Arg.Any<ConnectionProfile>()).Returns(true);
        _serverTxtService.ReadEntry(Arg.Any<string>()).Returns(new ServerTxtEntry
        {
            Field1 = "mis", DatabaseName = "old", ServerAddress = "0.0.0.0", Field4 = "X", Field5 = "1"
        });

        var vm = CreateVm();
        vm.ApplyChangesCommand.Execute(null);

        Assert.Contains("成功", vm.StatusMessage);
    }

    [Fact]
    public void AddCustomConnection_CallsSettingsService()
    {
        var vm = CreateVm();
        vm.AddCustomConnection("new", "10.0.0.1", "testdb");

        _settingsService.Received(1).AddProfile(Arg.Is<ConnectionProfile>(
            p => p.Name == "new" && p.Server == "10.0.0.1" && p.Database == "testdb"));
    }

    [Fact]
    public void DeleteCustomConnection_OnlyDeletesCustomSource()
    {
        var vm = CreateVm();
        var tableSpecProfile = new ConnectionProfile { Id = "1", Name = "dev", Source = "Specurai" };

        vm.DeleteCustomConnection(tableSpecProfile);

        _settingsService.DidNotReceive().DeleteProfile(Arg.Any<string>());
    }

    [Fact]
    public async Task ExportFeatureReport_SetsIsExporting()
    {
        _featureReportService.QueryAllCustomerFeaturesAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>())
            .Returns(new FeatureReportData());

        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);
        // 設定 SaveFileCallback 以避免 null
        vm.SaveFileCallback = () => Task.FromResult<string?>(Path.GetTempFileName());

        await vm.ExportFeatureReportCommand.ExecuteAsync(null);

        Assert.False(vm.IsExporting);
    }

    [Fact]
    public async Task ExportFeatureReport_NoSavePath_DoesNotExport()
    {
        _featureReportService.QueryAllCustomerFeaturesAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>())
            .Returns(new FeatureReportData());

        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);
        vm.SaveFileCallback = () => Task.FromResult<string?>(null);

        await vm.ExportFeatureReportCommand.ExecuteAsync(null);

        await _featureReportService.DidNotReceive().ExportToExcelAsync(Arg.Any<string>(), Arg.Any<FeatureReportData>());
    }

    [Fact]
    public void GetConnectionsForExport_ReturnsOnlyCustomConnections()
    {
        _connectionSource.LoadCustomConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "custom1", Server = "10.0.0.1", Database = "db1", Source = "Custom" }
        });
        var vm = CreateVm();
        var result = vm.GetConnectionsForExport();
        Assert.Single(result);
        Assert.Equal("custom1", result[0].Name);
    }

    [Fact]
    public void GetConnectionsForExport_ExcludesSpecuraiConnections()
    {
        var vm = CreateVm();
        var result = vm.GetConnectionsForExport();
        Assert.Empty(result); // 只有 Specurai 連線，應回傳空
    }

    [Fact]
    public async Task ExportFeatureReport_AllFailed_ShowsError()
    {
        var reportData = new FeatureReportData();
        reportData.FailedConnections.Add("Bad-Staging");
        _featureReportService.QueryAllCustomerFeaturesAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>())
            .Returns(reportData);

        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);
        vm.SaveFileCallback = () => Task.FromResult<string?>(Path.GetTempFileName());

        await vm.ExportFeatureReportCommand.ExecuteAsync(null);

        Assert.Contains("失敗", vm.StatusMessage);
    }

    [Fact]
    public void FilterConnectionsForReport_SpecuraiOnly_ReturnsOnlySpecurai()
    {
        var vm = CreateVm();
        var options = new ReportSourceOptions(Specurai: true, Custom: false, AnsibleProduction: false, AnsibleStaging: false);

        var result = vm.FilterConnectionsForReport(options);

        Assert.All(result, c => Assert.Equal("Specurai", c.Source));
    }

    [Fact]
    public void FilterConnectionsForReport_NoneSelected_ReturnsEmpty()
    {
        var vm = CreateVm();
        var options = new ReportSourceOptions(Specurai: false, Custom: false, AnsibleProduction: false, AnsibleStaging: false);

        var result = vm.FilterConnectionsForReport(options);

        Assert.Empty(result);
    }

    [Fact]
    public async Task ExportFeatureReport_SourceCallbackReturnsNull_DoesNotQuery()
    {
        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(null);
        vm.SaveFileCallback = () => Task.FromResult<string?>(Path.GetTempFileName());

        await vm.ExportFeatureReportCommand.ExecuteAsync(null);

        await _featureReportService.DidNotReceive().QueryAllCustomerFeaturesAsync(
            Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>());
    }

    [Fact]
    public async Task ExportUsageReport_SourceCallbackReturnsNull_DoesNotQuery()
    {
        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(null);
        vm.SaveUsageReportCallback = () => Task.FromResult<string?>(Path.GetTempFileName());

        await vm.ExportUsageReportCommand.ExecuteAsync(null);

        await _usageReportService.DidNotReceive().QueryAllAsync(
            Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>());
    }
}
