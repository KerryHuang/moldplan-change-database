using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ConnectionDialog : Window
{
    public ConnectionDialog()
    {
        InitializeComponent();
        DataContext = new ConnectionDialogViewModel();
    }

    private void OnConfirmClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is ConnectionDialogViewModel vm && vm.IsValid)
        {
            Close(vm);
        }
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e)
    {
        Close(null);
    }
}
