using System;
using System.Collections.Specialized;
using Avalonia.Controls;
using Avalonia.Data;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ReportingQueryPage : UserControl
{
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
}
