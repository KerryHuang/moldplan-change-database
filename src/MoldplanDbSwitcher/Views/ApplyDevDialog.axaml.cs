using Avalonia.Controls;
using Avalonia.Interactivity;
using CommunityToolkit.Mvvm.ComponentModel;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Views;

public partial class ApplyDevDialog : Window
{
    private readonly List<FileItem> _items;

    public ApplyDevDialog(IReadOnlyList<string> files, ConnectionProfile profile)
    {
        InitializeComponent();
        _items = files.Select(f => new FileItem { Path = f, IsChecked = true }).ToList();

        var (host, port) = SplitServer(profile.Server);
        PreviewText.Text =
            $"Host: {host}\n" +
            $"Port: {port}\n" +
            $"UserId: {profile.Username}\n" +
            $"Password: {profile.Password}\n" +
            $"ApplicationDatabase: {profile.Database}";

        if (_items.Count == 0)
        {
            NoFilesText.IsVisible = true;
            PreviewPanel.IsVisible = false;
        }
        else
        {
            FileList.ItemsSource = _items;
        }
    }

    private void OnSelectAllClick(object? sender, RoutedEventArgs e)
    {
        foreach (var item in _items) item.IsChecked = true;
    }

    private void OnDeselectAllClick(object? sender, RoutedEventArgs e)
    {
        foreach (var item in _items) item.IsChecked = false;
    }

    private void OnConfirmClick(object? sender, RoutedEventArgs e)
    {
        Close(_items.Where(i => i.IsChecked).Select(i => i.Path).ToList());
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close(null);

    private static (string host, string port) SplitServer(string server)
    {
        var idx = server.IndexOf(',');
        if (idx >= 0)
            return (server[..idx], server[(idx + 1)..]);
        return (server, "1433");
    }
}

public partial class FileItem : ObservableObject
{
    public string Path { get; set; } = string.Empty;

    [ObservableProperty]
    private bool _isChecked;
}
