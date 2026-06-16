using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IReportingDeployService
{
    Task<IReadOnlyList<DeployStep>> DeployAllAsync(ReportingDeployParameters parameters, IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DeployJobAsync(int fileNumber, ReportingDeployParameters parameters, IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DropAllAsync(ReportingDeployParameters parameters, string confirmDatabaseName, IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<ReportingInstallStatus> ScanInstallStatusAsync(CancellationToken ct = default);
    string GenerateExportSql(ReportingDeployParameters parameters, bool includeDrop = false);
}
