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

        var parameters = new List<(string name, object? value)>();
        var whereClause = BuildWhereClauseAndOnly(filters, parameters);

        var sql = $"SELECT TOP ({top}) * FROM [Reporting].[{objectName}]";
        if (!string.IsNullOrEmpty(whereClause)) sql += " WHERE " + whereClause;
        if (!string.IsNullOrWhiteSpace(orderBy)) sql += " ORDER BY " + orderBy;

        return await ExecuteQueryAsync(sql, parameters, ct);
    }

    public async Task<QueryResult> QueryTopNAsync(string objectName, int top,
        IEnumerable<QueryFilterRow> filters, IEnumerable<QuerySortRow> sorts,
        IEnumerable<string>? columns = null, CancellationToken ct = default)
    {
        EnsureValidIdentifier(objectName);
        if (top <= 0 || top > MaxTopN)
            throw new ArgumentOutOfRangeException(nameof(top), $"top 必須介於 1 與 {MaxTopN}");

        var parameters = new List<(string name, object? value)>();
        var whereClause = BuildWhereClauseWithConnectors(filters, parameters);
        var orderByClause = BuildOrderByClause(sorts);

        var selectList = BuildSelectList(columns);
        var sql = $"SELECT TOP ({top}) {selectList} FROM [Reporting].[{objectName}]";
        if (!string.IsNullOrEmpty(whereClause)) sql += " WHERE " + whereClause;
        if (!string.IsNullOrEmpty(orderByClause)) sql += " ORDER BY " + orderByClause;

        return await ExecuteQueryAsync(sql, parameters, ct);
    }

    private static string BuildSelectList(IEnumerable<string>? columns)
    {
        if (columns == null) return "*";
        var cols = columns.Where(c => !string.IsNullOrWhiteSpace(c)).ToList();
        if (cols.Count == 0) return "*";
        foreach (var c in cols) EnsureValidIdentifier(c);
        return string.Join(", ", cols.Select(c => $"[{c}]"));
    }

    private static string BuildFilterCondition(QueryFilterRow f, List<(string name, object? value)> parameters, ref int paramIdx)
    {
        var colExpr = $"[{f.ColumnName}]";
        switch (f.Operator)
        {
            case FilterOperator.IsNull:    return $"{colExpr} IS NULL";
            case FilterOperator.IsNotNull: return $"{colExpr} IS NOT NULL";
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
                    default: return "";
                }
                parameters.Add((pname, pvalue));
                return $"{colExpr} {op} {pname}";
        }
    }

    // Old AND-only logic (used by the string orderBy overload)
    private static string BuildWhereClauseAndOnly(IEnumerable<QueryFilterRow> filters, List<(string name, object? value)> parameters)
    {
        var parts = new List<string>();
        var paramIdx = 0;
        foreach (var f in filters)
        {
            if (string.IsNullOrWhiteSpace(f.ColumnName)) continue;
            EnsureValidIdentifier(f.ColumnName);
            var cond = BuildFilterCondition(f, parameters, ref paramIdx);
            if (!string.IsNullOrEmpty(cond)) parts.Add(cond);
        }
        return parts.Count > 0 ? string.Join(" AND ", parts) : "";
    }

    // New AND/OR grouping logic
    private static string BuildWhereClauseWithConnectors(IEnumerable<QueryFilterRow> filters, List<(string name, object? value)> parameters)
    {
        var rows = filters.Where(f => !string.IsNullOrWhiteSpace(f.ColumnName)).ToList();
        if (rows.Count == 0) return "";
        foreach (var f in rows) EnsureValidIdentifier(f.ColumnName!);

        // Build condition strings first
        var paramIdx = 0;
        var conditions = rows.Select(f => BuildFilterCondition(f, parameters, ref paramIdx)).ToList();

        // Group by connector: consecutive OR rows form a group with the row before the first OR
        // Algorithm: walk rows[1..n-1]; if connector==Or, append to current group; else push group and start new
        var groups = new List<List<string>>(); // each group is a list of condition strings
        var current = new List<string> { conditions[0] };
        for (var i = 1; i < rows.Count; i++)
        {
            if (rows[i].Connector == FilterConnector.Or)
                current.Add(conditions[i]);
            else
            {
                groups.Add(current);
                current = new List<string> { conditions[i] };
            }
        }
        groups.Add(current);

        var groupExprs = groups.Select(g =>
            g.Count > 1 ? "(" + string.Join(" OR ", g) + ")" : g[0]);
        return string.Join(" AND ", groupExprs);
    }

    private static string BuildOrderByClause(IEnumerable<QuerySortRow> sorts)
    {
        var parts = sorts
            .Where(s => !string.IsNullOrWhiteSpace(s.ColumnName))
            .Select(s =>
            {
                EnsureValidIdentifier(s.ColumnName!);
                var dir = s.Direction == SortDirection.Descending ? "DESC" : "ASC";
                return $"[{s.ColumnName}] {dir}";
            })
            .ToList();
        return parts.Count > 0 ? string.Join(", ", parts) : "";
    }

    private async Task<QueryResult> ExecuteQueryAsync(string sql, List<(string name, object? value)> parameters, CancellationToken ct)
    {
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
