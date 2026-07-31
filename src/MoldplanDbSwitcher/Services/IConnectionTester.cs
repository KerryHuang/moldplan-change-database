using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

/// <summary>單一連線的可達性測試。抽成介面是為了讓 ConnectionProbeService 可被單元測試
/// （SqlConnection.OpenAsync 無法 mock）。</summary>
public interface IConnectionTester
{
    Task<bool> CanConnectAsync(ConnectionProfile profile, CancellationToken ct = default);
}
