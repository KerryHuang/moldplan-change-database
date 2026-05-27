using CommunityToolkit.Mvvm.ComponentModel;

namespace MoldplanDbSwitcher.ViewModels;

public partial class DropConfirmDialogViewModel : ObservableObject
{
    public string TargetDatabase { get; }
    public DropConfirmDialogViewModel(string targetDatabase) { TargetDatabase = targetDatabase; }

    [ObservableProperty] private string _typedName = "";
    public bool CanConfirm => string.Equals(TypedName, TargetDatabase, StringComparison.OrdinalIgnoreCase);

    partial void OnTypedNameChanged(string value) => OnPropertyChanged(nameof(CanConfirm));
}
