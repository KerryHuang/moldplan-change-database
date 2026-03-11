using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class SettingsService : ISettingsService
{
    private readonly string _configPath;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    public SettingsService() : this(Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "MoldplanDbSwitcher"))
    {
    }

    public SettingsService(string configDir)
    {
        Directory.CreateDirectory(configDir);
        _configPath = Path.Combine(configDir, "connections.json");
    }

    public List<ConnectionProfile> LoadProfiles()
    {
        if (!File.Exists(_configPath))
            return [];

        try
        {
            var json = File.ReadAllText(_configPath);
            var data = JsonSerializer.Deserialize<ConnectionsFile>(json, JsonOptions);
            return data?.Profiles ?? [];
        }
        catch
        {
            return [];
        }
    }

    public void SaveProfiles(List<ConnectionProfile> profiles)
    {
        var data = new ConnectionsFile { Profiles = profiles };
        var json = JsonSerializer.Serialize(data, JsonOptions);
        File.WriteAllText(_configPath, json);
    }

    public void AddProfile(ConnectionProfile profile)
    {
        var profiles = LoadProfiles();
        profiles.Add(profile);
        SaveProfiles(profiles);
    }

    public void UpdateProfile(ConnectionProfile profile)
    {
        var profiles = LoadProfiles();
        var index = profiles.FindIndex(p => p.Id == profile.Id);
        if (index >= 0)
        {
            profiles[index] = profile;
            SaveProfiles(profiles);
        }
    }

    public void DeleteProfile(string id)
    {
        var profiles = LoadProfiles();
        profiles.RemoveAll(p => p.Id == id);
        SaveProfiles(profiles);
    }
}
