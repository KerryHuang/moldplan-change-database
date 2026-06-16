using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels.Documents;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportingObjectGroup : ObservableObject
{
    public string Header { get; }
    public ObservableCollection<ReportingObject> Items { get; } = new();
    public ReportingObjectGroup(string header) { Header = header; }
}

public partial class ReportingQueryViewModel : DocumentViewModel
{
    public override string DocumentType => "ReportingQuery";

    public override Task UseConnectionAsync(ActiveConnection connection)
        => UseConnectionAsync(connection.ConnectionString);
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
        Title = "Reporting 查詢";
    }

    public ObservableCollection<ReportingObject> Objects { get; } = new();
    public ObservableCollection<ReportingObjectGroup> ObjectGroups { get; } = new();
    public ObservableCollection<string> ResultColumns { get; } = new();
    public ObservableCollection<IReadOnlyList<object?>> ResultRows { get; } = new();
    public ObservableCollection<ReportingColumn> SelectedColumns { get; } = new();
    public ObservableCollection<string> AvailableColumnNames { get; } = new();
    public ObservableCollection<ColumnSelectionItem> ProjectionColumns { get; } = new();
    public ObservableCollection<RefreshLogEntry> RefreshLog { get; } = new();
    public ObservableCollection<QueryFilterRow> Filters { get; } = new();
    public ObservableCollection<QuerySortRow> Sorts { get; } = new();

    [ObservableProperty] private ReportingObject? _selectedObject;
    [ObservableProperty] private int _topN = 100;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _errorMessage;
    [ObservableProperty] private string _resultStatus = "請從左側選擇物件以自動載入預覽";

    partial void OnSelectedObjectChanged(ReportingObject? value)
    {
        Filters.Clear();
        Sorts.Clear();
        _ = LoadObjectDetailAsync(value);
        if (value != null) _ = QueryAsync();
    }

    [RelayCommand]
    private void AddFilter() => Filters.Add(new QueryFilterRow());

    [RelayCommand]
    private void RemoveFilter(QueryFilterRow row) => Filters.Remove(row);

    [RelayCommand]
    private void AddSort() => Sorts.Add(new QuerySortRow());

    [RelayCommand]
    private void RemoveSort(QuerySortRow row) => Sorts.Remove(row);

    [ObservableProperty] private string _projectionHeader = "顯示欄位";

    [RelayCommand]
    private void SelectAllColumns() { foreach (var c in ProjectionColumns) c.IsSelected = true; }

    [RelayCommand]
    private void ClearAllColumns() { foreach (var c in ProjectionColumns) c.IsSelected = false; }

    /// <summary>重建投影欄位清單（解除舊訂閱、依新欄位建立可勾選項並更新標頭）。</summary>
    public void RebuildProjection(IEnumerable<ReportingColumn> columns)
    {
        foreach (var old in ProjectionColumns) old.PropertyChanged -= OnProjectionItemChanged;
        ProjectionColumns.Clear();
        foreach (var c in columns)
        {
            var item = new ColumnSelectionItem(c.Name, c.DataType);
            item.PropertyChanged += OnProjectionItemChanged;
            ProjectionColumns.Add(item);
        }
        UpdateProjectionHeader();
    }

    private void OnProjectionItemChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(ColumnSelectionItem.IsSelected)) UpdateProjectionHeader();
    }

    private void UpdateProjectionHeader()
    {
        if (ProjectionColumns.Count == 0) { ProjectionHeader = "顯示欄位"; return; }
        var selected = ProjectionColumns.Count(c => c.IsSelected);
        ProjectionHeader = $"顯示欄位（已選 {selected}/{ProjectionColumns.Count}）";
    }

    public async Task UseConnectionAsync(string connectionString)
    {
        var dbHint = TryExtractDatabase(connectionString);
        _objects = _objectsFactory(connectionString);
        _query = _queryFactory(connectionString);
        SelectedObject = null;
        Objects.Clear();
        ObjectGroups.Clear();
        ResultColumns.Clear();
        ResultRows.Clear();
        SelectedColumns.Clear();
        AvailableColumnNames.Clear();
        RebuildProjection(System.Array.Empty<ReportingColumn>());
        Filters.Clear();
        Sorts.Clear();
        RefreshLog.Clear();
        ResultStatus = $"切換連線中（目標 DB: {dbHint}），載入物件清單⋯";
        await LoadObjectsAsync();
        if (Objects.Count == 0 && ErrorMessage == null)
            ResultStatus = $"此連線（{dbHint}）尚未部署 Reporting schema（請至「Reporting 部署」頁建立）";
        else if (ErrorMessage == null)
            ResultStatus = $"目前連線 DB: {dbHint}，請從左側選擇物件以自動載入預覽";
    }

    private static string TryExtractDatabase(string connectionString)
    {
        try
        {
            var b = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(connectionString);
            return string.IsNullOrEmpty(b.InitialCatalog) ? "(未指定)" : b.InitialCatalog;
        }
        catch { return "(無效連線字串)"; }
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
            var projected = ProjectionColumns.Where(c => c.IsSelected).Select(c => c.Name).ToList();
            var result = await _query.QueryTopNAsync(SelectedObject.Name, TopN, Filters, Sorts, projected);
            ResultColumns.Clear();
            foreach (var c in result.Columns) ResultColumns.Add(c);
            ResultRows.Clear();
            foreach (var r in result.Rows) ResultRows.Add(r);
            ResultStatus = $"共 {ResultRows.Count} 筆  ｜  DB: {result.Database}  ｜  SQL: {result.ExecutedSql}";
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    private async Task LoadObjectDetailAsync(ReportingObject? obj)
    {
        SelectedColumns.Clear();
        AvailableColumnNames.Clear();
        RebuildProjection(System.Array.Empty<ReportingColumn>());
        RefreshLog.Clear();
        if (obj == null) return;
        try
        {
            foreach (var c in await _objects.GetColumnsAsync(obj.Name)) SelectedColumns.Add(c);
            AvailableColumnNames.Clear();
            foreach (var c in SelectedColumns) AvailableColumnNames.Add(c.Name);
            RebuildProjection(SelectedColumns);
            if (obj.Kind != ReportingObjectKind.SystemTable && obj.Kind != ReportingObjectKind.Procedure)
                foreach (var l in await _objects.GetRefreshLogAsync(obj.Name)) RefreshLog.Add(l);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
    }
}
