namespace MoldplanDbSwitcher.Models;

/// <summary>更新資訊；CanAutoApply 表示可自動下載套用（Velopack 安裝）而非僅通知</summary>
public record UpdateInfo(string LatestVersion, string ReleaseUrl, string ReleaseNotes, bool CanAutoApply = false);
