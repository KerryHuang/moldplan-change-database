using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public partial class MainWindowViewModel : ObservableObject
{
    private readonly IConnectionSourceService _connectionSource;
    private readonly IServerTxtService _serverTxtService;
    private readonly ISettingsService _settingsService;

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
    private bool _showTableSpec = true;

    [ObservableProperty]
    private bool _showCustom = true;

    public MainWindowViewModel(
        IConnectionSourceService connectionSource,
        IServerTxtService serverTxtService,
        ISettingsService settingsService)
    {
        _connectionSource = connectionSource;
        _serverTxtService = serverTxtService;
        _settingsService = settingsService;

        LoadConnections();
        DiscoverServerTxtFiles();
    }

    partial void OnSelectedConnectionChanged(ConnectionProfile? value)
    {
        UpdatePreview();
    }

    partial void OnShowTableSpecChanged(bool value) => LoadConnections();
    partial void OnShowCustomChanged(bool value) => LoadConnections();

    [RelayCommand]
    private void LoadConnections()
    {
        var all = new List<ConnectionProfile>();
        if (ShowTableSpec)
            all.AddRange(_connectionSource.LoadTableSpecConnections());
        if (ShowCustom)
            all.AddRange(_connectionSource.LoadCustomConnections());

        Connections = new ObservableCollection<ConnectionProfile>(all);
        SelectedConnection = Connections.FirstOrDefault();
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
    private void ApplyChanges()
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
    private void RefreshAll()
    {
        LoadConnections();
        DiscoverServerTxtFiles();
        StatusMessage = "已重新整理";
    }

    public void AddCustomConnection(string name, string server, string database)
    {
        var profile = new ConnectionProfile
        {
            Name = name,
            Server = server,
            Database = database
        };
        _settingsService.AddProfile(profile);
        LoadConnections();
        StatusMessage = $"已新增自訂連線：{name}";
    }

    public void DeleteCustomConnection(ConnectionProfile profile)
    {
        if (profile.Source != "Custom") return;
        _settingsService.DeleteProfile(profile.Id);
        LoadConnections();
        StatusMessage = $"已刪除自訂連線：{profile.Name}";
    }
}

public partial class ServerTxtFileItem : ObservableObject
{
    [ObservableProperty]
    private string _path = string.Empty;

    [ObservableProperty]
    private bool _isSelected;
}
