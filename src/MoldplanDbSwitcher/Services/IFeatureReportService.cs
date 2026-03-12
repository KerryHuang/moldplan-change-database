using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IFeatureReportService
{
    Task<FeatureReportData> QueryAllCustomerFeaturesAsync(IProgress<string>? progress = null);
    Task ExportToExcelAsync(string path, FeatureReportData data);
}
