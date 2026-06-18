using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class AppSettingsServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly AppSettingsService _sut;

    public AppSettingsServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(_tempDir);
        _sut = new AppSettingsService(_tempDir);
    }

    public void Dispose() => Directory.Delete(_tempDir, true);

    [Fact]
    public void Load_NoFile_ReturnsDefaults()
    {
        var settings = _sut.Load();

        Assert.Equal(string.Empty, settings.AnsibleRepoPath);
        Assert.Contains(".ansible-vault-pass", settings.VaultPasswordFile);
    }

    [Fact]
    public void Save_ThenLoad_RoundTrips()
    {
        var settings = new AppSettings
        {
            AnsibleRepoPath = "/home/user/deploy-ansible",
            VaultPasswordFile = "/home/user/.my-vault-pass"
        };

        _sut.Save(settings);
        var loaded = _sut.Load();

        Assert.Equal("/home/user/deploy-ansible", loaded.AnsibleRepoPath);
        Assert.Equal("/home/user/.my-vault-pass", loaded.VaultPasswordFile);
    }

    [Fact]
    public void Save_CreatesFile_InConfigDir()
    {
        _sut.Save(new AppSettings());

        Assert.True(File.Exists(Path.Combine(_tempDir, "app-settings.json")));
    }

    [Fact]
    public void Save_ReportingScriptsOverridePath_RoundTrips()
    {
        var settings = new AppSettings
        {
            ReportingScriptsOverridePath = "X:/some/dir"
        };

        _sut.Save(settings);
        var loaded = _sut.Load();

        Assert.Equal("X:/some/dir", loaded.ReportingScriptsOverridePath);
    }

    [Fact]
    public void Load_NoFile_ReportingScriptsOverridePath_IsEmpty()
    {
        var settings = _sut.Load();
        Assert.Equal(string.Empty, settings.ReportingScriptsOverridePath);
    }
}
