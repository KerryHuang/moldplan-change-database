using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class AppSettingsService : IAppSettingsService
{
    private readonly string _filePath;

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public AppSettingsService() : this(Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "MoldplanDbSwitcher"))
    {
    }

    public AppSettingsService(string configDir)
    {
        Directory.CreateDirectory(configDir);
        _filePath = Path.Combine(configDir, "app-settings.json");
    }

    public AppSettings Load()
    {
        if (!File.Exists(_filePath))
            return new AppSettings();

        try
        {
            var json = File.ReadAllText(_filePath);
            return JsonSerializer.Deserialize<AppSettings>(json, JsonOptions) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        var json = JsonSerializer.Serialize(settings, JsonOptions);
        File.WriteAllText(_filePath, json);
    }

    private static readonly string DefaultScriptsRelative = Path.Combine("docs", "scripts", "Reporting");
    private static readonly string FallbackAbsolute = OperatingSystem.IsWindows()
        ? @"D:\Repos\MoldPlan-Workspace\docs\scripts\Reporting"
        : Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            "repos", "MoldPlan-Workspace", "docs", "scripts", "Reporting");

    public string GetMoldPlanScriptsPath()
    {
        var settings = Load();
        if (!string.IsNullOrWhiteSpace(settings.MoldPlanScriptsPath))
            return settings.MoldPlanScriptsPath;

        var envRepo = Environment.GetEnvironmentVariable("MOLDPLAN_REPO");
        if (!string.IsNullOrWhiteSpace(envRepo))
            return Path.Combine(envRepo, DefaultScriptsRelative);

        return FallbackAbsolute;
    }
}
