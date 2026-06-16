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
        _connectionFactory.Create(Arg.Any<ConnectionProfile>()).Returns(
            new SqlConnection("Server=localhost;Database=test;User Id=sa;Password=pass;"));
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
        _connectionFactory, _activeConnection);

    private ReportingQueryViewModel CreateQuery() => new(
        _ => Substitute.For<IReportingObjectService>(),
        _ => Substitute.For<IReportingQueryService>(),
        "");

    private ReportingDeployViewModel CreateDeploy() => new(
        _ => Substitute.For<IReportingObjectService>(),
        _ => Substitute.For<IReportingDeployService>(),
        "", "");

    private MainWindowViewModel CreateVm() => new(
        CreateConnectionSwitch(),
        CreateQuery,
        CreateDeploy,
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
}
