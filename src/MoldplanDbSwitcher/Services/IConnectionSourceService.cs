using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IConnectionSourceService
{
    List<ConnectionProfile> LoadSpecuraiConnections();
    List<ConnectionProfile> LoadCustomConnections();
    List<ConnectionProfile> LoadAllConnections();
}
