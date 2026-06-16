using CommunityToolkit.Mvvm.ComponentModel;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ServerTxtFileItem : ObservableObject
{
    [ObservableProperty]
    private string _path = string.Empty;

    [ObservableProperty]
    private bool _isSelected;
}
