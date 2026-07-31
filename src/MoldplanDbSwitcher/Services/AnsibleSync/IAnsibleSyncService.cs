using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services.AnsibleSync;

public interface IAnsibleSyncService
{
    Task<AnsibleSyncResult> SyncAsync();
}
