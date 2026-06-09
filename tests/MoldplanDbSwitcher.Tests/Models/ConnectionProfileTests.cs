using System.Text.Json;
using Xunit;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class ConnectionProfileTests
{
    [Fact]
    public void Deserialize_SpecuraiFormat_ReadsCorrectly()
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

    [Fact]
    public void Environment_預設為Staging()
    {
        var p = new ConnectionProfile { Name = "a", Server = "s", Database = "d" };
        Assert.Equal(DatabaseEnvironment.Staging, p.Environment);
    }

    [Fact]
    public void Environment_序列化往返應保留()
    {
        var p = new ConnectionProfile { Name = "a", Server = "s", Database = "d", Environment = DatabaseEnvironment.Production };
        var json = JsonSerializer.Serialize(p);
        var back = JsonSerializer.Deserialize<ConnectionProfile>(json);
        Assert.Equal(DatabaseEnvironment.Production, back!.Environment);
    }

    [Fact]
    public void Environment_序列化為數字()
    {
        var p = new ConnectionProfile { Name = "a", Server = "s", Database = "d", Environment = DatabaseEnvironment.Production };
        var json = JsonSerializer.Serialize(p);
        Assert.Contains("\"environment\":3", json);
    }

    [Fact]
    public void 反序列化舊JSON無environment欄位_應為Staging()
    {
        var json = "{\"name\":\"a\",\"server\":\"s\",\"database\":\"d\",\"authType\":0}";
        var p = JsonSerializer.Deserialize<ConnectionProfile>(json);
        Assert.Equal(DatabaseEnvironment.Staging, p!.Environment);
    }

    [Fact]
    public void 反序列化Specurai式PascalCase數字_應正確對應環境()
    {
        var json = "{\"Name\":\"a\",\"Server\":\"s\",\"Database\":\"d\",\"Environment\":3}";
        var p = JsonSerializer.Deserialize<ConnectionProfile>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        Assert.Equal(DatabaseEnvironment.Production, p!.Environment);
    }
}
