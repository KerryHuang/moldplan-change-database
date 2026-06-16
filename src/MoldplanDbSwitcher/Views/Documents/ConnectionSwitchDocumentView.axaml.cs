using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.ViewModels;             // ConnectionDialogViewModel
using MoldplanDbSwitcher.ViewModels.Documents;   // ConnectionSwitchDocumentViewModel

namespace MoldplanDbSwitcher.Views.Documents;

public partial class ConnectionSwitchDocumentView : UserControl
{
    public ConnectionSwitchDocumentView()
    {
        InitializeComponent();
    }

    private async void OnAddConnectionClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not ConnectionSwitchDocumentViewModel vm) return;
        if (TopLevel.GetTopLevel(this) is not Window owner) return;
        var dialog = new ConnectionDialog();
        var result = await dialog.ShowDialog<ConnectionDialogViewModel?>(owner);
        if (result is not null)
            vm.AddCustomConnection(result.Name, result.Server, result.Database, result.Environment);
    }

    private async void OnDeleteConnectionClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not ConnectionSwitchDocumentViewModel vm) return;
        if (vm.SelectedConnection is not { Source: "Custom" } profile) return;
        await vm.DeleteCustomConnection(profile);
    }
}
