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
    public void Source_IsJsonIgnored()
    {
        var profile = new ConnectionProfile { Name = "test", Source = "TableSpec" };
        var json = JsonSerializer.Serialize(profile);
        Assert.DoesNotContain("Source", json);
        Assert.DoesNotContain("TableSpec", json);
    }
}
