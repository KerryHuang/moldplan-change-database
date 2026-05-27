using Microsoft.Data.SqlClient;

namespace MoldplanDbSwitcher.Services;

public record BatchResult(int BatchIndex, bool Success, string? Error, int? RowsAffected);

public interface ISqlBatchExecutor
{
    Task<IReadOnlyList<BatchResult>> ExecuteAsync(
        SqlConnection connection, string sql, IProgress<BatchResult>? progress = null, CancellationToken ct = default);
}
