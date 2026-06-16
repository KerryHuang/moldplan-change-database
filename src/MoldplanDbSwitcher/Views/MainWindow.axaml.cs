using System.IO;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;
using MoldplanDbSwitcher.ViewModels.Documents;

namespace MoldplanDbSwitcher.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }

    private void OnExitClick(object? sender, RoutedEventArgs e) => Close();

    private Func<Task<ReportSourceOptions?>> CreateReportSourceCallback(ConnectionSwitchDocumentViewModel cs) =>
        async () =>
        {
            var dialog = new ReportSourceDialog(cs.GetAvailableSources());
            return await dialog.ShowDialog<ReportSourceOptions?>(this);
        };

    private async void OnExportFeatureReportClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm)
        {
            var cs = vm.ConnectionSwitch;
            cs.ReportSourceCallback = CreateReportSourceCallback(cs);
            cs.SaveFileCallback = async () =>
            {
                var file = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
                {
                    Title = "儲存功能差異表",
                    DefaultExtension = "xlsx",
                    FileTypeChoices = new[]
                    {
                        new FilePickerFileType("Excel 檔案") { Patterns = new[] { "*.xlsx" } }
                    },
                    SuggestedFileName = "客戶功能差異表"
                });
                return file?.Path.LocalPath;
            };
            await cs.ExportFeatureReportCommand.ExecuteAsync(null);
        }
    }

    private async void OnExportUsageReportClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm)
        {
            var cs = vm.ConnectionSwitch;
            cs.ReportSourceCallback = CreateReportSourceCallback(cs);
            cs.SaveUsageReportCallback = async () =>
            {
                var file = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
                {
                    Title = "儲存使用次數統計",
                    DefaultExtension = "xlsx",
                    FileTypeChoices = new[]
                    {
                        new FilePickerFileType("Excel 檔案") { Patterns = new[] { "*.xlsx" } }
                    },
                    SuggestedFileName = "系統功能使用次數統計表"
                });
                return file?.Path.LocalPath;
            };
            await cs.ExportUsageReportCommand.ExecuteAsync(null);
        }
    }

    private async void OnSettingsClick(object? sender, RoutedEventArgs e)
    {
        var dialog = new SettingsDialog(App.Services!.GetRequiredService<IAppSettingsService>());
        await dialog.ShowDialog(this);
        if (DataContext is MainWindowViewModel vm)
        {
            vm.ConnectionSwitch.NotifyCanSyncAnsibleChanged();
            vm.ConnectionSwitch.NotifyHasDevDirectoryChanged();
        }
    }

    protected override void OnDataContextChanged(EventArgs e)
    {
        base.OnDataContextChanged(e);
        if (DataContext is MainWindowViewModel vm)
            SetupApplyDevCallback(vm.ConnectionSwitch);
    }

    private void SetupApplyDevCallback(ConnectionSwitchDocumentViewModel cs)
    {
        cs.ApplyDevDialogCallback = async (files, profile) =>
        {
            var dialog = new ApplyDevDialog(files, profile);
            return await dialog.ShowDialog<IReadOnlyList<string>?>(this);
        };

        cs.ConfirmCallback = async (message, banner) =>
        {
            var dialog = new ConfirmDialog(message, banner);
            return await dialog.ShowDialog<bool>(this);
        };
    }

    private async void OnExportConnectionsClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel vm) return;
        var cs = vm.ConnectionSwitch;

        var profiles = cs.GetConnectionsForExport();
        if (profiles.Count == 0) return;

        var exportVm = new ExportConnectionsViewModel(profiles, cs.ConnectionExportService);
        var dialog = new ExportConnectionsWindow { DataContext = exportVm };
        await dialog.ShowDialog(this);
    }

    private void OnDownloadUpdateClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm && !string.IsNullOrEmpty(vm.UpdateReleaseUrl))
        {
            try
            {
                System.Diagnostics.Process.Start(
                    new System.Diagnostics.ProcessStartInfo(vm.UpdateReleaseUrl)
                    { UseShellExecute = true });
            }
            catch { /* 靜音 */ }
        }
    }

    private async void OnImportConnectionsClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel vm) return;
        var cs = vm.ConnectionSwitch;

        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "選擇連線設定檔",
            AllowMultiple = false,
            FileTypeFilter = new[]
            {
                new FilePickerFileType("連線設定檔") { Patterns = new[] { "*.json", "*.tsjson" } }
            }
        });

        if (files.Count == 0) return;

        await using var stream = await files[0].OpenReadAsync();
        using var ms = new MemoryStream();
        await stream.CopyToAsync(ms);
        var data = ms.ToArray();

        var importVm = new ImportConnectionsViewModel(
            cs.ConnectionExportService, cs.SettingsServicePublic, cs.GetCustomConnections());
        importVm.LoadImportData(data);

        var dialog = new ImportConnectionsWindow { DataContext = importVm };
        var result = await dialog.ShowDialog<ImportResult?>(this);

        if (result is not null)
        {
            cs.LoadConnectionsCommand.Execute(null);
            cs.StatusMessage = $"匯入完成：新增 {result.Added}，覆蓋 {result.Overwritten}，跳過 {result.Skipped}";
        }
    }
}
