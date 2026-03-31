using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services.AnsibleSync;

public interface IAnsibleSyncService
{
    Task<List<ConnectionProfile>> SyncAsync();
}
