using System.Diagnostics;
using MoldplanDbSwitcher.Models;
using Velopack;
using Velopack.Sources;
using VelopackUpdateInfo = Velopack.UpdateInfo;

namespace MoldplanDbSwitcher.Services;

/// <summary>
/// Velopack 自動更新實作：Windows 且以 Velopack 安裝時走自動下載＋套用；
/// 其餘情境（macOS、直接解壓執行）委派 fallback 的通知模式。
/// 更新來源為 GitHub private Release，需使用者設定 GitHubToken。
/// </summary>
public sealed class VelopackUpdateCheckService : IUpdateCheckService
{
    private const string RepoUrl = "https://github.com/KerryHuang/moldplan-change-database";

    private readonly IUpdateCheckService _fallback;
    private UpdateManager? _manager;
    private VelopackUpdateInfo? _pending;

    public VelopackUpdateCheckService(IUpdateCheckService fallback)
    {
        _fallback = fallback;
    }

    public async Task<Models.UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default)
    {
        // private repo：Windows 上無 token 時 API 必定 404，直接短路，
        // 免得多建一個用不到的 UpdateManager（非 Windows 時仍交由下方委派 fallback 判斷）
        if (OperatingSystem.IsWindows() && string.IsNullOrWhiteSpace(token))
            return null;

        var manager = GetManagerOrNull(token);
        if (!OperatingSystem.IsWindows() || manager is null || !manager.IsInstalled)
            return await _fallback.CheckAsync(token, ct);

        try
        {
            _pending = await manager.CheckForUpdatesAsync().ConfigureAwait(false);
            if (_pending is null)
                return null;

            var target = _pending.TargetFullRelease;
            return new Models.UpdateInfo(
                target.Version.ToString(),
                $"{RepoUrl}/releases/tag/v{target.Version}",
                target.NotesMarkdown ?? string.Empty,
                CanAutoApply: true);
        }
        catch (Exception ex)
        {
            Trace.WriteLine($"[UpdateCheck] Velopack 檢查失敗：{ex.Message}");
            return null;
        }
    }

    public async Task DownloadAsync(IProgress<int>? progress = null, CancellationToken ct = default)
    {
        if (_manager is null || _pending is null)
            throw new InvalidOperationException("未偵測到待套用的更新，請先呼叫 CheckAsync。");

        await _manager.DownloadUpdatesAsync(_pending, p => progress?.Report(p), cancelToken: ct).ConfigureAwait(false);
    }

    public void ApplyAndRestart()
    {
        if (_manager is null || _pending is null)
            throw new InvalidOperationException("未偵測到待套用的更新。");

        _manager.ApplyUpdatesAndRestart(_pending.TargetFullRelease);
    }

    /// <summary>lazy 建立 UpdateManager；非 Velopack 環境建構失敗回 null（走 fallback）</summary>
    private UpdateManager? GetManagerOrNull(string? token)
    {
        if (_manager is not null) return _manager;
        try
        {
            var source = new GithubSource(RepoUrl,
                accessToken: string.IsNullOrWhiteSpace(token) ? null : token,
                prerelease: false);
            _manager = new UpdateManager(source);
            return _manager;
        }
        catch (Exception ex)
        {
            Trace.WriteLine($"[UpdateCheck] Velopack 初始化失敗：{ex.Message}");
            return null;
        }
    }
}
