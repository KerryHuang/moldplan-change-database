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

public partial class QueryFilterRow : ObservableObject
{
    [ObservableProperty] private string? _columnName;
    [ObservableProperty] private FilterOperator _operator = FilterOperator.Equals;
    [ObservableProperty] private string? _value;
}
