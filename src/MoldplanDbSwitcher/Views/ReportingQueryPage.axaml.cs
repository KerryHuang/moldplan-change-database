using System;
using System.Collections.Specialized;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Data;
using Avalonia.VisualTree;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ReportingQueryPage : UserControl
{
    private bool _settingSelection;

    public ReportingQueryPage()
    {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    private void OnDataContextChanged(object? sender, EventArgs e)
    {
        if (DataContext is not ReportingQueryViewModel vm) return;
        vm.ResultColumns.CollectionChanged -= OnColumnsChanged;
        vm.ResultColumns.CollectionChanged += OnColumnsChanged;
        vm.SelectedColumns.CollectionChanged -= OnSelectedColumnsChanged;
        vm.SelectedColumns.CollectionChanged += OnSelectedColumnsChanged;
        RebuildColumns(vm);
    }

    private void OnColumnsChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        if (DataContext is ReportingQueryViewModel vm) RebuildColumns(vm);
    }

    private void OnSelectedColumnsChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        if (DataContext is ReportingQueryViewModel vm) RebuildColumns(vm);
    }

    private void RebuildColumns(ReportingQueryViewModel vm)
    {
        var grid = this.FindControl<DataGrid>("ResultGrid");
        if (grid is null) return;
        grid.Columns.Clear();
        for (var i = 0; i < vm.ResultColumns.Count; i++)
        {
            var colName = vm.ResultColumns[i];
            var colMeta = vm.SelectedColumns.FirstOrDefault(c =>
                string.Equals(c.Name, colName, StringComparison.OrdinalIgnoreCase));

            object header;
            if (!string.IsNullOrEmpty(colMeta?.Description))
            {
                var panel = new StackPanel();
                panel.Children.Add(new TextBlock { Text = colName, FontWeight = Avalonia.Media.FontWeight.SemiBold });
                panel.Children.Add(new TextBlock
                {
                    Text = colMeta.Description,
                    FontSize = 10,
                    Foreground = Avalonia.Media.Brushes.Gray
                });
                ToolTip.SetTip(panel, colMeta.Description);
                header = panel;
            }
            else
            {
                header = new TextBlock { Text = colName };
            }

            var col = new DataGridTextColumn
            {
                Header = header,
                Binding = new Binding($"[{i}]")
            };
            grid.Columns.Add(col);
        }
    }

    internal void OnGroupListBoxSelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_settingSelection) return;
        if (DataContext is not ReportingQueryViewModel vm) return;
        if (sender is not ListBox selectedListBox) return;
        if (selectedListBox.SelectedItem is not ReportingObject selected) return;

        _settingSelection = true;
        try
        {
            vm.SelectedObject = selected;
            // Deselect all other group ListBoxes
            foreach (var lb in this.GetVisualDescendants().OfType<ListBox>())
            {
                if (!ReferenceEquals(lb, selectedListBox))
                    lb.SelectedItem = null;
            }
        }
        finally
        {
            _settingSelection = false;
        }
    }
}
