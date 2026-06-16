using System;

namespace MoldplanDbSwitcher.Models;

/// <summary>一個 SQL Server Agent Job 的狀態快照（對齊監控頁欄位）。</summary>
public record AgentJobStatus(
    string JobName,
    bool Enabled,
    DateTime? LastRunTime,
    string LastRunOutcome,
    DateTime? NextRunTime,
    int? LastDurationSeconds)
{
    public string StatusText => Enabled ? "啟用" : "停用";
}
