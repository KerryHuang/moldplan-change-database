using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IUsageReportService
{
    Task<UsageReportData> QueryAllAsync(IProgress<string>? progress = null);
    Task ExportToExcelAsync(string path, UsageReportData data);
}
