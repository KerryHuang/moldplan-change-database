using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ConnectionSourceService : IConnectionSourceService
{
    private readonly ISettingsService _settingsService;
    private readonly string _tableSpecPath;

    public ConnectionSourceService(ISettingsService settingsService)
        : this(settingsService, Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "TableSpec",
            "connections.json"))
    {
    }

    public ConnectionSourceService(ISettingsService settingsService, string tableSpecPath)
    {
        _settingsService = settingsService;
        _tableSpecPath = tableSpecPath;
    }

    public List<ConnectionProfile> LoadTableSpecConnections()
    {
        if (!File.Exists(_tableSpecPath))
            return [];

        try
        {
            var json = File.ReadAllText(_tableSpecPath);
            var data = JsonSerializer.Deserialize<ConnectionsFile>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
            if (data?.Profiles is null) return [];

            foreach (var p in data.Profiles)
                p.Source = "TableSpec";

            return data.Profiles;
        }
        catch
        {
            return [];
        }
    }

    public List<ConnectionProfile> LoadCustomConnections()
    {
        var profiles = _settingsService.LoadProfiles();
        foreach (var p in profiles)
            p.Source = "Custom";
        return profiles;
    }

    public List<ConnectionProfile> LoadAllConnections()
    {
        var all = new List<ConnectionProfile>();
        all.AddRange(LoadTableSpecConnections());
        all.AddRange(LoadCustomConnections());
        return all;
    }
}
