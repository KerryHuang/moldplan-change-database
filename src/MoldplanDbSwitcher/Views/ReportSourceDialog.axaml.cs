using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ReportSourceDialog : Window
{
    public ReportSourceDialog(ReportSourceOptions available)
    {
        InitializeComponent();
        DataContext = new ReportSourceDialogViewModel(available);
    }

    private void OnConfirmClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is ReportSourceDialogViewModel vm)
            Close(vm.ToOptions());
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e)
    {
        Close(null);
    }
}
