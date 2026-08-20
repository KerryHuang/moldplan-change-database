using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ServerTxtService : IServerTxtService
{
    private readonly string[] _searchPaths;

    public ServerTxtService() : this(GetDefaultPaths())
    {
    }

    public ServerTxtService(string[] searchPaths)
    {
        _searchPaths = searchPaths;
    }

    public static string[] GetDefaultPaths()
    {
        if (OperatingSystem.IsWindows())
        {
            return [
                @"C:\WDMIS\SERVER.txt",
                @"D:\WDMIS\SERVER.txt"
            ];
        }

        if (OperatingSystem.IsMacOS() || OperatingSystem.IsLinux())
        {
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            return [
                Path.Combine(home, "WDMIS", "SERVER.txt")
            ];
        }

        return [];
    }

    public List<string> DiscoverPaths()
    {
        return _searchPaths.Where(File.Exists).ToList();
    }

    public ServerTxtEntry? ReadEntry(string path)
    {
        try
        {
            var line = File.ReadAllText(path).Trim();
            return ServerTxtEntry.Parse(line);
        }
        catch
        {
            return null;
        }
    }

    // SERVER.txt 為逗號分隔格式，伺服器位址不能帶「,PORT」後綴
    private static string StripPort(string server)
    {
        var commaIndex = server.IndexOf(',');
        return commaIndex >= 0 ? server[..commaIndex] : server;
    }

    public string Preview(ServerTxtEntry original, ConnectionProfile target)
    {
        var modified = new ServerTxtEntry
        {
            Field1 = original.Field1,
            DatabaseName = target.Database,
            ServerAddress = StripPort(target.Server),
            Field4 = original.Field4,
            Field5 = original.Field5
        };
        return modified.ToLine();
    }

    public bool Apply(string path, ConnectionProfile target)
    {
        try
        {
            var entry = ReadEntry(path);
            if (entry is null) return false;

            entry.DatabaseName = target.Database;
            entry.ServerAddress = StripPort(target.Server);
            File.WriteAllText(path, entry.ToLine());
            return true;
        }
        catch
        {
            return false;
        }
    }
}
