using Xunit;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ConnectionDialogViewModelTests
{
    [Fact]
    public void IsValid_AllFieldsFilled_ReturnsTrue()
    {
        var vm = new ConnectionDialogViewModel
        {
            Name = "test",
            Server = "127.0.0.1",
            Database = "mis"
        };
        Assert.True(vm.IsValid);
    }

    [Theory]
    [InlineData("", "127.0.0.1", "mis")]
    [InlineData("test", "", "mis")]
    [InlineData("test", "127.0.0.1", "")]
    [InlineData("  ", "127.0.0.1", "mis")]
    public void IsValid_MissingField_ReturnsFalse(string name, string server, string database)
    {
        var vm = new ConnectionDialogViewModel
        {
            Name = name,
            Server = server,
            Database = database
        };
        Assert.False(vm.IsValid);
    }
}
