using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class ServerTxtServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly ServerTxtService _service;

    public ServerTxtServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "ServerTxtTest_" + Guid.NewGuid());
        Directory.CreateDirectory(_tempDir);
        _service = new ServerTxtService([Path.Combine(_tempDir, "SERVER.txt")]);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, true);
    }

    [Fact]
    public void DiscoverPaths_NoFile_ReturnsEmpty()
    {
        Assert.Empty(_service.DiscoverPaths());
    }

    [Fact]
    public void DiscoverPaths_FileExists_ReturnsPath()
    {
        var path = Path.Combine(_tempDir, "SERVER.txt");
        File.WriteAllText(path, "mis,db,server,x,1");

        var result = _service.DiscoverPaths();
        Assert.Single(result);
        Assert.Equal(path, result[0]);
    }

    [Fact]
    public void ReadEntry_ValidFile_ReturnsEntry()
    {
        var path = Path.Combine(_tempDir, "SERVER.txt");
        File.WriteAllText(path, "mis,yuchiun-test,100.73.36.124,XXX,1");

        var entry = _service.ReadEntry(path);

        Assert.NotNull(entry);
        Assert.Equal("yuchiun-test", entry.DatabaseName);
        Assert.Equal("100.73.36.124", entry.ServerAddress);
    }

    [Fact]
    public void Preview_ReturnsModifiedLine()
    {
        var original = new ServerTxtEntry
        {
            Field1 = "mis",
            DatabaseName = "yuchiun-test",
            ServerAddress = "100.73.36.124",
            Field4 = "XXX",
            Field5 = "1"
        };
        var target = new ConnectionProfile { Server = "127.0.0.1", Database = "yuchiun" };

        var result = _service.Preview(original, target);
        Assert.Equal("mis,yuchiun,127.0.0.1,XXX,1", result);
    }

    [Fact]
    public void Preview_ServerWithPort_StripsPort()
    {
        var original = new ServerTxtEntry
        {
            Field1 = "mis",
            DatabaseName = "yungmaun-test",
            ServerAddress = "192.20.10.9",
            Field4 = "XXX",
            Field5 = "1"
        };
        var target = new ConnectionProfile { Server = "100.92.189.23,1434", Database = "ANCHIAO" };

        var result = _service.Preview(original, target);
        Assert.Equal("mis,ANCHIAO,100.92.189.23,XXX,1", result);
    }

    [Fact]
    public void Apply_ServerWithPort_StripsPort()
    {
        var path = Path.Combine(_tempDir, "SERVER.txt");
        File.WriteAllText(path, "mis,yungmaun-test,192.20.10.9,XXX,1");

        var target = new ConnectionProfile { Server = "100.92.189.23,1434", Database = "ANCHIAO" };
        var result = _service.Apply(path, target);

        Assert.True(result);
        Assert.Equal("mis,ANCHIAO,100.92.189.23,XXX,1", File.ReadAllText(path));
    }

    [Fact]
    public void Apply_WritesModifiedContent()
    {
        var path = Path.Combine(_tempDir, "SERVER.txt");
        File.WriteAllText(path, "mis,yuchiun-test,100.73.36.124,XXX,1");

        var target = new ConnectionProfile { Server = "127.0.0.1", Database = "yuchiun" };
        var result = _service.Apply(path, target);

        Assert.True(result);
        Assert.Equal("mis,yuchiun,127.0.0.1,XXX,1", File.ReadAllText(path));
    }

    [Fact]
    public void Apply_NonExistentFile_ReturnsFalse()
    {
        var target = new ConnectionProfile { Server = "127.0.0.1", Database = "db" };
        var result = _service.Apply(Path.Combine(_tempDir, "nope.txt"), target);
        Assert.False(result);
    }

    [Fact]
    public void GetDefaultPaths_ReturnsNonEmptyList()
    {
        var paths = ServerTxtService.GetDefaultPaths();
        Assert.NotEmpty(paths);
        Assert.All(paths, p => Assert.Contains("WDMIS", p));
        Assert.All(paths, p => Assert.EndsWith("SERVER.txt", p));
    }

    [Fact]
    public void GetDefaultPaths_OnWindows_IncludesDriveLetters()
    {
        if (!OperatingSystem.IsWindows()) return;

        var paths = ServerTxtService.GetDefaultPaths();
        Assert.Contains(paths, p => p.StartsWith(@"C:\"));
        Assert.Contains(paths, p => p.StartsWith(@"D:\"));
    }

    [Fact]
    public void GetDefaultPaths_OnMac_IncludesHomeDir()
    {
        if (!OperatingSystem.IsMacOS()) return;

        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var paths = ServerTxtService.GetDefaultPaths();
        Assert.Contains(paths, p => p.StartsWith(home));
    }
}
