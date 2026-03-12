using System.Text.Json;
using Xunit;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class ConnectionProfileTests
{
    [Fact]
    public void Deserialize_TableSpecFormat_ReadsCorrectly()
    {
        var json = """
        {
            "profiles": [
                {
                    "id": "test-id",
                    "name": "dev",
                    "server": "127.0.0.1",
                    "database": "mis",
                    "authType": 0,
                    "username": "",
                    "password": "",
                    "isDefault": true
                }
            ],
            "currentProfileId": "test-id"
        }
        """;

        var data = JsonSerializer.Deserialize<ConnectionsFile>(json);

        Assert.NotNull(data);
        Assert.Single(data.Profiles);
        Assert.Equal("dev", data.Profiles[0].Name);
        Assert.Equal("127.0.0.1", data.Profiles[0].Server);
        Assert.Equal("mis", data.Profiles[0].Database);
        Assert.Equal("test-id", data.CurrentProfileId);
    }

    [Fact]
    public void Deserialize_WithCredentials_ReadsUsernameAndPassword()
    {
        var json = """
        {
            "profiles": [
                {
                    "Id": "test-id",
                    "Name": "Gma-Staging",
                    "Server": "192.168.1.250",
                    "Database": "gma-staging",
                    "AuthType": 1,
                    "Username": "mis",
                    "Password": "service",
                    "IsDefault": false
                }
            ],
            "CurrentProfileId": "test-id"
        }
        """;

        var data = JsonSerializer.Deserialize<ConnectionsFile>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        Assert.NotNull(data);
        Assert.Single(data.Profiles);
        Assert.Equal("mis", data.Profiles[0].Username);
        Assert.Equal("service", data.Profiles[0].Password);
    }

    [Fact]
    public void Source_IsJsonIgnored()
    {
        var profile = new ConnectionProfile { Name = "test", Source = "TableSpec" };
        var json = JsonSerializer.Serialize(profile);
        Assert.DoesNotContain("Source", json);
        Assert.DoesNotContain("TableSpec", json);
    }

    [Fact]
    public void NewProfile_AuthType_DefaultsToWindowsAuthentication()
    {
        var profile = new ConnectionProfile();
        Assert.Equal(AuthenticationType.WindowsAuthentication, profile.AuthType);
    }

    [Fact]
    public void NewProfile_IsDefault_DefaultsToFalse()
    {
        var profile = new ConnectionProfile();
        Assert.False(profile.IsDefault);
    }

    [Fact]
    public void Deserialize_MissingAuthTypeAndIsDefault_UsesDefaults()
    {
        var json = """
        {
            "profiles": [
                {
                    "id": "test-id",
                    "name": "dev",
                    "server": "127.0.0.1",
                    "database": "mis",
                    "username": "",
                    "password": ""
                }
            ],
            "currentProfileId": "test-id"
        }
        """;

        var data = JsonSerializer.Deserialize<ConnectionsFile>(json);

        Assert.NotNull(data);
        Assert.Equal(AuthenticationType.WindowsAuthentication, data.Profiles[0].AuthType);
        Assert.False(data.Profiles[0].IsDefault);
    }
}
