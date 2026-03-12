using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
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
}
