using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ConnectionSourceService : IConnectionSourceService
{
    private readonly ISettingsService _settingsService;
    private readonly string _specuraiPath;

    public ConnectionSourceService(ISettingsService settingsService)
        : this(settingsService, Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Specurai",
            "connections.json"))
    {
    }

    public ConnectionSourceService(ISettingsService settingsService, string specuraiPath)
    {
        _settingsService = settingsService;
        _specuraiPath = specuraiPath;
    }

    public List<ConnectionProfile> LoadSpecuraiConnections()
    {
        if (!File.Exists(_specuraiPath))
            return [];

        try
        {
            var json = File.ReadAllText(_specuraiPath);
            var data = JsonSerializer.Deserialize<ConnectionsFile>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
            if (data?.Profiles is null) return [];

            foreach (var p in data.Profiles)
                p.Source = "Specurai";

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
        all.AddRange(LoadSpecuraiConnections());
        all.AddRange(LoadCustomConnections());
        return all;
    }
}
