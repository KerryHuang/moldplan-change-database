using CommunityToolkit.Mvvm.ComponentModel;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportSourceDialogViewModel : ObservableObject
{
    // 是否有該來源／環境的連線（控制 checkbox 是否可點）
    public bool HasSpecurai { get; }
    public bool HasCustom { get; }
    public bool HasMoldPlanCenter { get; }
    public bool HasDevelopment { get; }
    public bool HasTesting { get; }
    public bool HasStaging { get; }
    public bool HasProduction { get; }

    [ObservableProperty] private bool _specurai;
    [ObservableProperty] private bool _custom;
    [ObservableProperty] private bool _moldPlanCenter;
    [ObservableProperty] private bool _development;
    [ObservableProperty] private bool _testing;
    [ObservableProperty] private bool _staging;
    [ObservableProperty] private bool _production;

    public ReportSourceDialogViewModel(ReportSourceOptions available)
    {
        HasSpecurai = available.Specurai;
        HasCustom = available.Custom;
        HasMoldPlanCenter = available.MoldPlanCenter;
        HasDevelopment = available.Development;
        HasTesting = available.Testing;
        HasStaging = available.Staging;
        HasProduction = available.Production;

        // 預設只勾選實際存在的來源與環境
        _specurai = available.Specurai;
        _custom = available.Custom;
        _moldPlanCenter = available.MoldPlanCenter;
        _development = available.Development;
        _testing = available.Testing;
        _staging = available.Staging;
        _production = available.Production;
    }

    public ReportSourceOptions ToOptions() =>
        new(Specurai, Custom, MoldPlanCenter, Development, Testing, Staging, Production);
}
