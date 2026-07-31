using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ConnectionProbeService : IConnectionProbeService
{
    private readonly IConnectionTester _tester;

    public ConnectionProbeService(IConnectionTester tester)
    {
        _tester = tester;
    }

    public async Task<ConnectionProbeResult> ProbeAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null,
        CancellationToken ct = default)
    {
        progress?.Report($"正在檢查 {profiles.Count} 個連線...");

        // Task.WhenAll 保留輸入順序，Reachable 因此與 profiles 同序
        var results = await Task.WhenAll(profiles.Select(async p =>
            (Profile: p, CanConnect: await _tester.CanConnectAsync(p, ct))));

        var reachable = results.Where(r => r.CanConnect).Select(r => r.Profile).ToList();
        var unreachable = results.Where(r => !r.CanConnect).Select(r => r.Profile.Name).ToList();

        progress?.Report($"{reachable.Count} 個可連線，跳過 {unreachable.Count} 個");

        return new ConnectionProbeResult(reachable, unreachable);
    }
}
