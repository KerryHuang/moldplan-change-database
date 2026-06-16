using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IJobMonitorService
{
    Task<IReadOnlyList<AgentJobStatus>> ListJobsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<RefreshLogEntry>> GetRefreshLogAsync(int top = 50, CancellationToken ct = default);
    Task TriggerJobAsync(string jobName, CancellationToken ct = default);
}
