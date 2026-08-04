using System.Net.Http;
using System.Threading;
using Xunit;
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Services.AnsibleSync;
using MoldplanDbSwitcher.ViewModels;
using MoldplanDbSwitcher.ViewModels.Documents;
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
    private readonly IConnectionProbeService _connectionProbe;
    private readonly IActiveConnectionService _activeConnection;
    private readonly IUpdateCheckService _updateCheckService;

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
        _connectionFactory.Create(Arg.Any<ConnectionProfile>(), Arg.Any<int?>()).Returns(
            new SqlConnection("Server=localhost;Database=test;User Id=sa;Password=pass;"));
        _connectionProbe = Substitute.For<IConnectionProbeService>();
        _connectionProbe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult(new ConnectionProbeResult(
                call.Arg<IReadOnlyList<ConnectionProfile>>().ToList(), [])));
        _activeConnection = new ActiveConnectionService();

        _updateCheckService = Substitute.For<IUpdateCheckService>();
        _updateCheckService.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
            .Returns((UpdateInfo?)null);

        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Source = "Specurai" }
        });
        _connectionSource.LoadCustomConnections().Returns(new List<ConnectionProfile>());
        _serverTxtService.DiscoverPaths().Returns(new List<string>());
    }

    private ConnectionSwitchDocumentViewModel CreateConnectionSwitch() => new(
        _connectionSource, _serverTxtService, _settingsService,
        _featureReportService, _connectionExportService, _usageReportService,
        _ansibleSyncService, _appSettingsService, _appSettingsDevService,
        _connectionFactory, _connectionProbe, _activeConnection);

    private ReportingQueryViewModel CreateQuery() => new(
        _ => Substitute.For<IReportingObjectService>(),
        _ => Substitute.For<IReportingQueryService>(),
        "");

    private ReportingDeployViewModel CreateDeploy()
    {
        var deploy = Substitute.For<IReportingDeployService>();
        deploy.ScanInstallStatusAsync(Arg.Any<CancellationToken>())
            .Returns(new ReportingInstallStatus(false, false, 0, 0, 0));
        return new ReportingDeployViewModel(_ => deploy, "", "");
    }

    private MonitoringDocumentViewModel CreateMonitor()
    {
        var monitor = Substitute.For<IJobMonitorService>();
        monitor.ListJobsAsync(Arg.Any<CancellationToken>()).Returns(new List<AgentJobStatus>());
        monitor.GetRefreshLogAsync(Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(new List<RefreshLogEntry>());
        return new MonitoringDocumentViewModel(_ => monitor, "");
    }

    private MainWindowViewModel CreateVm() => new(
        CreateConnectionSwitch(),
        CreateQuery,
        CreateDeploy,
        CreateMonitor,
        _activeConnection,
        _updateCheckService,
        _appSettingsService);

    [Fact]
    public void Startup_OpensConnectionSwitch_AsActiveDocument()
    {
        var vm = CreateVm();

        Assert.Single(vm.Documents);
        Assert.Equal("ConnectionSwitch", vm.Documents[0].DocumentType);
        Assert.Same(vm.Documents[0], vm.SelectedDocument);
    }

    [Fact]
    public void OpenReportingQuery_AddsDocument_AndActivates()
    {
        var vm = CreateVm();

        vm.OpenReportingQueryCommand.Execute(null);

        var doc = vm.Documents.FirstOrDefault(d => d.DocumentType == "ReportingQuery");
        Assert.NotNull(doc);
        Assert.Same(doc, vm.SelectedDocument);
    }

    [Fact]
    public void OpenReportingQuery_Twice_DoesNotDuplicate()
    {
        var vm = CreateVm();

        vm.OpenReportingQueryCommand.Execute(null);
        vm.OpenReportingQueryCommand.Execute(null);

        Assert.Single(vm.Documents, d => d.DocumentType == "ReportingQuery");
    }

    [Fact]
    public void CloseDocument_RemovesIt_ButKeepsPinnedHome()
    {
        var vm = CreateVm();
        vm.OpenReportingQueryCommand.Execute(null);
        var query = vm.Documents.First(d => d.DocumentType == "ReportingQuery");

        // 關閉可關閉的文件 → 移除
        query.CloseCommand.Execute(null);
        Assert.DoesNotContain(vm.Documents, d => d.DocumentType == "ReportingQuery");

        // 關閉主頁（CanClose=false）→ 仍保留
        var home = vm.Documents.First(d => d.DocumentType == "ConnectionSwitch");
        home.CloseCommand.Execute(null);
        Assert.Contains(vm.Documents, d => d.DocumentType == "ConnectionSwitch");
    }

    // ── 更新橫幅測試 ────────────────────────────────────────────────────

    private static async Task WaitForUpdateCheckAsync(MainWindowViewModel vm)
    {
        for (var i = 0; i < 50; i++)
        {
            if (vm.UpdateAvailable || vm.UpdateBannerText.Length > 0) return;
            await Task.Delay(20);
        }
    }

    [Fact]
    public async Task Ctor_UpdateAvailable_SetsBannerProperties()
    {
        _updateCheckService.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
            .Returns(new UpdateInfo("9.9.9", "https://x/release", "notes"));

        var vm = CreateVm();
        await WaitForUpdateCheckAsync(vm);

        Assert.True(vm.UpdateAvailable);
        Assert.Equal("https://x/release", vm.UpdateReleaseUrl);
        Assert.Contains("9.9.9", vm.UpdateBannerText);
    }

    [Fact]
    public async Task Ctor_NoUpdate_BannerHidden()
    {
        // Default fixture returns null
        var vm = CreateVm();
        await Task.Delay(100); // let fire-and-forget settle
        Assert.False(vm.UpdateAvailable);
    }

    [Fact]
    public async Task DismissUpdateCommand_HidesBanner()
    {
        _updateCheckService.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
            .Returns(new UpdateInfo("9.9.9", "https://x", ""));
        var vm = CreateVm();
        await WaitForUpdateCheckAsync(vm);

        vm.DismissUpdateCommand.Execute(null);

        Assert.False(vm.UpdateAvailable);
    }

    [Fact]
    public async Task AutoApplicableUpdate_DownloadsAutomatically_AndShowsRestartBanner()
    {
        _appSettingsService.Load().Returns(new AppSettings { GitHubToken = "tok" });
        _updateCheckService.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
            .Returns(new UpdateInfo("2.0.0", "https://example.com", "", CanAutoApply: true));

        var vm = CreateVm(); // 建構式內會觸發 CheckForUpdatesAsync
        await WaitForUpdateCheckAsync(vm);

        await _updateCheckService.Received(1).DownloadAsync(Arg.Any<IProgress<int>?>(), Arg.Any<CancellationToken>());
        Assert.True(vm.UpdateAvailable);
        Assert.True(vm.UpdateReadyToRestart);
        Assert.Contains("重啟", vm.UpdateBannerText);
    }

    [Fact]
    public async Task NotificationOnlyUpdate_KeepsExistingBanner_WithoutDownloading()
    {
        _appSettingsService.Load().Returns(new AppSettings { GitHubToken = "tok" });
        _updateCheckService.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
            .Returns(new UpdateInfo("2.0.0", "https://example.com/rel", ""));

        var vm = CreateVm();
        await WaitForUpdateCheckAsync(vm);

        await _updateCheckService.DidNotReceiveWithAnyArgs().DownloadAsync(default, default);
        Assert.True(vm.UpdateAvailable);
        Assert.False(vm.UpdateReadyToRestart);
        Assert.Equal("https://example.com/rel", vm.UpdateReleaseUrl);
    }

    [Fact]
    public async Task AutoDownloadFails_FallsBackToNotificationBanner()
    {
        // 下載失敗不該讓使用者完全看不到「有新版」的通知，應退回一般通知橫幅（不可一鍵重啟）
        _appSettingsService.Load().Returns(new AppSettings { GitHubToken = "tok" });
        _updateCheckService.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
            .Returns(new UpdateInfo("2.0.0", "https://example.com", "", CanAutoApply: true));
        _updateCheckService.DownloadAsync(Arg.Any<IProgress<int>?>(), Arg.Any<CancellationToken>())
            .Returns<Task>(_ => throw new HttpRequestException("網路中斷"));

        var vm = CreateVm();
        await WaitForUpdateCheckAsync(vm);

        Assert.True(vm.UpdateAvailable);
        Assert.False(vm.UpdateReadyToRestart);
        Assert.Contains("有新版", vm.UpdateBannerText);
    }

    [Fact]
    public void ApplyUpdateAndRestartCommand_CallsApplyAndRestart()
    {
        var vm = CreateVm();
        vm.ApplyUpdateAndRestartCommand.Execute(null);
        _updateCheckService.Received(1).ApplyAndRestart();
    }

    [Fact]
    public void OpenReportingMonitor_AddsDocument_AndActivates_Singleton()
    {
        var vm = CreateVm();
        vm.OpenReportingMonitorCommand.Execute(null);
        vm.OpenReportingMonitorCommand.Execute(null);
        Assert.Equal(1, vm.Documents.Count(d => d.DocumentType == "ReportingMonitor"));
        Assert.Equal("ReportingMonitor", vm.SelectedDocument!.DocumentType);
    }

    [Fact]
    public void ActiveConnectionChanged_PropagatesToOpenDocuments()
    {
        // 記錄 objectsFactory 被呼叫時收到的 connectionString
        var objectFactoryCalls = new List<string>();

        Func<ReportingQueryViewModel> queryFactory = () => new ReportingQueryViewModel(
            cs =>
            {
                objectFactoryCalls.Add($"obj:{cs}");
                var s = Substitute.For<IReportingObjectService>();
                s.ListTablesAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
                s.ListViewsAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
                s.ListProceduresAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
                return s;
            },
            _ => Substitute.For<IReportingQueryService>(),
            "");

        var active = new ActiveConnectionService();

        var vm = new MainWindowViewModel(
            CreateConnectionSwitch(),
            queryFactory,
            CreateDeploy,
            CreateMonitor,
            active,
            _updateCheckService,
            _appSettingsService);

        // 開啟一個 ReportingQuery 文件
        vm.OpenReportingQueryCommand.Execute(null);
        objectFactoryCalls.Clear(); // 清除初始化時的呼叫（空字串）

        // 設定新連線 → shell 應透過 OnActiveConnectionChanged 呼叫 doc.UseConnectionAsync
        active.SetCurrent(new ActiveConnection("Server=tcp:relay;Database=R", "R", null));

        // objectsFactory 在 UseConnectionAsync 一開始就同步呼叫，不需 await
        Assert.Contains("obj:Server=tcp:relay;Database=R", objectFactoryCalls);
    }
}
