using CommunityToolkit.Mvvm.ComponentModel;

namespace MoldplanDbSwitcher.ViewModels;

/// <summary>查詢投影欄位的可勾選項目。</summary>
public partial class ColumnSelectionItem : ObservableObject
{
    public string Name { get; }
    public string DataType { get; }
    [ObservableProperty] private bool _isSelected = true;

    public ColumnSelectionItem(string name, string dataType)
    {
        Name = name;
        DataType = dataType;
    }
}
