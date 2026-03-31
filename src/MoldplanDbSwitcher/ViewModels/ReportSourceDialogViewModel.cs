using CommunityToolkit.Mvvm.ComponentModel;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportSourceDialogViewModel : ObservableObject
{
    // 是否有該來源的連線（控制 checkbox 是否可點）
    public bool HasSpecurai { get; }
    public bool HasCustom { get; }
    public bool HasAnsibleProduction { get; }
    public bool HasAnsibleStaging { get; }

    [ObservableProperty] private bool _specurai;
    [ObservableProperty] private bool _custom;
    [ObservableProperty] private bool _ansibleProduction;
    [ObservableProperty] private bool _ansibleStaging;

    public ReportSourceDialogViewModel(ReportSourceOptions available)
    {
        HasSpecurai = available.Specurai;
        HasCustom = available.Custom;
        HasAnsibleProduction = available.AnsibleProduction;
        HasAnsibleStaging = available.AnsibleStaging;

        // 預設只勾選有連線的來源
        _specurai = available.Specurai;
        _custom = available.Custom;
        _ansibleProduction = available.AnsibleProduction;
        _ansibleStaging = available.AnsibleStaging;
    }

    public ReportSourceOptions ToOptions() =>
        new(Specurai, Custom, AnsibleProduction, AnsibleStaging);
}
