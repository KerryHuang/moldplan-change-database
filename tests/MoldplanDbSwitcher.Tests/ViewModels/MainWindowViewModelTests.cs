using Xunit;
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class MainWindowViewModelTests
{
    private readonly IConnectionSourceService _connectionSource;
    private readonly IServerTxtService _serverTxtService;
    private readonly ISettingsService _settingsService;

    public MainWindowViewModelTests()
    {
        _connectionSource = Substitute.For<IConnectionSourceService>();
        _serverTxtService = Substitute.For<IServerTxtService>();
        _settingsService = Substitute.For<ISettingsService>();

        _connectionSource.LoadTableSpecConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Source = "TableSpec" }
        });
        _connectionSource.LoadCustomConnections().Returns(new List<ConnectionProfile>());
        _serverTxtService.DiscoverPaths().Returns(new List<string>());
    }

    private MainWindowViewModel CreateVm() => new(_connectionSource, _serverTxtService, _settingsService);

    [Fact]
    public void Constructor_LoadsConnections()
    {
        var vm = CreateVm();
        Assert.Single(vm.Connections);
        Assert.Equal("dev", vm.Connections[0].Name);
    }

    [Fact]
    public void Constructor_SetsFirstConnectionAsSelected()
    {
        var vm = CreateVm();
        Assert.NotNull(vm.SelectedConnection);
        Assert.Equal("dev", vm.SelectedConnection!.Name);
    }

    [Fact]
    public void ApplyChanges_NoSelection_SetsErrorStatus()
    {
        _connectionSource.LoadTableSpecConnections().Returns(new List<ConnectionProfile>());
        var vm = CreateVm();
        vm.SelectedConnection = null;

        vm.ApplyChangesCommand.Execute(null);

        Assert.Contains("請先選擇", vm.StatusMessage);
    }

    [Fact]
    public void ApplyChanges_NoServerTxtSelected_SetsErrorStatus()
    {
        var vm = CreateVm();

        vm.ApplyChangesCommand.Execute(null);

        Assert.Contains("請至少選擇", vm.StatusMessage);
    }

    [Fact]
    public void ApplyChanges_Success_SetsSuccessStatus()
    {
        _serverTxtService.DiscoverPaths().Returns(new List<string> { @"C:\WDMIS\SERVER.txt" });
        _serverTxtService.Apply(Arg.Any<string>(), Arg.Any<ConnectionProfile>()).Returns(true);
        _serverTxtService.ReadEntry(Arg.Any<string>()).Returns(new ServerTxtEntry
        {
            Field1 = "mis", DatabaseName = "old", ServerAddress = "0.0.0.0", Field4 = "X", Field5 = "1"
        });

        var vm = CreateVm();
        vm.ApplyChangesCommand.Execute(null);

        Assert.Contains("成功", vm.StatusMessage);
    }

    [Fact]
    public void AddCustomConnection_CallsSettingsService()
    {
        var vm = CreateVm();
        vm.AddCustomConnection("new", "10.0.0.1", "testdb");

        _settingsService.Received(1).AddProfile(Arg.Is<ConnectionProfile>(
            p => p.Name == "new" && p.Server == "10.0.0.1" && p.Database == "testdb"));
    }

    [Fact]
    public void DeleteCustomConnection_OnlyDeletesCustomSource()
    {
        var vm = CreateVm();
        var tableSpecProfile = new ConnectionProfile { Id = "1", Name = "dev", Source = "TableSpec" };

        vm.DeleteCustomConnection(tableSpecProfile);

        _settingsService.DidNotReceive().DeleteProfile(Arg.Any<string>());
    }
}
