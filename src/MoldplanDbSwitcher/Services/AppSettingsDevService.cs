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
            SearchOption.AllDirectories).ToList();
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
