using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels.Documents;

namespace MoldplanDbSwitcher.ViewModels;

public partial class MainWindowViewModel : ObservableObject
{
    private readonly Func<ReportingQueryViewModel> _queryFactory;
    private readonly Func<ReportingDeployViewModel> _deployFactory;
    private readonly Func<MonitoringDocumentViewModel> _monitorFactory;
    private readonly IActiveConnectionService _activeConnection;
    private readonly IUpdateCheckService _updateCheckService;
    private readonly IAppSettingsService _appSettingsService;

    public ConnectionSwitchDocumentViewModel ConnectionSwitch { get; }

    /// <summary>視窗標題：App 名稱 + 目前版本（與更新橫幅同一版本來源）</summary>
    public string WindowTitle { get; } =
        $"資料庫連線切換工具 v{Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "?"}";

    [ObservableProperty] private ObservableCollection<DocumentViewModel> _documents = [];
    [ObservableProperty] private DocumentViewModel? _selectedDocument;

    [ObservableProperty] private bool _updateAvailable;
    [ObservableProperty] private string _updateBannerText = "";
    [ObservableProperty] private string? _updateReleaseUrl;
    [ObservableProperty] private bool _updateReadyToRestart;

    public MainWindowViewModel(
        ConnectionSwitchDocumentViewModel connectionSwitch,
        Func<ReportingQueryViewModel> queryFactory,
        Func<ReportingDeployViewModel> deployFactory,
        Func<MonitoringDocumentViewModel> monitorFactory,
        IActiveConnectionService activeConnection,
        IUpdateCheckService updateCheckService,
        IAppSettingsService appSettingsService)
    {
        ConnectionSwitch = connectionSwitch;
        _queryFactory = queryFactory;
        _deployFactory = deployFactory;
        _monitorFactory = monitorFactory;
        _activeConnection = activeConnection;
        _updateCheckService = updateCheckService;
        _appSettingsService = appSettingsService;

        _activeConnection.Changed += OnActiveConnectionChanged;

        OpenDocument(connectionSwitch);   // 主頁
        _ = CheckForUpdatesAsync();
    }

    private void OnActiveConnectionChanged(ActiveConnection conn)
    {
        foreach (var doc in Documents)
            _ = doc.UseConnectionAsync(conn);
    }

    private T OpenOrActivate<T>(Func<T> factory) where T : DocumentViewModel
    {
        var existing = Documents.OfType<T>().FirstOrDefault();
        if (existing != null) { SelectedDocument = existing; return existing; }

        var doc = factory();
        OpenDocument(doc);
        if (_activeConnection.Current is { } cur)
            _ = doc.UseConnectionAsync(cur);
        return doc;
    }

    private void OpenDocument(DocumentViewModel doc)
    {
        doc.CloseRequested += OnDocumentCloseRequested;
        Documents.Add(doc);
        SelectedDocument = doc;
    }

    private void OnDocumentCloseRequested(DocumentViewModel doc)
    {
        if (!doc.CanClose) return;
        doc.CloseRequested -= OnDocumentCloseRequested;
        Documents.Remove(doc);
        if (SelectedDocument == doc)
            SelectedDocument = Documents.LastOrDefault();
    }

    [RelayCommand] private void OpenReportingQuery() => OpenOrActivate(_queryFactory);
    [RelayCommand] private void OpenReportingDeploy() => OpenOrActivate(_deployFactory);
    [RelayCommand] private void OpenReportingMonitor() => OpenOrActivate(_monitorFactory);

    private async Task CheckForUpdatesAsync()
    {
        try
        {
            var token = _appSettingsService.Load().GitHubToken;
            var info = await _updateCheckService.CheckAsync(token);
            if (info == null) return;
            UpdateReleaseUrl = info.ReleaseUrl;
            var current = Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "?";

            if (info.CanAutoApply)
            {
                try
                {
                    // 背景自動下載，完成後橫幅提供一鍵重啟
                    await _updateCheckService.DownloadAsync();
                    UpdateBannerText = $"⬇ 已下載 v{info.LatestVersion}（目前 v{current}），重啟以完成更新";
                    UpdateReadyToRestart = true;
                }
                catch
                {
                    // 下載失敗不代表沒有新版：仍要讓使用者看到通知，退回一般通知橫幅（不可一鍵重啟）
                    UpdateBannerText = $"🎉 有新版 v{info.LatestVersion} 可用（目前 v{current}）";
                }
            }
            else
            {
                UpdateBannerText = $"🎉 有新版 v{info.LatestVersion} 可用（目前 v{current}）";
            }

            UpdateAvailable = true;
        }
        catch { /* 靜音：檢查更新失敗不打擾使用者 */ }
    }

    [RelayCommand]
    private void ApplyUpdateAndRestart()
    {
        try { _updateCheckService.ApplyAndRestart(); }
        catch { /* 靜音 */ }
    }

    [RelayCommand] private void DismissUpdate() => UpdateAvailable = false;
}
