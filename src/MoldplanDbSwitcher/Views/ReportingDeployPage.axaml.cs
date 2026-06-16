using Avalonia.Controls;
using Avalonia.Platform.Storage;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ReportingDeployPage : UserControl
{
    public ReportingDeployPage() { InitializeComponent(); }

    private async void OnDropAllClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not ReportingDeployViewModel vm) return;
        var dialog = new DropConfirmDialog
        {
            DataContext = new DropConfirmDialogViewModel(vm.TargetDatabaseName)
        };
        var owner = TopLevel.GetTopLevel(this) as Window;
        if (owner == null) return;
        var ok = await dialog.ShowDialog<bool>(owner);
        if (ok) await vm.DropAllAsync(vm.TargetDatabaseName);
    }

    private async void OnExportSqlClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not ReportingDeployViewModel vm) return;
        var top = TopLevel.GetTopLevel(this);
        if (top is null) return;
        vm.SaveExportSqlCallback = async (content) =>
        {
            var file = await top.StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "匯出 Reporting 部署 SQL",
                DefaultExtension = "sql",
                SuggestedFileName = "Reporting_Deploy",
                FileTypeChoices = new[] { new FilePickerFileType("SQL 檔案") { Patterns = new[] { "*.sql" } } }
            });
            if (file is null) return null;
            await using var stream = await file.OpenWriteAsync();
            await using var writer = new System.IO.StreamWriter(stream);
            await writer.WriteAsync(content);
            return file.Path.LocalPath;
        };
        await vm.ExportSqlCommand.ExecuteAsync(null);
    }
}
