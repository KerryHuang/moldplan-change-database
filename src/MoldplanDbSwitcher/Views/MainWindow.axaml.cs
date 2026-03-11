using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
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
