using Microsoft.Data.SqlClient;

namespace MoldplanDbSwitcher.Services;

public class ReportingQueryService : IReportingQueryService
{
    public const int MaxTopN = 10000;
    private readonly string _connectionString;

    public ReportingQueryService(string connectionString) { _connectionString = connectionString; }

    public async Task<QueryResult> QueryTopNAsync(string objectName, int top, string? where, string? orderBy, CancellationToken ct = default)
    {
        EnsureValidIdentifier(objectName);
        if (top <= 0 || top > MaxTopN)
            throw new ArgumentOutOfRangeException(nameof(top), $"top 必須介於 1 與 {MaxTopN}");
        EnsureSafeClause(where, "WHERE");
        EnsureSafeClause(orderBy, "ORDER BY");

        var sql = $"SELECT TOP ({top}) * FROM [Reporting].[{objectName}]";
        if (!string.IsNullOrWhiteSpace(where)) sql += " WHERE " + where;
        if (!string.IsNullOrWhiteSpace(orderBy)) sql += " ORDER BY " + orderBy;

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        cmd.CommandTimeout = 60;
        await using var reader = await cmd.ExecuteReaderAsync(ct);

        var cols = Enumerable.Range(0, reader.FieldCount).Select(reader.GetName).ToList();
        var rows = new List<IReadOnlyList<object?>>();
        while (await reader.ReadAsync(ct))
        {
            var row = new object?[reader.FieldCount];
            for (var i = 0; i < reader.FieldCount; i++)
                row[i] = reader.IsDBNull(i) ? null : reader.GetValue(i);
            rows.Add(row);
        }
        return new QueryResult(cols, rows);
    }

    private static void EnsureValidIdentifier(string name)
    {
        if (string.IsNullOrWhiteSpace(name) || !name.All(c => char.IsLetterOrDigit(c) || c == '_'))
            throw new ArgumentException($"無效的物件名稱: {name}", nameof(name));
    }

    private static void EnsureSafeClause(string? clause, string label)
    {
        if (string.IsNullOrWhiteSpace(clause)) return;
        if (clause.Contains(';') || clause.Contains("--") || clause.Contains("/*"))
            throw new ArgumentException($"{label} 子句包含不允許的字元（; -- /*）");
    }
}
