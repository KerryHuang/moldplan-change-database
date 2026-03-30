using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IUsageQueryService
{
    Task<List<UsageEntry>> QueryUsageAsync(ConnectionProfile profile, DateTime startDate, DateTime endDate);
}
