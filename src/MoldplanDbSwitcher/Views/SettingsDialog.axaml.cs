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
    }

    private void OnSaveClick(object? sender, RoutedEventArgs e)
    {
        _appSettingsService.Save(new AppSettings
        {
            AnsibleRepoPath = AnsibleRepoPathBox.Text ?? string.Empty,
            VaultPasswordFile = VaultPasswordFileBox.Text ?? string.Empty
        });
        Close();
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();

    private async void OnBrowseRepoClick(object? sender, RoutedEventArgs e)
    {
        var folders = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "選擇 deploy-ansible 目錄",
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
}
