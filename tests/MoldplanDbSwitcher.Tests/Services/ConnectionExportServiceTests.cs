using System.Text.Json;
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class ConnectionExportServiceTests
{
    private readonly ConnectionExportService _service = new();

    [Fact]
    public void ExportToJson_BasicProfiles_ReturnsValidJson()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis" }
        };
        var bytes = _service.ExportToJson(profiles, includePasswords: false);
        var data = JsonSerializer.Deserialize<ConnectionExportData>(bytes);
        Assert.NotNull(data);
        Assert.Equal(1, data.Version);
        Assert.Single(data.Profiles);
        Assert.Equal("dev", data.Profiles[0].Name);
    }

    [Fact]
    public void ExportToJson_IncludePasswordsFalse_NullsOutPasswords()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Password = "secret" }
        };
        var bytes = _service.ExportToJson(profiles, includePasswords: false);
        var data = JsonSerializer.Deserialize<ConnectionExportData>(bytes);
        Assert.NotNull(data);
        Assert.Null(data.Profiles[0].Password);
    }

    [Fact]
    public void ExportToJson_IncludePasswordsTrue_PreservesPasswords()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Password = "secret" }
        };
        var bytes = _service.ExportToJson(profiles, includePasswords: true);
        var data = JsonSerializer.Deserialize<ConnectionExportData>(bytes);
        Assert.NotNull(data);
        Assert.Equal("secret", data.Profiles[0].Password);
    }

    [Fact]
    public void ImportFromJson_ValidData_ReturnsExportData()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis" }
        };
        var bytes = _service.ExportToJson(profiles, includePasswords: true);
        var result = _service.ImportFromJson(bytes);
        Assert.Equal(1, result.Version);
        Assert.Single(result.Profiles);
        Assert.Equal("dev", result.Profiles[0].Name);
    }

    [Fact]
    public void ImportFromJson_InvalidData_ThrowsException()
    {
        var bytes = System.Text.Encoding.UTF8.GetBytes("not json");
        Assert.ThrowsAny<Exception>(() => _service.ImportFromJson(bytes));
    }

    [Fact]
    public void IsEncryptedFormat_WithMagicBytes_ReturnsTrue()
    {
        var data = new byte[] { (byte)'T', (byte)'S', (byte)'E', (byte)'C', 0, 0, 0, 0 };
        Assert.True(_service.IsEncryptedFormat(data));
    }

    [Fact]
    public void IsEncryptedFormat_WithJsonData_ReturnsFalse()
    {
        var data = System.Text.Encoding.UTF8.GetBytes("{\"Version\":1}");
        Assert.False(_service.IsEncryptedFormat(data));
    }

    [Fact]
    public void IsEncryptedFormat_TooShort_ReturnsFalse()
    {
        var data = new byte[] { (byte)'T', (byte)'S' };
        Assert.False(_service.IsEncryptedFormat(data));
    }
}
