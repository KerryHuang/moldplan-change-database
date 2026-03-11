using Xunit;
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class ConnectionSourceServiceTests
{
    private readonly ISettingsService _settingsService;
    private readonly ConnectionSourceService _service;

    public ConnectionSourceServiceTests()
    {
        _settingsService = Substitute.For<ISettingsService>();
        _service = new ConnectionSourceService(_settingsService, Path.Combine(Path.GetTempPath(), "nonexistent", "connections.json"));
    }

    [Fact]
    public void LoadTableSpecConnections_NoFile_ReturnsEmpty()
    {
        var result = _service.LoadTableSpecConnections();
        Assert.Empty(result);
    }

    [Fact]
    public void LoadCustomConnections_ReturnsFromSettingsService()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "custom1", Server = "1.1.1.1", Database = "db1" }
        };
        _settingsService.LoadProfiles().Returns(profiles);

        var result = _service.LoadCustomConnections();

        Assert.Single(result);
        Assert.Equal("Custom", result[0].Source);
    }

    [Fact]
    public void LoadAllConnections_CombinesBothSources()
    {
        _settingsService.LoadProfiles().Returns(new List<ConnectionProfile>
        {
            new() { Name = "custom1" }
        });

        var result = _service.LoadAllConnections();
        Assert.Single(result);
    }

    [Fact]
    public void LoadTableSpecConnections_ValidFile_SetsSourceToTableSpec()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), "TableSpecTest_" + Guid.NewGuid());
        Directory.CreateDirectory(tempDir);
        var tempPath = Path.Combine(tempDir, "connections.json");
        File.WriteAllText(tempPath, """
        {
            "profiles": [
                { "id": "1", "name": "dev", "server": "127.0.0.1", "database": "mis" }
            ]
        }
        """);

        try
        {
            var service = new ConnectionSourceService(_settingsService, tempPath);
            var result = service.LoadTableSpecConnections();

            Assert.Single(result);
            Assert.Equal("TableSpec", result[0].Source);
            Assert.Equal("dev", result[0].Name);
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void LoadTableSpecConnections_PascalCaseJson_ReadsCorrectly()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), "TableSpecPascal_" + Guid.NewGuid());
        Directory.CreateDirectory(tempDir);
        var tempPath = Path.Combine(tempDir, "connections.json");
        File.WriteAllText(tempPath, """
        {
            "Profiles": [
                { "Id": "1", "Name": "WDMIS", "Server": "100.73.36.124", "Database": "MoldPlanDataModel" }
            ],
            "CurrentProfileId": "1"
        }
        """);

        try
        {
            var service = new ConnectionSourceService(_settingsService, tempPath);
            var result = service.LoadTableSpecConnections();

            Assert.Single(result);
            Assert.Equal("WDMIS", result[0].Name);
            Assert.Equal("100.73.36.124", result[0].Server);
            Assert.Equal("MoldPlanDataModel", result[0].Database);
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }
}
