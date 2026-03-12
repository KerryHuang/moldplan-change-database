using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class SqlConnectionFactoryTests
{
    private readonly SqlConnectionFactory _factory = new();

    [Fact]
    public void Create_WindowsAuth_UsesIntegratedSecurity()
    {
        var profile = new ConnectionProfile
        {
            Server = "127.0.0.1", Database = "mis",
            AuthType = AuthenticationType.WindowsAuthentication
        };
        using var conn = _factory.Create(profile);
        Assert.Contains("Integrated Security", conn.ConnectionString, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("User ID", conn.ConnectionString, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Create_SqlAuth_UsesUsernamePassword()
    {
        var profile = new ConnectionProfile
        {
            Server = "127.0.0.1", Database = "mis",
            AuthType = AuthenticationType.SqlServerAuthentication,
            Username = "sa", Password = "secret"
        };
        using var conn = _factory.Create(profile);
        Assert.Contains("User ID=sa", conn.ConnectionString);
        Assert.Contains("Password=secret", conn.ConnectionString);
    }
}
