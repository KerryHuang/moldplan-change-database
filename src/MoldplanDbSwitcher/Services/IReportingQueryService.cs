using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public record QueryResult(
    IReadOnlyList<string> Columns,
    IReadOnlyList<IReadOnlyList<object?>> Rows,
    string ExecutedSql = "",
    string Database = "");

public interface IReportingQueryService
{
    Task<QueryResult> QueryTopNAsync(string objectName, int top, string? where, string? orderBy, CancellationToken ct = default);
    Task<QueryResult> QueryTopNAsync(string objectName, int top, IEnumerable<QueryFilterRow> filters, string? orderBy, CancellationToken ct = default);
    Task<QueryResult> QueryTopNAsync(string objectName, int top, IEnumerable<QueryFilterRow> filters, IEnumerable<QuerySortRow> sorts, IEnumerable<string>? columns = null, CancellationToken ct = default);
}
