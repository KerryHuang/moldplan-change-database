using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IAppSettingsDevService
{
    IReadOnlyList<string> FindFiles(string directory);
    bool Apply(string filePath, ConnectionProfile profile);
}
