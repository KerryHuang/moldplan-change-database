using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class SettingsServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly SettingsService _service;

    public SettingsServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "MoldplanDbSwitcherTest_" + Guid.NewGuid());
        Directory.CreateDirectory(_tempDir);
        _service = new SettingsService(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, true);
    }

    [Fact]
    public void LoadProfiles_NoFile_ReturnsEmpty()
    {
        var profiles = _service.LoadProfiles();
        Assert.Empty(profiles);
    }

    [Fact]
    public void AddProfile_ThenLoad_ReturnsSavedProfile()
    {
        var profile = new ConnectionProfile
        {
            Name = "test",
            Server = "127.0.0.1",
            Database = "mis"
        };

        _service.AddProfile(profile);
        var loaded = _service.LoadProfiles();

        Assert.Single(loaded);
        Assert.Equal("test", loaded[0].Name);
        Assert.Equal("127.0.0.1", loaded[0].Server);
        Assert.Equal("mis", loaded[0].Database);
    }

    [Fact]
    public void DeleteProfile_RemovesCorrectProfile()
    {
        var p1 = new ConnectionProfile { Id = "id1", Name = "one" };
        var p2 = new ConnectionProfile { Id = "id2", Name = "two" };

        _service.AddProfile(p1);
        _service.AddProfile(p2);
        _service.DeleteProfile("id1");

        var loaded = _service.LoadProfiles();
        Assert.Single(loaded);
        Assert.Equal("two", loaded[0].Name);
    }

    [Fact]
    public void UpdateProfile_ModifiesExisting()
    {
        var profile = new ConnectionProfile { Id = "id1", Name = "old", Server = "1.1.1.1", Database = "db1" };
        _service.AddProfile(profile);

        profile.Name = "new";
        profile.Server = "2.2.2.2";
        _service.UpdateProfile(profile);

        var loaded = _service.LoadProfiles();
        Assert.Single(loaded);
        Assert.Equal("new", loaded[0].Name);
        Assert.Equal("2.2.2.2", loaded[0].Server);
    }
}
