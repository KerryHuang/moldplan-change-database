using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IUsageReportService
{
    Task<UsageReportData> QueryAllAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null);
    Task ExportToExcelAsync(string path, UsageReportData data);
}
