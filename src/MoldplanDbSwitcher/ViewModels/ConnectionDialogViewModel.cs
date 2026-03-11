using CommunityToolkit.Mvvm.ComponentModel;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ConnectionDialogViewModel : ObservableObject
{
    [ObservableProperty]
    private string _name = string.Empty;

    [ObservableProperty]
    private string _server = string.Empty;

    [ObservableProperty]
    private string _database = string.Empty;

    [ObservableProperty]
    private string _dialogTitle = "新增自訂連線";

    public bool IsValid => !string.IsNullOrWhiteSpace(Name)
                        && !string.IsNullOrWhiteSpace(Server)
                        && !string.IsNullOrWhiteSpace(Database);
}
