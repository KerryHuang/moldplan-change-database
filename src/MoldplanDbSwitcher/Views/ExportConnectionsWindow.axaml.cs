using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ExportConnectionsWindow : Window
{
    public ExportConnectionsWindow()
    {
        InitializeComponent();
    }

    private async void OnExportClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not ExportConnectionsViewModel vm) return;

        if (vm.ProfileSelections.All(p => !p.IsSelected)) return;

        if (vm.UseEncryption)
        {
            if (string.IsNullOrEmpty(vm.EncryptionPassword)) return;
            if (vm.EncryptionPassword != vm.ConfirmPassword) return;
        }

        var extension = vm.UseEncryption ? "tsjson" : "json";
        var typeName = vm.UseEncryption ? "加密 JSON 檔案" : "JSON 檔案";
        var file = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            Title = "匯出連線設定",
            DefaultExtension = extension,
            FileTypeChoices = new[]
            {
                new FilePickerFileType(typeName) { Patterns = new[] { $"*.{extension}" } }
            },
            SuggestedFileName = "connections"
        });

        if (file is null) return;

        var data = vm.GetExportData();
        await using var stream = await file.OpenWriteAsync();
        await stream.WriteAsync(data);
        Close();
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();
}
