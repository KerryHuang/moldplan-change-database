using Avalonia.Controls;
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
}
