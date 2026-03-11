using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IConnectionSourceService
{
    List<ConnectionProfile> LoadTableSpecConnections();
    List<ConnectionProfile> LoadCustomConnections();
    List<ConnectionProfile> LoadAllConnections();
}
