using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Services.AnsibleSync;
using MoldplanDbSwitcher.ViewModels;
using MoldplanDbSwitcher.ViewModels.Documents;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ConnectionSwitchDocumentViewModelTests
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
    private readonly IConnectionProbeService _connectionProbe;
    private readonly IActiveConnectionService _activeConnection;

    public ConnectionSwitchDocumentViewModelTests()
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
        _connectionFactory.Create(Arg.Any<ConnectionProfile>(), Arg.Any<int?>()).Returns(
            new SqlConnection("Server=localhost;Database=test;User Id=sa;Password=pass;"));
        _connectionProbe = Substitute.For<IConnectionProbeService>();
        _connectionProbe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult(new ConnectionProbeResult(
                call.Arg<IReadOnlyList<ConnectionProfile>>().ToList(), [])));
        _activeConnection = new ActiveConnectionService();

        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Source = "Specurai" }
        });
        _connectionSource.LoadCustomConnections().Returns(new List<ConnectionProfile>());
        _serverTxtService.DiscoverPaths().Returns(new List<string>());
    }

    private ConnectionSwitchDocumentViewModel CreateVm() => new(
        _connectionSource, _serverTxtService, _settingsService,
        _featureReportService, _connectionExportService, _usageReportService,
        _ansibleSyncService, _appSettingsService, _appSettingsDevService,
        _connectionFactory, _connectionProbe, _activeConnection);

    // ── 原 Create() helper（供保留舊測試使用）────────────────────────────
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
        factory.Create(Arg.Any<ConnectionProfile>(), Arg.Any<int?>()).Returns(
            new SqlConnection("Server=localhost;Database=test;User Id=sa;Password=pass;"));
        active ??= new ActiveConnectionService();

        var probe = Substitute.For<IConnectionProbeService>();
        probe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult(new ConnectionProbeResult(
                call.Arg<IReadOnlyList<ConnectionProfile>>().ToList(), [])));

        return new ConnectionSwitchDocumentViewModel(
            source, serverTxt, settings, featureReport, export, usage,
            ansible, appSettings, appDev, factory, probe, active);
    }

    // ── 原有測試（shell 重構前已存在）────────────────────────────────────

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
        factory.Create(Arg.Any<ConnectionProfile>(), Arg.Any<int?>()).Returns(
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

        var probe = Substitute.For<IConnectionProbeService>();
        probe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult(new ConnectionProbeResult(
                call.Arg<IReadOnlyList<ConnectionProfile>>().ToList(), [])));

        var active = new ActiveConnectionService();
        ActiveConnection? pushed = null;
        active.Changed += c => pushed = c;

        var vm = new ConnectionSwitchDocumentViewModel(
            source, serverTxt, settings, featureReport, export, usage,
            ansible, appSettings, appDev, factory, probe, active);

        Assert.NotNull(pushed);
        Assert.Equal("DB1", pushed!.Database);
    }

    // ── 從 MainWindowViewModelTests 遷移的連線切換測試 ──────────────────

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
    public async Task ApplyChanges_NoSelection_SetsErrorStatus()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>());
        var vm = CreateVm();
        vm.SelectedConnection = null;

        await vm.ApplyChangesCommand.ExecuteAsync(null);

        Assert.Contains("請先選擇", vm.StatusMessage);
    }

    [Fact]
    public async Task ApplyChanges_NoServerTxtSelected_SetsErrorStatus()
    {
        var vm = CreateVm();

        await vm.ApplyChangesCommand.ExecuteAsync(null);

        Assert.Contains("請至少選擇", vm.StatusMessage);
    }

    [Fact]
    public async Task ApplyChanges_Success_SetsSuccessStatus()
    {
        _serverTxtService.DiscoverPaths().Returns(new List<string> { @"C:\WDMIS\SERVER.txt" });
        _serverTxtService.Apply(Arg.Any<string>(), Arg.Any<ConnectionProfile>()).Returns(true);
        _serverTxtService.ReadEntry(Arg.Any<string>()).Returns(new ServerTxtEntry
        {
            Field1 = "mis", DatabaseName = "old", ServerAddress = "0.0.0.0", Field4 = "X", Field5 = "1"
        });

        var vm = CreateVm();
        await vm.ApplyChangesCommand.ExecuteAsync(null);

        Assert.Contains("成功", vm.StatusMessage);
    }

    [Fact]
    public void AddCustomConnection_CallsSettingsService()
    {
        var vm = CreateVm();
        vm.AddCustomConnection("new", "10.0.0.1", "testdb", DatabaseEnvironment.Production);

        _settingsService.Received(1).AddProfile(Arg.Is<ConnectionProfile>(
            p => p.Name == "new" && p.Server == "10.0.0.1" && p.Database == "testdb"
              && p.Environment == DatabaseEnvironment.Production));
    }

    [Fact]
    public async Task DeleteCustomConnection_OnlyDeletesCustomSource()
    {
        var vm = CreateVm();
        var tableSpecProfile = new ConnectionProfile { Id = "1", Name = "dev", Source = "Specurai" };

        await vm.DeleteCustomConnection(tableSpecProfile);

        _settingsService.DidNotReceive().DeleteProfile(Arg.Any<string>());
    }

    [Fact]
    public async Task ApplyChanges_Production_確認回否_不寫SERVER_txt()
    {
        _serverTxtService.DiscoverPaths().Returns(new List<string> { @"C:\WDMIS\SERVER.txt" });
        _serverTxtService.ReadEntry(Arg.Any<string>()).Returns(new ServerTxtEntry
        { Field1 = "mis", DatabaseName = "old", ServerAddress = "0.0.0.0", Field4 = "X", Field5 = "1" });
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "prod", Server = "s", Database = "mis", Environment = DatabaseEnvironment.Production, Source = "Specurai" }
        });
        var vm = CreateVm();
        vm.ConfirmCallback = (_, _) => Task.FromResult(false);

        await vm.ApplyChangesCommand.ExecuteAsync(null);

        _serverTxtService.DidNotReceive().Apply(Arg.Any<string>(), Arg.Any<ConnectionProfile>());
        Assert.Contains("取消", vm.StatusMessage);
    }

    [Fact]
    public async Task ApplyChanges_Production_確認回是_有寫SERVER_txt()
    {
        _serverTxtService.DiscoverPaths().Returns(new List<string> { @"C:\WDMIS\SERVER.txt" });
        _serverTxtService.Apply(Arg.Any<string>(), Arg.Any<ConnectionProfile>()).Returns(true);
        _serverTxtService.ReadEntry(Arg.Any<string>()).Returns(new ServerTxtEntry
        { Field1 = "mis", DatabaseName = "old", ServerAddress = "0.0.0.0", Field4 = "X", Field5 = "1" });
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "prod", Server = "s", Database = "mis", Environment = DatabaseEnvironment.Production, Source = "Specurai" }
        });
        var vm = CreateVm();
        vm.ConfirmCallback = (_, _) => Task.FromResult(true);

        await vm.ApplyChangesCommand.ExecuteAsync(null);

        _serverTxtService.Received().Apply(Arg.Any<string>(), Arg.Any<ConnectionProfile>());
    }

    [Fact]
    public async Task DeleteCustomConnection_Production_確認回否_不刪除()
    {
        var vm = CreateVm();
        vm.ConfirmCallback = (_, _) => Task.FromResult(false);
        var profile = new ConnectionProfile { Id = "9", Name = "prod", Server = "s", Database = "d",
            Environment = DatabaseEnvironment.Production, Source = "Custom" };

        await vm.DeleteCustomConnection(profile);

        _settingsService.DidNotReceive().DeleteProfile(Arg.Any<string>());
    }

    [Fact]
    public async Task ExportFeatureReport_SetsIsExporting()
    {
        _featureReportService.QueryAllCustomerFeaturesAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>())
            .Returns(new FeatureReportData());

        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);
        vm.SaveFileCallback = () => Task.FromResult<string?>(System.IO.Path.GetTempFileName());

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
        vm.SaveFileCallback = () => Task.FromResult<string?>(System.IO.Path.GetTempFileName());

        await vm.ExportFeatureReportCommand.ExecuteAsync(null);

        Assert.Contains("失敗", vm.StatusMessage);
    }

    [Fact]
    public void FilterConnectionsForReport_SpecuraiOnly_ReturnsOnlySpecurai()
    {
        var vm = CreateVm();
        var options = new ReportSourceOptions(
            Specurai: true, Custom: false, MoldPlanCenter: false,
            Development: true, Testing: true, Staging: true, Production: true);

        var result = vm.FilterConnectionsForReport(options);

        Assert.All(result, c => Assert.Equal("Specurai", c.Source));
    }

    [Fact]
    public void FilterConnectionsForReport_NoneSelected_ReturnsEmpty()
    {
        var vm = CreateVm();
        var options = new ReportSourceOptions(
            Specurai: false, Custom: false, MoldPlanCenter: false,
            Development: false, Testing: false, Staging: false, Production: false);

        var result = vm.FilterConnectionsForReport(options);

        Assert.Empty(result);
    }

    [Fact]
    public void FilterConnectionsForReport_來源命中但環境未勾_排除()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "預備連線", Server = "s", Database = "d",
                    Environment = DatabaseEnvironment.Staging, Source = "Specurai" }
        });
        var vm = CreateVm();
        var options = new ReportSourceOptions(
            Specurai: true, Custom: false, MoldPlanCenter: false,
            Development: false, Testing: true, Staging: false, Production: true);

        var result = vm.FilterConnectionsForReport(options);

        Assert.Empty(result);
    }

    [Fact]
    public void FilterConnectionsForReport_依Environment欄位判斷而非連線名稱()
    {
        // 名稱不含「正式」，但 Environment 是 Production，應被「正式」勾選命中
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "GMA-Prod", Server = "s", Database = "d",
                    Environment = DatabaseEnvironment.Production, Source = "Specurai" }
        });
        var vm = CreateVm();
        var options = new ReportSourceOptions(
            Specurai: true, Custom: false, MoldPlanCenter: false,
            Development: false, Testing: false, Staging: false, Production: true);

        var result = vm.FilterConnectionsForReport(options);

        Assert.Single(result);
        Assert.Equal("GMA-Prod", result[0].Name);
    }

    [Fact]
    public void GetAvailableSources_無開發環境連線_Development為false()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "測試連線", Server = "s", Database = "d",
                    Environment = DatabaseEnvironment.Testing, Source = "Specurai" }
        });
        var vm = CreateVm();

        var available = vm.GetAvailableSources();

        Assert.False(available.Development);
        Assert.True(available.Testing);
        Assert.False(available.Staging);
        Assert.False(available.Production);
    }

    [Fact]
    public async Task ExportFeatureReport_SourceCallbackReturnsNull_DoesNotQuery()
    {
        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(null);
        vm.SaveFileCallback = () => Task.FromResult<string?>(System.IO.Path.GetTempFileName());

        await vm.ExportFeatureReportCommand.ExecuteAsync(null);

        await _featureReportService.DidNotReceive().QueryAllCustomerFeaturesAsync(
            Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>());
    }

    [Fact]
    public async Task ExportUsageReport_SourceCallbackReturnsNull_DoesNotQuery()
    {
        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(null);
        vm.SaveUsageReportCallback = () => Task.FromResult<string?>(System.IO.Path.GetTempFileName());

        await vm.ExportUsageReportCommand.ExecuteAsync(null);

        await _usageReportService.DidNotReceive().QueryAllAsync(
            Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>());
    }

    [Fact]
    public void LoadConnections_應依預設環境名稱排序()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "zzz", Server = "s", Database = "d", Environment = DatabaseEnvironment.Production, Source = "Specurai" },
            new() { Name = "aaa", Server = "s", Database = "d", Environment = DatabaseEnvironment.Development, Source = "Specurai" },
            new() { Name = "def", Server = "s", Database = "d", Environment = DatabaseEnvironment.Production, IsDefault = true, Source = "Specurai" },
        });
        var vm = CreateVm();

        Assert.Equal(new[] { "def", "aaa", "zzz" }, vm.Connections.Select(c => c.Name).ToArray());
    }

    [Fact]
    public async Task SyncAnsible_原樣保留Service給的Environment()
    {
        _ansibleSyncService.SyncAsync().Returns(new AnsibleSyncResult(
            new List<ConnectionProfile>
            {
                new() { Name = "客戶A - 正式", Server = "s", Database = "d", Source = "MoldPlan Center", Environment = DatabaseEnvironment.Production },
                new() { Name = "客戶A - 預備", Server = "s", Database = "d", Source = "MoldPlan Center", Environment = DatabaseEnvironment.Staging },
            },
            new List<string>()));
        var vm = CreateVm();

        await vm.SyncAnsibleCommand.ExecuteAsync(null);

        var prod = vm.Connections.First(c => c.Name == "客戶A - 正式");
        var staging = vm.Connections.First(c => c.Name == "客戶A - 預備");
        Assert.Equal(DatabaseEnvironment.Production, prod.Environment);
        Assert.Equal(DatabaseEnvironment.Staging, staging.Environment);
    }

    [Fact]
    public async Task SyncAnsible_有略過項目_狀態訊息顯示略過清單()
    {
        _ansibleSyncService.SyncAsync().Returns(new AnsibleSyncResult(
            new List<ConnectionProfile>
            {
                new() { Name = "客戶A - 正式", Server = "s", Database = "d", Source = "MoldPlan Center", Environment = DatabaseEnvironment.Production },
            },
            new List<string> { "anchiao-production", "anchiao-staging" }));
        var vm = CreateVm();

        await vm.SyncAnsibleCommand.ExecuteAsync(null);

        Assert.Contains("略過 2 筆", vm.StatusMessage);
        Assert.Contains("anchiao-production", vm.StatusMessage);
        Assert.Contains("anchiao-staging", vm.StatusMessage);
    }

    [Fact]
    public async Task ExportUsageReport_有連線不通_只查詢可連線的()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "通", Server = "s", Database = "d", Source = "Specurai" },
            new() { Name = "不通", Server = "s", Database = "d", Source = "Specurai" },
        });
        _connectionProbe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult(new ConnectionProbeResult(
                call.Arg<IReadOnlyList<ConnectionProfile>>().Where(p => p.Name == "通").ToList(),
                ["不通"])));

        var reportData = new UsageReportData();
        reportData.FailedConnections.Add("通");
        _usageReportService.QueryAllAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>())
            .Returns(reportData);

        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);
        vm.SaveUsageReportCallback = () => Task.FromResult<string?>(System.IO.Path.GetTempFileName());

        await vm.ExportUsageReportCommand.ExecuteAsync(null);

        await _usageReportService.Received(1).QueryAllAsync(
            Arg.Is<IReadOnlyList<ConnectionProfile>>(list =>
                list.Count == 1 && list[0].Name == "通"),
            Arg.Any<IProgress<string>>());
    }

    [Fact]
    public async Task ExportFeatureReport_有連線不通_只查詢可連線的()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "通", Server = "s", Database = "d", Source = "Specurai" },
            new() { Name = "不通", Server = "s", Database = "d", Source = "Specurai" },
        });
        _connectionProbe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult(new ConnectionProbeResult(
                call.Arg<IReadOnlyList<ConnectionProfile>>().Where(p => p.Name == "通").ToList(),
                ["不通"])));

        var reportData = new FeatureReportData();
        _featureReportService.QueryAllCustomerFeaturesAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>())
            .Returns(reportData);

        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);
        vm.SaveFileCallback = () => Task.FromResult<string?>(System.IO.Path.GetTempFileName());

        await vm.ExportFeatureReportCommand.ExecuteAsync(null);

        await _featureReportService.Received(1).QueryAllCustomerFeaturesAsync(
            Arg.Is<IReadOnlyList<ConnectionProfile>>(list =>
                list.Count == 1 && list[0].Name == "通"),
            Arg.Any<IProgress<string>>());
    }

    [Fact]
    public async Task ExportUsageReport_全部連線不通_不查詢且顯示訊息()
    {
        _connectionProbe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(new ConnectionProbeResult([], ["dev"])));

        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);
        vm.SaveUsageReportCallback = () => Task.FromResult<string?>(System.IO.Path.GetTempFileName());

        await vm.ExportUsageReportCommand.ExecuteAsync(null);

        await _usageReportService.DidNotReceive().QueryAllAsync(
            Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>());
        Assert.Contains("無法連線", vm.StatusMessage);
    }
}
