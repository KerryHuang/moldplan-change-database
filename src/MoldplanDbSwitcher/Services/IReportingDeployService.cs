using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IReportingDeployService
{
    Task<DeployStep> DeploySchemaAsync(IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DeployTablesAsync(IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DeployViewsAsync(IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DeployProceduresAsync(IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DeployJobAsync(int fileNumber, string databaseName, string jobOwner, IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DropAllAsync(string confirmDatabaseName, IProgress<DeployStep>? progress = null, CancellationToken ct = default);
}
