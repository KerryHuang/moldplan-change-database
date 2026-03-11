using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IServerTxtService
{
    List<string> DiscoverPaths();
    ServerTxtEntry? ReadEntry(string path);
    string Preview(ServerTxtEntry original, ConnectionProfile target);
    bool Apply(string path, ConnectionProfile target);
}
