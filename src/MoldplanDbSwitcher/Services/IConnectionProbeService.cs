using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

/// <summary>探測結果。Unreachable 存連線名稱，與報表既有的 FailedConnections 風格一致。</summary>
public record ConnectionProbeResult(
    List<ConnectionProfile> Reachable,
    List<string> Unreachable);

public interface IConnectionProbeService
{
    /// <summary>平行探測所有連線，只做 OpenAsync 不執行查詢。</summary>
    Task<ConnectionProbeResult> ProbeAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null,
        CancellationToken ct = default);
}
