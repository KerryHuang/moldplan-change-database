using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

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
        return new QueryResult(cols, rows, sql, conn.Database);
    }

    public async Task<QueryResult> QueryTopNAsync(string objectName, int top,
        IEnumerable<QueryFilterRow> filters, string? orderBy, CancellationToken ct = default)
    {
        EnsureValidIdentifier(objectName);
        if (top <= 0 || top > MaxTopN)
            throw new ArgumentOutOfRangeException(nameof(top), $"top 必須介於 1 與 {MaxTopN}");
        EnsureSafeClause(orderBy, "ORDER BY");

        var whereParts = new List<string>();
        var parameters = new List<(string name, object? value)>();
        var paramIdx = 0;
        foreach (var f in filters)
        {
            if (string.IsNullOrWhiteSpace(f.ColumnName)) continue;
            EnsureValidIdentifier(f.ColumnName);
            var colExpr = $"[{f.ColumnName}]";

            string clause;
            switch (f.Operator)
            {
                case FilterOperator.IsNull:
                    clause = $"{colExpr} IS NULL";
                    break;
                case FilterOperator.IsNotNull:
                    clause = $"{colExpr} IS NOT NULL";
                    break;
                default:
                    var pname = $"@p{paramIdx++}";
                    object? pvalue = f.Value;
                    string op;
                    switch (f.Operator)
                    {
                        case FilterOperator.Equals:         op = "="; break;
                        case FilterOperator.NotEquals:      op = "<>"; break;
                        case FilterOperator.GreaterThan:    op = ">"; break;
                        case FilterOperator.LessThan:       op = "<"; break;
                        case FilterOperator.GreaterOrEqual: op = ">="; break;
                        case FilterOperator.LessOrEqual:    op = "<="; break;
                        case FilterOperator.Contains:       op = "LIKE"; pvalue = $"%{f.Value}%"; break;
                        case FilterOperator.StartsWith:     op = "LIKE"; pvalue = $"{f.Value}%"; break;
                        default: continue;
                    }
                    clause = $"{colExpr} {op} {pname}";
                    parameters.Add((pname, pvalue));
                    break;
            }
            whereParts.Add(clause);
        }

        var sql = $"SELECT TOP ({top}) * FROM [Reporting].[{objectName}]";
        if (whereParts.Count > 0) sql += " WHERE " + string.Join(" AND ", whereParts);
        if (!string.IsNullOrWhiteSpace(orderBy)) sql += " ORDER BY " + orderBy;

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        cmd.CommandTimeout = 60;
        foreach (var (n, v) in parameters)
            cmd.Parameters.AddWithValue(n, v ?? DBNull.Value);

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
        return new QueryResult(cols, rows, sql, conn.Database);
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
