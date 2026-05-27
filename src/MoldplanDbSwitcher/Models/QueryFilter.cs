using CommunityToolkit.Mvvm.ComponentModel;

namespace MoldplanDbSwitcher.Models;

public enum FilterOperator
{
    Equals,         // =
    NotEquals,      // <>
    Contains,       // LIKE '%x%'
    StartsWith,     // LIKE 'x%'
    GreaterThan,    // >
    LessThan,       // <
    GreaterOrEqual, // >=
    LessOrEqual,    // <=
    IsNull,         // IS NULL
    IsNotNull,      // IS NOT NULL
}

public enum FilterConnector { And, Or }

public enum SortDirection { Ascending, Descending }

public partial class QueryFilterRow : ObservableObject
{
    [ObservableProperty] private ReportingColumn? _selectedColumn;
    [ObservableProperty] private FilterOperator _operator = FilterOperator.Equals;
    [ObservableProperty] private string? _value;
    [ObservableProperty] private FilterConnector _connector = FilterConnector.And;

    public string? ColumnName => SelectedColumn?.Name;

    partial void OnSelectedColumnChanged(ReportingColumn? value) =>
        OnPropertyChanged(nameof(ColumnName));
}

public partial class QuerySortRow : ObservableObject
{
    [ObservableProperty] private ReportingColumn? _selectedColumn;
    [ObservableProperty] private SortDirection _direction = SortDirection.Ascending;

    public string? ColumnName => SelectedColumn?.Name;

    partial void OnSelectedColumnChanged(ReportingColumn? value) =>
        OnPropertyChanged(nameof(ColumnName));
}
