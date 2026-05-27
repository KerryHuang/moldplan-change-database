using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportingQueryViewModel : ObservableObject
{
    private readonly Func<string, IReportingObjectService> _objectsFactory;
    private readonly Func<string, IReportingQueryService> _queryFactory;
    private IReportingObjectService _objects;
    private IReportingQueryService _query;

    public ReportingQueryViewModel(
        Func<string, IReportingObjectService> objectsFactory,
        Func<string, IReportingQueryService> queryFactory,
        string initialConnectionString)
    {
        _objectsFactory = objectsFactory;
        _queryFactory = queryFactory;
        _objects = objectsFactory(initialConnectionString);
        _query = queryFactory(initialConnectionString);
    }

    public ObservableCollection<ReportingObject> Objects { get; } = new();
    public ObservableCollection<string> ResultColumns { get; } = new();
    public ObservableCollection<IReadOnlyList<object?>> ResultRows { get; } = new();
    public ObservableCollection<ReportingColumn> SelectedColumns { get; } = new();
    public ObservableCollection<RefreshLogEntry> RefreshLog { get; } = new();

    [ObservableProperty] private ReportingObject? _selectedObject;
    [ObservableProperty] private int _topN = 100;
    [ObservableProperty] private string? _whereClause;
    [ObservableProperty] private string? _orderByClause;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _errorMessage;

    partial void OnSelectedObjectChanged(ReportingObject? value)
    {
        _ = LoadObjectDetailAsync(value);
    }

    public async Task UseConnectionAsync(string connectionString)
    {
        _objects = _objectsFactory(connectionString);
        _query = _queryFactory(connectionString);
        Objects.Clear();
        ResultColumns.Clear();
        ResultRows.Clear();
        SelectedColumns.Clear();
        RefreshLog.Clear();
        await LoadObjectsAsync();
    }

    [RelayCommand]
    private async Task LoadObjectsAsync()
    {
        try
        {
            IsBusy = true;
            ErrorMessage = null;
            Objects.Clear();
            foreach (var o in await _objects.ListTablesAsync()) Objects.Add(o);
            foreach (var o in await _objects.ListViewsAsync()) Objects.Add(o);
            foreach (var o in await _objects.ListProceduresAsync()) Objects.Add(o);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task QueryAsync()
    {
        if (SelectedObject == null) return;
        try
        {
            IsBusy = true;
            ErrorMessage = null;
            var result = await _query.QueryTopNAsync(SelectedObject.Name, TopN, WhereClause, OrderByClause);
            ResultColumns.Clear();
            foreach (var c in result.Columns) ResultColumns.Add(c);
            ResultRows.Clear();
            foreach (var r in result.Rows) ResultRows.Add(r);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    private async Task LoadObjectDetailAsync(ReportingObject? obj)
    {
        SelectedColumns.Clear();
        RefreshLog.Clear();
        if (obj == null) return;
        try
        {
            foreach (var c in await _objects.GetColumnsAsync(obj.Name)) SelectedColumns.Add(c);
            if (obj.Kind != ReportingObjectKind.SystemTable && obj.Kind != ReportingObjectKind.Procedure)
                foreach (var l in await _objects.GetRefreshLogAsync(obj.Name)) RefreshLog.Add(l);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
    }
}
