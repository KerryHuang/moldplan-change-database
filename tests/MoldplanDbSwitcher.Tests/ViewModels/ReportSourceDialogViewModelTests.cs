using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.ViewModels;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ReportSourceDialogViewModelTests
{
    [Fact]
    public void 建構_可用選項為false_對應屬性不勾選且不可點()
    {
        var available = new ReportSourceOptions(
            Specurai: true, Custom: false, MoldPlanCenter: true,
            Development: false, Testing: true, Staging: false, Production: true);

        var vm = new ReportSourceDialogViewModel(available);

        Assert.False(vm.HasCustom);
        Assert.False(vm.Custom);
        Assert.False(vm.HasDevelopment);
        Assert.False(vm.Development);
        Assert.False(vm.HasStaging);
        Assert.False(vm.Staging);
    }

    [Fact]
    public void 建構_可用選項為true_預設勾選且可點()
    {
        var available = new ReportSourceOptions(
            Specurai: true, Custom: false, MoldPlanCenter: true,
            Development: false, Testing: true, Staging: false, Production: true);

        var vm = new ReportSourceDialogViewModel(available);

        Assert.True(vm.HasSpecurai);
        Assert.True(vm.Specurai);
        Assert.True(vm.HasMoldPlanCenter);
        Assert.True(vm.MoldPlanCenter);
        Assert.True(vm.HasTesting);
        Assert.True(vm.Testing);
        Assert.True(vm.HasProduction);
        Assert.True(vm.Production);
    }

    [Fact]
    public void ToOptions_回傳目前勾選狀態()
    {
        var vm = new ReportSourceDialogViewModel(ReportSourceOptions.AllSelected);
        vm.Custom = false;
        vm.Staging = false;

        var result = vm.ToOptions();

        Assert.True(result.Specurai);
        Assert.False(result.Custom);
        Assert.True(result.MoldPlanCenter);
        Assert.True(result.Development);
        Assert.True(result.Testing);
        Assert.False(result.Staging);
        Assert.True(result.Production);
    }
}
