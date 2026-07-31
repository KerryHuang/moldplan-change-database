using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Services.AnsibleSync;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.ViewModels.Documents;

/// <summary>連線切換主頁文件 ViewModel（不可關閉的 home document）。</summary>
public partial class ConnectionSwitchDocumentViewModel : DocumentViewModel
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
    private List<ConnectionProfile> _ansibleConnections = [];

    public override string DocumentType => "ConnectionSwitch";
    public override bool CanClose => false;

    [ObservableProperty]
    private ObservableCollection<ConnectionProfile> _connections = [];

    [ObservableProperty]
    private ConnectionProfile? _selectedConnection;

    [ObservableProperty]
    private ObservableCollection<ServerTxtFileItem> _serverTxtFiles = [];

    [ObservableProperty]
    private string _previewBefore = string.Empty;

    [ObservableProperty]
    private string _previewAfter = string.Empty;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private bool _showSpecurai = true;

    [ObservableProperty]
    private bool _showCustom = true;

    [ObservableProperty]
    private bool _showAnsible = true;

    [ObservableProperty]
    private bool _isSyncingAnsible;

    [ObservableProperty]
    private bool _isExporting;

    [ObservableProperty]
    private string _progressText = string.Empty;

    public bool CanSyncAnsible =>
        !IsSyncingAnsible &&
        !string.IsNullOrWhiteSpace(_appSettingsService.Load().AnsibleRepoPath);

    partial void OnIsSyncingAnsibleChanged(bool value) => OnPropertyChanged(nameof(CanSyncAnsible));

    public void NotifyCanSyncAnsibleChanged() => OnPropertyChanged(nameof(CanSyncAnsible));

    public bool HasDevDirectory =>
        !string.IsNullOrWhiteSpace(_appSettingsService.Load().DevDirectory);

    public void NotifyHasDevDirectoryChanged() => OnPropertyChanged(nameof(HasDevDirectory));

    public Func<IReadOnlyList<string>, ConnectionProfile, Task<IReadOnlyList<string>?>>? ApplyDevDialogCallback { get; set; }

    /// <summary>Production 重大操作的確認回呼（由 View 設定）。參數：(訊息, 警告橫幅)。</summary>
    public Func<string, string?, Task<bool>>? ConfirmCallback { get; set; }

    public Func<Task<string?>>? SaveFileCallback { get; set; }
    public Func<Task<string?>>? SaveUsageReportCallback { get; set; }
    public Func<Task<ReportSourceOptions?>>? ReportSourceCallback { get; set; }

    public IConnectionExportService ConnectionExportService => _connectionExportService;
    public ISettingsService SettingsServicePublic => _settingsService;

    public ConnectionSwitchDocumentViewModel(
        IConnectionSourceService connectionSource,
        IServerTxtService serverTxtService,
        ISettingsService settingsService,
        IFeatureReportService featureReportService,
        IConnectionExportService connectionExportService,
        IUsageReportService usageReportService,
        IAnsibleSyncService ansibleSyncService,
        IAppSettingsService appSettingsService,
        IAppSettingsDevService appSettingsDevService,
        ISqlConnectionFactory connectionFactory,
        IActiveConnectionService activeConnection)
    {
        _connectionSource = connectionSource;
        _serverTxtService = serverTxtService;
        _settingsService = settingsService;
        _featureReportService = featureReportService;
        _connectionExportService = connectionExportService;
        _usageReportService = usageReportService;
        _ansibleSyncService = ansibleSyncService;
        _appSettingsService = appSettingsService;
        _appSettingsDevService = appSettingsDevService;
        _connectionFactory = connectionFactory;
        _activeConnection = activeConnection;

        Title = "連線切換";

        LoadConnections();
        DiscoverServerTxtFiles();
    }

    partial void OnSelectedConnectionChanged(ConnectionProfile? value)
    {
        UpdatePreview();
        if (value == null) return;
        var connStr = _connectionFactory.Create(value).ConnectionString;
        _activeConnection.SetCurrent(new ActiveConnection(connStr, value.Database, value));
    }

    partial void OnShowSpecuraiChanged(bool value) => LoadConnections();
    partial void OnShowCustomChanged(bool value) => LoadConnections();
    partial void OnShowAnsibleChanged(bool value) => LoadConnections();

    [RelayCommand]
    private void LoadConnections()
    {
        var all = new List<ConnectionProfile>();
        if (ShowSpecurai)
            all.AddRange(_connectionSource.LoadSpecuraiConnections());
        if (ShowCustom)
            all.AddRange(_connectionSource.LoadCustomConnections());
        if (ShowAnsible)
            all.AddRange(_ansibleConnections);

        Connections = new ObservableCollection<ConnectionProfile>(
            all.OrderBy(p => p, ConnectionProfileComparer.Instance));
        SelectedConnection = Connections.FirstOrDefault();
    }

    [RelayCommand]
    private async Task SyncAnsible()
    {
        IsSyncingAnsible = true;
        StatusMessage = "正在從 MoldPlan Center 同步連線...";
        try
        {
            var result = await _ansibleSyncService.SyncAsync();
            _ansibleConnections = result.Profiles;
            LoadConnections();
            StatusMessage = result.SkippedEntries.Count == 0
                ? $"已同步 {result.Profiles.Count} 個 MoldPlan Center 連線"
                : $"已同步 {result.Profiles.Count} 個 MoldPlan Center 連線"
                  + $"（略過 {result.SkippedEntries.Count} 筆：{string.Join(", ", result.SkippedEntries)}）";
        }
        catch (Exception ex)
        {
            StatusMessage = $"同步失敗：{ex.Message}";
        }
        finally
        {
            IsSyncingAnsible = false;
        }
    }

    [RelayCommand]
    private void DiscoverServerTxtFiles()
    {
        var paths = _serverTxtService.DiscoverPaths();
        ServerTxtFiles = new ObservableCollection<ServerTxtFileItem>(
            paths.Select(p => new ServerTxtFileItem { Path = p, IsSelected = true }));

        if (paths.Count == 0)
            StatusMessage = "找不到 SERVER.txt 檔案";

        UpdatePreview();
    }

    private void UpdatePreview()
    {
        if (SelectedConnection is null || ServerTxtFiles.Count == 0)
        {
            PreviewBefore = string.Empty;
            PreviewAfter = string.Empty;
            return;
        }

        var firstSelected = ServerTxtFiles.FirstOrDefault(f => f.IsSelected);
        if (firstSelected is null) return;

        var entry = _serverTxtService.ReadEntry(firstSelected.Path);
        if (entry is null) return;

        PreviewBefore = entry.ToLine();
        PreviewAfter = _serverTxtService.Preview(entry, SelectedConnection);
    }

    [RelayCommand]
    private async Task ApplyChanges()
    {
        if (SelectedConnection is null)
        {
            StatusMessage = "請先選擇一個連線設定";
            return;
        }

        var selectedFiles = ServerTxtFiles.Where(f => f.IsSelected).ToList();
        if (selectedFiles.Count == 0)
        {
            StatusMessage = "請至少選擇一個 SERVER.txt 檔案";
            return;
        }

        if (SelectedConnection.Environment == DatabaseEnvironment.Production && ConfirmCallback is not null)
        {
            var confirmed = await ConfirmCallback(
                $"確定要將 SERVER.txt 指向「{SelectedConnection.Name}」嗎？",
                $"⚠ 正式環境 (Production)：{SelectedConnection.Database}");
            if (!confirmed)
            {
                StatusMessage = "已取消套用";
                return;
            }
        }

        var successCount = 0;
        var failCount = 0;

        foreach (var file in selectedFiles)
        {
            if (_serverTxtService.Apply(file.Path, SelectedConnection))
                successCount++;
            else
                failCount++;
        }

        if (failCount == 0)
            StatusMessage = $"已成功更新 {successCount} 個檔案";
        else
            StatusMessage = $"完成：{successCount} 個成功，{failCount} 個失敗";

        UpdatePreview();
    }

    [RelayCommand]
    private async Task ApplyDevAsync()
    {
        if (SelectedConnection is null) return;

        var devDir = _appSettingsService.Load().DevDirectory;
        var files = _appSettingsDevService.FindFiles(devDir);

        if (ApplyDevDialogCallback is null) return;
        var selected = await ApplyDevDialogCallback(files, SelectedConnection);
        if (selected is null) return;

        var success = 0;
        var fail = 0;
        foreach (var path in selected)
        {
            if (_appSettingsDevService.Apply(path, SelectedConnection))
                success++;
            else
                fail++;
        }

        StatusMessage = fail == 0
            ? $"套用完成：已更新 {success} 個檔案"
            : $"套用完成：{success} 成功，{fail} 失敗";
    }

    [RelayCommand]
    private async Task ExportFeatureReport()
    {
        IsExporting = true;
        ProgressText = "正在查詢客戶功能...";

        try
        {
            var sourceOptions = ReportSourceCallback != null
                ? await ReportSourceCallback()
                : ReportSourceOptions.AllSelected;

            if (sourceOptions is null)
            {
                StatusMessage = "已取消匯出";
                return;
            }

            var profiles = FilterConnectionsForReport(sourceOptions);
            if (profiles.Count == 0)
            {
                StatusMessage = "沒有符合條件的連線";
                return;
            }

            var progress = new Progress<string>(msg => ProgressText = msg);
            var data = await _featureReportService.QueryAllCustomerFeaturesAsync(profiles, progress);

            if (data.Customers.Count == 0)
            {
                StatusMessage = $"所有連線查詢失敗：{string.Join(", ", data.FailedConnections)}";
                return;
            }

            var path = SaveFileCallback != null ? await SaveFileCallback() : null;
            if (path is null)
            {
                StatusMessage = "已取消匯出";
                return;
            }

            ProgressText = "正在產出 Excel...";
            await _featureReportService.ExportToExcelAsync(path, data);

            var msg = $"已成功匯出至 {path}";
            if (data.SkippedConnections.Count > 0)
                msg += $"（{data.SkippedConnections.Count} 個連線無資料已跳過：{string.Join(", ", data.SkippedConnections)}）";
            if (data.FailedConnections.Count > 0)
                msg += $"（{data.FailedConnections.Count} 個連線失敗：{string.Join(", ", data.FailedConnections)}）";
            StatusMessage = msg;
        }
        catch (Exception ex)
        {
            StatusMessage = $"匯出失敗：{ex.Message}";
        }
        finally
        {
            IsExporting = false;
            ProgressText = string.Empty;
        }
    }

    [RelayCommand]
    private async Task ExportUsageReport()
    {
        IsExporting = true;
        ProgressText = "正在查詢使用次數...";

        try
        {
            var sourceOptions = ReportSourceCallback != null
                ? await ReportSourceCallback()
                : ReportSourceOptions.AllSelected;

            if (sourceOptions is null)
            {
                StatusMessage = "已取消匯出";
                return;
            }

            var profiles = FilterConnectionsForReport(sourceOptions);
            if (profiles.Count == 0)
            {
                StatusMessage = "沒有符合條件的連線";
                return;
            }

            var progress = new Progress<string>(msg => ProgressText = msg);
            var data = await _usageReportService.QueryAllAsync(profiles, progress);

            if (data.Rows.Count == 0)
            {
                StatusMessage = $"所有連線查詢失敗或無資料：{string.Join(", ", data.FailedConnections)}";
                return;
            }

            var path = SaveUsageReportCallback != null ? await SaveUsageReportCallback() : null;
            if (path is null)
            {
                StatusMessage = "已取消匯出";
                return;
            }

            ProgressText = "正在產出 Excel...";
            await _usageReportService.ExportToExcelAsync(path, data);

            var msg = $"已成功匯出至 {path}";
            if (data.SkippedConnections.Count > 0)
                msg += $"（{data.SkippedConnections.Count} 個連線無資料已跳過：{string.Join(", ", data.SkippedConnections)}）";
            if (data.FailedConnections.Count > 0)
                msg += $"（{data.FailedConnections.Count} 個連線失敗：{string.Join(", ", data.FailedConnections)}）";
            StatusMessage = msg;
        }
        catch (Exception ex)
        {
            StatusMessage = $"匯出失敗：{ex.Message}";
        }
        finally
        {
            IsExporting = false;
            ProgressText = string.Empty;
        }
    }

    [RelayCommand]
    private void RefreshAll()
    {
        LoadConnections();
        DiscoverServerTxtFiles();
        StatusMessage = "已重新整理";
    }

    public void AddCustomConnection(string name, string server, string database, DatabaseEnvironment environment)
    {
        var profile = new ConnectionProfile
        {
            Name = name,
            Server = server,
            Database = database,
            Environment = environment
        };
        _settingsService.AddProfile(profile);
        LoadConnections();
        StatusMessage = $"已新增自訂連線：{name}";
    }

    public async Task DeleteCustomConnection(ConnectionProfile profile)
    {
        if (profile.Source != "Custom") return;

        if (profile.Environment == DatabaseEnvironment.Production && ConfirmCallback is not null)
        {
            var confirmed = await ConfirmCallback(
                $"確定要刪除自訂連線「{profile.Name}」嗎？",
                $"⚠ 正式環境 (Production)：{profile.Database}");
            if (!confirmed) return;
        }

        _settingsService.DeleteProfile(profile.Id);
        LoadConnections();
        StatusMessage = $"已刪除自訂連線：{profile.Name}";
    }

    public IReadOnlyList<ConnectionProfile> GetConnectionsForExport()
        => Connections
            .Where(c => c.Source is "Custom" or "MoldPlan Center")
            .ToList();

    public IReadOnlyList<ConnectionProfile> GetCustomConnections()
        => Connections.Where(c => c.Source == "Custom").ToList();

    public ReportSourceOptions GetAvailableSources() => new(
        Specurai: Connections.Any(c => c.Source == "Specurai"),
        Custom: Connections.Any(c => c.Source == "Custom"),
        MoldPlanCenter: Connections.Any(c => c.Source == "MoldPlan Center"),
        Development: Connections.Any(c => c.Environment == DatabaseEnvironment.Development),
        Testing: Connections.Any(c => c.Environment == DatabaseEnvironment.Testing),
        Staging: Connections.Any(c => c.Environment == DatabaseEnvironment.Staging),
        Production: Connections.Any(c => c.Environment == DatabaseEnvironment.Production));

    public IReadOnlyList<ConnectionProfile> FilterConnectionsForReport(ReportSourceOptions options)
        => Connections.Where(c => MatchesSource(c, options) && MatchesEnvironment(c, options)).ToList();

    private static bool MatchesSource(ConnectionProfile c, ReportSourceOptions o) => c.Source switch
    {
        "Specurai" => o.Specurai,
        "Custom" => o.Custom,
        "MoldPlan Center" => o.MoldPlanCenter,
        _ => false
    };

    private static bool MatchesEnvironment(ConnectionProfile c, ReportSourceOptions o) => c.Environment switch
    {
        DatabaseEnvironment.Development => o.Development,
        DatabaseEnvironment.Testing => o.Testing,
        DatabaseEnvironment.Staging => o.Staging,
        DatabaseEnvironment.Production => o.Production,
        _ => false
    };
}
