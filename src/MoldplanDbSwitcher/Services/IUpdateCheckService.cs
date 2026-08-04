using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IUpdateCheckService
{
    Task<UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default);

    /// <summary>下載已偵測到的更新（僅 CanAutoApply 來源支援）</summary>
    Task DownloadAsync(IProgress<int>? progress = null, CancellationToken ct = default);

    /// <summary>套用已下載的更新並重啟（僅 CanAutoApply 來源支援）</summary>
    void ApplyAndRestart();
}
