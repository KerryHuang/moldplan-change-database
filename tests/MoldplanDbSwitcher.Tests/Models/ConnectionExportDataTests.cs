using System.Text.Json;
using Xunit;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class ConnectionExportDataTests
{
    [Fact]
    public void NewExportData_Version_DefaultsTo1()
    {
        var data = new ConnectionExportData { Profiles = new List<ConnectionProfile>() };
        Assert.Equal(1, data.Version);
    }

    [Fact]
    public void NewExportData_ExportedAt_DefaultsToUtcNow()
    {
        var before = DateTime.UtcNow;
        var data = new ConnectionExportData { Profiles = new List<ConnectionProfile>() };
        var after = DateTime.UtcNow;
        Assert.InRange(data.ExportedAt, before, after);
    }

    [Fact]
    public void Serialize_RoundTrip_PreservesData()
    {
        var original = new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "test", Server = "127.0.0.1", Database = "mis" }
            }
        };
        var json = JsonSerializer.Serialize(original);
        var restored = JsonSerializer.Deserialize<ConnectionExportData>(json);
        Assert.NotNull(restored);
        Assert.Equal(1, restored.Version);
        Assert.Single(restored.Profiles);
        Assert.Equal("test", restored.Profiles[0].Name);
    }
}
