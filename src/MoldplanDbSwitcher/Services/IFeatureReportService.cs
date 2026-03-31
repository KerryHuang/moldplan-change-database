using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IFeatureReportService
{
    Task<FeatureReportData> QueryAllCustomerFeaturesAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null);
    Task ExportToExcelAsync(string path, FeatureReportData data);
}
