using Xunit;
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ExportConnectionsViewModelTests
{
    private readonly IConnectionExportService _exportService;
    private readonly List<ConnectionProfile> _profiles;

    public ExportConnectionsViewModelTests()
    {
        _exportService = Substitute.For<IConnectionExportService>();
        _profiles = new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis" },
            new() { Name = "staging", Server = "10.0.0.1", Database = "staging" }
        };
    }

    private ExportConnectionsViewModel CreateVm() => new(_profiles, _exportService);

    [Fact]
    public void Constructor_LoadsAllProfileSelections()
    {
        var vm = CreateVm();
        Assert.Equal(2, vm.ProfileSelections.Count);
        Assert.Equal("dev", vm.ProfileSelections[0].Profile.Name);
    }

    [Fact]
    public void SelectAll_SelectsAllProfiles()
    {
        var vm = CreateVm();
        foreach (var p in vm.ProfileSelections) p.IsSelected = false;
        vm.SelectAllCommand.Execute(null);
        Assert.All(vm.ProfileSelections, p => Assert.True(p.IsSelected));
    }

    [Fact]
    public void DeselectAll_DeselectsAllProfiles()
    {
        var vm = CreateVm();
        foreach (var p in vm.ProfileSelections) p.IsSelected = true;
        vm.DeselectAllCommand.Execute(null);
        Assert.All(vm.ProfileSelections, p => Assert.False(p.IsSelected));
    }

    [Fact]
    public void UseEncryption_True_SetsIncludePasswordsTrue()
    {
        var vm = CreateVm();
        vm.UseEncryption = true;
        Assert.True(vm.IncludePasswords);
    }

    [Fact]
    public void UseEncryption_False_SetsIncludePasswordsFalse()
    {
        var vm = CreateVm();
        vm.UseEncryption = true;
        vm.UseEncryption = false;
        Assert.False(vm.IncludePasswords);
    }

    [Fact]
    public void GetExportData_PlainText_CallsExportToJson()
    {
        _exportService.ExportToJson(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<bool>())
            .Returns(new byte[] { 1, 2, 3 });
        var vm = CreateVm();
        vm.ProfileSelections[0].IsSelected = true;
        vm.ProfileSelections[1].IsSelected = false;
        vm.UseEncryption = false;
        var result = vm.GetExportData();
        Assert.Equal(new byte[] { 1, 2, 3 }, result);
        _exportService.Received(1).ExportToJson(
            Arg.Is<IReadOnlyList<ConnectionProfile>>(list => list.Count == 1 && list[0].Name == "dev"),
            Arg.Any<bool>());
    }

    [Fact]
    public void GetExportData_Encrypted_CallsExportToEncryptedJson()
    {
        _exportService.ExportToEncryptedJson(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<string>(), Arg.Any<bool>())
            .Returns(new byte[] { 4, 5, 6 });
        var vm = CreateVm();
        vm.ProfileSelections[0].IsSelected = true;
        vm.UseEncryption = true;
        vm.EncryptionPassword = "pass";
        var result = vm.GetExportData();
        Assert.Equal(new byte[] { 4, 5, 6 }, result);
        _exportService.Received(1).ExportToEncryptedJson(
            Arg.Any<IReadOnlyList<ConnectionProfile>>(), "pass", true);
    }
}
