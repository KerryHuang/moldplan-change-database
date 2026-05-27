namespace MoldplanDbSwitcher.Services;

public record QueryResult(IReadOnlyList<string> Columns, IReadOnlyList<IReadOnlyList<object?>> Rows);

public interface IReportingQueryService
{
    Task<QueryResult> QueryTopNAsync(string objectName, int top, string? where, string? orderBy, CancellationToken ct = default);
}
