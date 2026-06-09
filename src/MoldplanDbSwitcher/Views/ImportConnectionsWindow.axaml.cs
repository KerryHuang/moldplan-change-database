using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ImportConnectionsWindow : Window
{
    public ImportConnectionsWindow()
    {
        InitializeComponent();
    }

    private void OnDecryptClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is ImportConnectionsViewModel vm)
            vm.DecryptAndLoad();
    }

    private async void OnImportClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not ImportConnectionsViewModel vm) return;

        if (vm.HasProductionOverwrite())
        {
            var confirm = new ConfirmDialog(
                "匯入清單將覆蓋既有的正式環境連線，確定要繼續嗎？",
                "⚠ 此次匯入包含 Production（正式環境）連線的覆蓋");
            var ok = await confirm.ShowDialog<bool>(this);
            if (!ok) return;
        }

        var result = vm.ExecuteImport();
        Close(result);
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();
}
