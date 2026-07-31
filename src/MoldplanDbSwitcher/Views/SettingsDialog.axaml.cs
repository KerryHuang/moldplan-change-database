using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Views;

public partial class SettingsDialog : Window
{
    private readonly IAppSettingsService _appSettingsService;

    public SettingsDialog(IAppSettingsService appSettingsService)
    {
        InitializeComponent();
        _appSettingsService = appSettingsService;

        var settings = _appSettingsService.Load();
        AnsibleRepoPathBox.Text = settings.AnsibleRepoPath;
        VaultPasswordFileBox.Text = settings.VaultPasswordFile;
        DevDirectoryBox.Text = settings.DevDirectory;
        GitHubTokenBox.Text = settings.GitHubToken ?? string.Empty;
        ReportingScriptsOverridePathBox.Text = settings.ReportingScriptsOverridePath;
    }

    private void OnSaveClick(object? sender, RoutedEventArgs e)
    {
        _appSettingsService.Save(new AppSettings
        {
            AnsibleRepoPath = AnsibleRepoPathBox.Text ?? string.Empty,
            VaultPasswordFile = VaultPasswordFileBox.Text ?? string.Empty,
            DevDirectory = DevDirectoryBox.Text ?? string.Empty,
            GitHubToken = string.IsNullOrWhiteSpace(GitHubTokenBox.Text) ? null : GitHubTokenBox.Text,
            ReportingScriptsOverridePath = ReportingScriptsOverridePathBox.Text ?? string.Empty
        });
        Close();
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();

    private async void OnBrowseRepoClick(object? sender, RoutedEventArgs e)
    {
        var folders = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "選擇 MoldPlan Center 目錄",
            AllowMultiple = false
        });
        if (folders.Count > 0)
            AnsibleRepoPathBox.Text = folders[0].Path.LocalPath;
    }

    private async void OnBrowseVaultPassClick(object? sender, RoutedEventArgs e)
    {
        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "選擇 Vault 密碼檔案",
            AllowMultiple = false
        });
        if (files.Count > 0)
            VaultPasswordFileBox.Text = files[0].Path.LocalPath;
    }

    private async void OnBrowseDevDirectoryClick(object? sender, RoutedEventArgs e)
    {
        var folders = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "選擇開發目錄",
            AllowMultiple = false
        });
        if (folders.Count > 0)
            DevDirectoryBox.Text = folders[0].Path.LocalPath;
    }

    private async void OnBrowseReportingScriptsOverridePathClick(object? sender, RoutedEventArgs e)
    {
        var folders = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "選擇 Reporting 腳本覆寫目錄",
            AllowMultiple = false
        });
        if (folders.Count > 0)
            ReportingScriptsOverridePathBox.Text = folders[0].Path.LocalPath;
    }
}
