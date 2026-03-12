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

    private void OnImportClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is ImportConnectionsViewModel vm)
        {
            var result = vm.ExecuteImport();
            Close(result);
        }
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();
}
