using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IReportingObjectService
{
    Task<bool> SchemaExistsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<ReportingObject>> ListTablesAsync(CancellationToken ct = default);
    Task<IReadOnlyList<ReportingObject>> ListViewsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<ReportingObject>> ListProceduresAsync(CancellationToken ct = default);
    Task<IReadOnlyList<ReportingObject>> ListAllAsync(CancellationToken ct = default);
    Task<IReadOnlyList<ReportingColumn>> GetColumnsAsync(string objectName, CancellationToken ct = default);
    Task<IReadOnlyList<RefreshLogEntry>> GetRefreshLogAsync(string tableName, int top = 5, CancellationToken ct = default);
}
