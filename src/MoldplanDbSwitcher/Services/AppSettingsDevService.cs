using System.Text.Json.Nodes;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class AppSettingsDevService : IAppSettingsDevService
{
    public IReadOnlyList<string> FindFiles(string directory)
    {
        if (!Directory.Exists(directory))
            return [];

        return Directory.EnumerateFiles(directory, "appsettings.Development.json",
            SearchOption.AllDirectories)
            .Where(f => !IsUnderBinOrObj(f, directory))
            .Where(HasMssqlSection)
            .ToList();
    }

    private static bool IsUnderBinOrObj(string filePath, string baseDirectory)
    {
        var relative = Path.GetRelativePath(baseDirectory, filePath);
        var parts = relative.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        return parts.Any(p => p.Equals("bin", StringComparison.OrdinalIgnoreCase)
                           || p.Equals("obj", StringComparison.OrdinalIgnoreCase));
    }

    private static bool HasMssqlSection(string filePath)
    {
        try
        {
            var root = JsonNode.Parse(File.ReadAllText(filePath));
            if (root is not JsonObject rootObj) return false;
            if (rootObj["MSSQL"] is not JsonObject mssql) return false;
            return mssql["Host"] is not null
                && mssql["Port"] is not null
                && mssql["UserId"] is not null
                && mssql["Password"] is not null
                && mssql["ApplicationDatabase"] is not null;
        }
        catch
        {
            return false;
        }
    }

    public bool Apply(string filePath, ConnectionProfile profile)
    {
        var text = File.ReadAllText(filePath);
        var root = JsonNode.Parse(text);
        if (root is not JsonObject rootObj)
            return false;

        if (rootObj["MSSQL"] is not JsonObject mssql)
            return false;

        var (host, port) = SplitServer(profile.Server);
        mssql["Host"] = host;
        mssql["Port"] = port;
        mssql["UserId"] = profile.Username;
        mssql["Password"] = profile.Password;
        mssql["ApplicationDatabase"] = profile.Database;

        File.WriteAllText(filePath, root.ToJsonString(new System.Text.Json.JsonSerializerOptions
        {
            WriteIndented = true
        }));
        return true;
    }

    private static (string host, string port) SplitServer(string server)
    {
        var idx = server.IndexOf(',');
        if (idx >= 0)
            return (server[..idx], server[(idx + 1)..]);
        return (server, "1433");
    }
}
