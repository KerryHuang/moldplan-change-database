using Avalonia.Controls;
using Avalonia.Interactivity;

namespace MoldplanDbSwitcher.Views;

public partial class ConfirmDialog : Window
{
    public ConfirmDialog() { InitializeComponent(); }

    /// <summary>建立確認對話框；warningBanner 非空白時於上方顯示紅色警告橫幅。</summary>
    public ConfirmDialog(string message, string? warningBanner) : this()
    {
        MessageText.Text = message;
        if (!string.IsNullOrEmpty(warningBanner))
        {
            WarningText.Text = warningBanner;
            WarningBanner.IsVisible = true;
        }
    }

    private void OnYes(object? sender, RoutedEventArgs e) => Close(true);
    private void OnNo(object? sender, RoutedEventArgs e) => Close(false);
}
