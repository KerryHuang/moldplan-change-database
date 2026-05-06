using System.Text.Json;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class AppSettingsDevServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly AppSettingsDevService _sut;

    public AppSettingsDevServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(_tempDir);
        _sut = new AppSettingsDevService();
    }

    public void Dispose() => Directory.Delete(_tempDir, recursive: true);

    [Fact]
    public void FindFiles_EmptyDirectory_ReturnsEmptyList()
    {
        var result = _sut.FindFiles(_tempDir);
        Assert.Empty(result);
    }

    [Fact]
    public void FindFiles_NonExistentDirectory_ReturnsEmptyList()
    {
        var result = _sut.FindFiles(Path.Combine(_tempDir, "nonexistent"));
        Assert.Empty(result);
    }

    [Fact]
    public void FindFiles_WithNestedFiles_ReturnsAllPaths()
    {
        var sub = Path.Combine(_tempDir, "projectA", "src");
        Directory.CreateDirectory(sub);
        var file1 = Path.Combine(_tempDir, "appsettings.Development.json");
        var file2 = Path.Combine(sub, "appsettings.Development.json");
        File.WriteAllText(file1, "{}");
        File.WriteAllText(file2, "{}");

        var result = _sut.FindFiles(_tempDir);

        Assert.Equal(2, result.Count);
        Assert.Contains(file1, result);
        Assert.Contains(file2, result);
    }

    [Fact]
    public void FindFiles_IgnoresOtherJsonFiles()
    {
        File.WriteAllText(Path.Combine(_tempDir, "appsettings.json"), "{}");
        File.WriteAllText(Path.Combine(_tempDir, "appsettings.Production.json"), "{}");

        var result = _sut.FindFiles(_tempDir);

        Assert.Empty(result);
    }

    [Fact]
    public void Apply_UpdatesMssqlFields_LeavesOtherFieldsIntact()
    {
        var filePath = Path.Combine(_tempDir, "appsettings.Development.json");
        File.WriteAllText(filePath, """
        {
          "MSSQL": {
            "Host": "old-host",
            "Port": "1433",
            "UserId": "old-user",
            "Password": "old-pass",
            "ApplicationDatabase": "old-db",
            "LocalizationDatabase": "loc-db",
            "QuartzJobDatabase": "quartz-db"
          },
          "OtherSection": { "Key": "value" }
        }
        """);

        var profile = new ConnectionProfile
        {
            Server = "192.168.1.100",
            Database = "new-app-db",
            Username = "mis",
            Password = "secret"
        };

        var result = _sut.Apply(filePath, profile);

        Assert.True(result);
        var json = JsonDocument.Parse(File.ReadAllText(filePath));
        var mssql = json.RootElement.GetProperty("MSSQL");
        Assert.Equal("192.168.1.100", mssql.GetProperty("Host").GetString());
        Assert.Equal("1433", mssql.GetProperty("Port").GetString());
        Assert.Equal("mis", mssql.GetProperty("UserId").GetString());
        Assert.Equal("secret", mssql.GetProperty("Password").GetString());
        Assert.Equal("new-app-db", mssql.GetProperty("ApplicationDatabase").GetString());
        Assert.Equal("loc-db", mssql.GetProperty("LocalizationDatabase").GetString());
        Assert.Equal("quartz-db", mssql.GetProperty("QuartzJobDatabase").GetString());
        Assert.Equal("value", json.RootElement.GetProperty("OtherSection").GetProperty("Key").GetString());
    }

    [Fact]
    public void Apply_ServerWithPort_SplitsCorrectly()
    {
        var filePath = Path.Combine(_tempDir, "appsettings.Development.json");
        File.WriteAllText(filePath, """
        {
          "MSSQL": {
            "Host": "old",
            "Port": "1433",
            "UserId": "u",
            "Password": "p",
            "ApplicationDatabase": "db"
          }
        }
        """);

        var profile = new ConnectionProfile
        {
            Server = "192.168.21.1,1430",
            Database = "mydb",
            Username = "mis",
            Password = "pass"
        };

        _sut.Apply(filePath, profile);

        var json = JsonDocument.Parse(File.ReadAllText(filePath));
        var mssql = json.RootElement.GetProperty("MSSQL");
        Assert.Equal("192.168.21.1", mssql.GetProperty("Host").GetString());
        Assert.Equal("1430", mssql.GetProperty("Port").GetString());
    }

    [Fact]
    public void Apply_ServerWithoutPort_DefaultsTo1433()
    {
        var filePath = Path.Combine(_tempDir, "appsettings.Development.json");
        File.WriteAllText(filePath, """
        {
          "MSSQL": {
            "Host": "old",
            "Port": "9999",
            "UserId": "u",
            "Password": "p",
            "ApplicationDatabase": "db"
          }
        }
        """);

        var profile = new ConnectionProfile
        {
            Server = "192.168.1.1",
            Database = "mydb",
            Username = "mis",
            Password = "pass"
        };

        _sut.Apply(filePath, profile);

        var json = JsonDocument.Parse(File.ReadAllText(filePath));
        var mssql = json.RootElement.GetProperty("MSSQL");
        Assert.Equal("192.168.1.1", mssql.GetProperty("Host").GetString());
        Assert.Equal("1433", mssql.GetProperty("Port").GetString());
    }

    [Fact]
    public void Apply_MissingMssqlSection_ReturnsFalse()
    {
        var filePath = Path.Combine(_tempDir, "appsettings.Development.json");
        File.WriteAllText(filePath, """{ "Other": {} }""");

        var profile = new ConnectionProfile { Server = "1.1.1.1", Database = "db" };

        var result = _sut.Apply(filePath, profile);

        Assert.False(result);
    }
}
