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
}
