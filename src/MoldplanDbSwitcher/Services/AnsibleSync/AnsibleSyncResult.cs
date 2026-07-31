using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services.AnsibleSync;

/// <summary>同步結果。SkippedEntries 為查不到資料庫名稱、或 server 為空而略過的 customer-env。</summary>
public record AnsibleSyncResult(
    List<ConnectionProfile> Profiles,
    List<string> SkippedEntries);
