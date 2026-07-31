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

    [Fact]
    public void Create_指定ConnectTimeout_連線字串使用該值()
    {
        var profile = new ConnectionProfile { Server = "127.0.0.1", Database = "mis" };

        using var conn = _factory.Create(profile, 5);

        var builder = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(conn.ConnectionString);
        Assert.Equal(5, builder.ConnectTimeout);
    }

    [Fact]
    public void Create_未指定ConnectTimeout_維持預設10秒()
    {
        var profile = new ConnectionProfile { Server = "127.0.0.1", Database = "mis" };

        using var conn = _factory.Create(profile);

        var builder = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(conn.ConnectionString);
        Assert.Equal(10, builder.ConnectTimeout);
    }
}
