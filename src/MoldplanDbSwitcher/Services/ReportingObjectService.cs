using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ReportingObjectService : IReportingObjectService
{
    private static readonly HashSet<string> SummaryTables = new(StringComparer.OrdinalIgnoreCase)
    {
        "MoldCostSummary", "MoldPartCostSummary", "MoldPartProcessCostSummary"
    };
    private static readonly HashSet<string> SystemTables = new(StringComparer.OrdinalIgnoreCase)
    {
        "RefreshLog"
    };

    private readonly string _connectionString;
    public ReportingObjectService(string connectionString) { _connectionString = connectionString; }

    public async Task<bool> SchemaExistsAsync(CancellationToken ct = default)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT CASE WHEN SCHEMA_ID('Reporting') IS NOT NULL THEN 1 ELSE 0 END";
        var r = await cmd.ExecuteScalarAsync(ct);
        return Convert.ToInt32(r) == 1;
    }

    public Task<IReadOnlyList<ReportingObject>> ListTablesAsync(CancellationToken ct = default) =>
        QueryAsync("SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID('Reporting') ORDER BY name", ClassifyTable, ct);

    public Task<IReadOnlyList<ReportingObject>> ListViewsAsync(CancellationToken ct = default) =>
        QueryAsync("SELECT name FROM sys.views WHERE schema_id = SCHEMA_ID('Reporting') ORDER BY name",
            _ => ReportingObjectKind.View, ct);

    public Task<IReadOnlyList<ReportingObject>> ListProceduresAsync(CancellationToken ct = default) =>
        QueryAsync("SELECT name FROM sys.procedures WHERE schema_id = SCHEMA_ID('Reporting') ORDER BY name",
            _ => ReportingObjectKind.Procedure, ct);

    public async Task<IReadOnlyList<ReportingObject>> ListAllAsync(CancellationToken ct = default)
    {
        var all = new List<ReportingObject>();
        all.AddRange(await ListTablesAsync(ct));
        all.AddRange(await ListViewsAsync(ct));
        all.AddRange(await ListProceduresAsync(ct));
        return all;
    }

    private static ReportingObjectKind ClassifyTable(string name)
    {
        if (SystemTables.Contains(name)) return ReportingObjectKind.SystemTable;
        if (SummaryTables.Contains(name)) return ReportingObjectKind.SummaryTable;
        return ReportingObjectKind.BaseTable;
    }

    private async Task<IReadOnlyList<ReportingObject>> QueryAsync(
        string sql, Func<string, ReportingObjectKind> classify, CancellationToken ct)
    {
        var list = new List<ReportingObject>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            var name = reader.GetString(0);
            list.Add(new ReportingObject("Reporting", name, classify(name), null));
        }
        return list;
    }

    private static void EnsureValidIdentifier(string name)
    {
        if (string.IsNullOrWhiteSpace(name) ||
            !name.All(c => char.IsLetterOrDigit(c) || c == '_'))
            throw new ArgumentException($"無效的物件名稱: {name}", nameof(name));
    }

    public async Task<IReadOnlyList<ReportingColumn>> GetColumnsAsync(string objectName, CancellationToken ct = default)
    {
        EnsureValidIdentifier(objectName);
        var list = new List<ReportingColumn>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            SELECT c.name, TYPE_NAME(c.user_type_id) +
                CASE WHEN c.max_length > 0 AND TYPE_NAME(c.user_type_id) IN ('varchar','nvarchar','char','nchar')
                     THEN '(' + CAST(c.max_length AS VARCHAR) + ')' ELSE '' END,
                c.is_nullable,
                CAST(ep.value AS NVARCHAR(MAX))
            FROM sys.columns c
            LEFT JOIN sys.extended_properties ep
                ON ep.major_id = c.object_id AND ep.minor_id = c.column_id AND ep.name = 'MS_Description'
            WHERE c.object_id = OBJECT_ID(@obj)
            ORDER BY c.column_id;";
        cmd.Parameters.AddWithValue("@obj", $"Reporting.{objectName}");
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            list.Add(new ReportingColumn(
                reader.GetString(0), reader.GetString(1), reader.GetBoolean(2),
                reader.IsDBNull(3) ? null : reader.GetString(3)));
        return list;
    }

    public async Task<IReadOnlyList<RefreshLogEntry>> GetRefreshLogAsync(string tableName, int top = 5, CancellationToken ct = default)
    {
        EnsureValidIdentifier(tableName);
        var list = new List<RefreshLogEntry>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        if (!await TableExistsAsync(conn, "RefreshLog", ct)) return list;
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            SELECT TOP (@top) StartTime, EndTime, Status, RowCount, ErrorMessage
            FROM Reporting.RefreshLog
            WHERE TableName = @t
            ORDER BY StartTime DESC;";
        cmd.Parameters.AddWithValue("@top", top);
        cmd.Parameters.AddWithValue("@t", tableName);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            list.Add(new RefreshLogEntry(
                reader.GetDateTime(0),
                reader.IsDBNull(1) ? null : reader.GetDateTime(1),
                reader.GetString(2),
                reader.IsDBNull(3) ? null : reader.GetInt32(3),
                reader.IsDBNull(4) ? null : reader.GetString(4)));
        return list;
    }

    private static async Task<bool> TableExistsAsync(SqlConnection conn, string name, CancellationToken ct)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT CASE WHEN OBJECT_ID('Reporting.' + @n, 'U') IS NOT NULL THEN 1 ELSE 0 END";
        cmd.Parameters.AddWithValue("@n", name);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(ct)) == 1;
    }
}
