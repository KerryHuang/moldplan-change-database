using System.Collections.Generic;
using System.Linq;

namespace MoldplanDbSwitcher.Models;

/// <summary>監控頁頂部狀態彙總卡的計數。</summary>
public record MonitorSummary(int TotalJobs, int SucceededCount, int FailedCount, int DisabledCount)
{
    public static MonitorSummary FromJobs(IReadOnlyList<AgentJobStatus> jobs) => new(
        TotalJobs: jobs.Count,
        SucceededCount: jobs.Count(j => j.LastRunOutcome == "成功"),
        FailedCount: jobs.Count(j => j.LastRunOutcome == "失敗"),
        DisabledCount: jobs.Count(j => !j.Enabled));
}
