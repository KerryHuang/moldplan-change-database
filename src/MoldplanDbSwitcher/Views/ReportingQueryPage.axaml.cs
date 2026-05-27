using System;
using System.Collections.Specialized;
using System.Linq;
using Avalonia.Controls;
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
        RebuildColumns(vm);
    }

    private void OnColumnsChanged(object? sender, NotifyCollectionChangedEventArgs e)
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
            grid.Columns.Add(new DataGridTextColumn
            {
                Header = vm.ResultColumns[i],
                Binding = new Binding($"[{i}]")
            });
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
