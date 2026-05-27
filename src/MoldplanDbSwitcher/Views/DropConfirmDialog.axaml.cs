using Avalonia.Controls;

namespace MoldplanDbSwitcher.Views;

public partial class DropConfirmDialog : Window
{
    public DropConfirmDialog() { InitializeComponent(); }

    private void OnCancel(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close(false);
    private void OnConfirm(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close(true);
}
