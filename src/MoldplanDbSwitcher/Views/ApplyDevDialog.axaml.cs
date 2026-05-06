using Avalonia.Controls;
using Avalonia.Interactivity;
using CommunityToolkit.Mvvm.ComponentModel;

namespace MoldplanDbSwitcher.Views;

public partial class ApplyDevDialog : Window
{
    private readonly List<FileItem> _items;

    public ApplyDevDialog(IReadOnlyList<string> files)
    {
        InitializeComponent();
        _items = files.Select(f => new FileItem { Path = f, IsChecked = true }).ToList();

        if (_items.Count == 0)
        {
            NoFilesText.IsVisible = true;
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
}

public partial class FileItem : ObservableObject
{
    public string Path { get; set; } = string.Empty;

    [ObservableProperty]
    private bool _isChecked;
}
