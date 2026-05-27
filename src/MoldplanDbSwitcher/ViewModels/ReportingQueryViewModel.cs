using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportingObjectGroup : ObservableObject
{
    public string Header { get; }
    public ObservableCollection<ReportingObject> Items { get; } = new();
    public ReportingObjectGroup(string header) { Header = header; }
}

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
    public ObservableCollection<ReportingObjectGroup> ObjectGroups { get; } = new();
    public ObservableCollection<string> ResultColumns { get; } = new();
    public ObservableCollection<IReadOnlyList<object?>> ResultRows { get; } = new();
    public ObservableCollection<ReportingColumn> SelectedColumns { get; } = new();
    public ObservableCollection<string> AvailableColumnNames { get; } = new();
    public ObservableCollection<RefreshLogEntry> RefreshLog { get; } = new();
    public ObservableCollection<QueryFilterRow> Filters { get; } = new();

    [ObservableProperty] private ReportingObject? _selectedObject;
    [ObservableProperty] private int _topN = 100;
    [ObservableProperty] private string? _orderByClause;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _errorMessage;
    [ObservableProperty] private string _resultStatus = "請從左側選擇物件以自動載入預覽";

    partial void OnSelectedObjectChanged(ReportingObject? value)
    {
        Filters.Clear();
        _ = LoadObjectDetailAsync(value);
        if (value != null) _ = QueryAsync();
    }

    [RelayCommand]
    private void AddFilter() => Filters.Add(new QueryFilterRow());

    [RelayCommand]
    private void RemoveFilter(QueryFilterRow row) => Filters.Remove(row);

    public async Task UseConnectionAsync(string connectionString)
    {
        _objects = _objectsFactory(connectionString);
        _query = _queryFactory(connectionString);
        SelectedObject = null;
        Objects.Clear();
        ObjectGroups.Clear();
        ResultColumns.Clear();
        ResultRows.Clear();
        SelectedColumns.Clear();
        AvailableColumnNames.Clear();
        Filters.Clear();
        RefreshLog.Clear();
        ResultStatus = "切換連線中，正在載入物件清單⋯";
        await LoadObjectsAsync();
        if (Objects.Count == 0 && ErrorMessage == null)
            ResultStatus = "此連線尚未部署 Reporting schema（請至「Reporting 部署」頁建立）";
        else if (ErrorMessage == null)
            ResultStatus = "請從左側選擇物件以自動載入預覽";
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
            RebuildGroups();
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    private void RebuildGroups()
    {
        ObjectGroups.Clear();
        var order = new[]
        {
            (ReportingObjectKind.BaseTable, "Base Tables"),
            (ReportingObjectKind.SummaryTable, "Summary Tables"),
            (ReportingObjectKind.View, "Views"),
            (ReportingObjectKind.Procedure, "Procedures"),
            (ReportingObjectKind.SystemTable, "System Tables"),
        };
        foreach (var (kind, header) in order)
        {
            var items = Objects.Where(o => o.Kind == kind).ToList();
            if (items.Count == 0) continue;
            var group = new ReportingObjectGroup($"{header} ({items.Count})");
            foreach (var i in items) group.Items.Add(i);
            ObjectGroups.Add(group);
        }
    }

    [RelayCommand]
    private async Task QueryAsync()
    {
        if (SelectedObject == null) return;
        try
        {
            IsBusy = true;
            ErrorMessage = null;
            var result = await _query.QueryTopNAsync(SelectedObject.Name, TopN, Filters, OrderByClause);
            ResultColumns.Clear();
            foreach (var c in result.Columns) ResultColumns.Add(c);
            ResultRows.Clear();
            foreach (var r in result.Rows) ResultRows.Add(r);
            ResultStatus = $"共 {ResultRows.Count} 筆";
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    private async Task LoadObjectDetailAsync(ReportingObject? obj)
    {
        SelectedColumns.Clear();
        AvailableColumnNames.Clear();
        RefreshLog.Clear();
        if (obj == null) return;
        try
        {
            foreach (var c in await _objects.GetColumnsAsync(obj.Name)) SelectedColumns.Add(c);
            AvailableColumnNames.Clear();
            foreach (var c in SelectedColumns) AvailableColumnNames.Add(c.Name);
            if (obj.Kind != ReportingObjectKind.SystemTable && obj.Kind != ReportingObjectKind.Procedure)
                foreach (var l in await _objects.GetRefreshLogAsync(obj.Name)) RefreshLog.Add(l);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
    }
}
