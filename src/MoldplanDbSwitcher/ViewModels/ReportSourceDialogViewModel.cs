using CommunityToolkit.Mvvm.ComponentModel;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportSourceDialogViewModel : ObservableObject
{
    [ObservableProperty] private bool _specurai = true;
    [ObservableProperty] private bool _custom = true;
    [ObservableProperty] private bool _ansibleProduction = true;
    [ObservableProperty] private bool _ansibleStaging = true;

    public ReportSourceOptions ToOptions() =>
        new(Specurai, Custom, AnsibleProduction, AnsibleStaging);
}
