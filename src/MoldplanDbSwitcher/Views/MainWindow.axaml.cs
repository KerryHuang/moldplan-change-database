using System.IO;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }

    private async void OnExportFeatureReportClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm)
        {
            vm.SaveFileCallback = async () =>
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
            await vm.ExportFeatureReportCommand.ExecuteAsync(null);
        }
    }

    private async void OnAddConnectionClick(object? sender, RoutedEventArgs e)
    {
        var dialog = new ConnectionDialog();
        var result = await dialog.ShowDialog<ConnectionDialogViewModel?>(this);
        if (result is not null && DataContext is MainWindowViewModel vm)
        {
            vm.AddCustomConnection(result.Name, result.Server, result.Database);
        }
    }

    private void OnDeleteConnectionClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm && vm.SelectedConnection is { Source: "Custom" } profile)
        {
            vm.DeleteCustomConnection(profile);
        }
    }

    private async void OnExportConnectionsClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel vm) return;

        var profiles = vm.GetConnectionsForExport();
        if (profiles.Count == 0) return;

        var exportVm = new ExportConnectionsViewModel(profiles, vm.ConnectionExportService);
        var dialog = new ExportConnectionsWindow { DataContext = exportVm };
        await dialog.ShowDialog(this);
    }

    private async void OnImportConnectionsClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel vm) return;

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
            vm.ConnectionExportService, vm.SettingsServicePublic, vm.GetConnectionsForExport());
        importVm.LoadImportData(data);

        var dialog = new ImportConnectionsWindow { DataContext = importVm };
        var result = await dialog.ShowDialog<ImportResult?>(this);

        if (result is not null)
        {
            vm.LoadConnectionsCommand.Execute(null);
            vm.StatusMessage = $"匯入完成：新增 {result.Added}，覆蓋 {result.Overwritten}，跳過 {result.Skipped}";
        }
    }
}
