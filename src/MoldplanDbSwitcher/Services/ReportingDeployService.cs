using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;
using System.Text;

namespace MoldplanDbSwitcher.Services;

public class ReportingDeployService : IReportingDeployService
{
    private static readonly int[] DeploySequence = { 1, 2, 3, 4, 5, 6, 7 };

    private readonly string _connectionString;
    private readonly IReportingScriptProvider _scripts;
    private readonly ISqlBatchExecutor _executor;

    public ReportingDeployService(string connectionString, IReportingScriptProvider scripts, ISqlBatchExecutor executor)
    {
        _connectionString = connectionString;
        _scripts = scripts;
        _executor = executor;
    }

    /// <summary>依序執行全部部署腳本（01–07），首錯即停。</summary>
    /// <remarks>
    /// 註：本方法的逐檔序列與「首錯即停」邏輯未做單元測試——服務內部自行開啟 SqlConnection，
    /// 且 04/05 腳本以三段式跨庫參照來源主庫（LocalDB 無該庫），完整整合測試不可行。
    /// 邏輯為固定序列的 guarded foreach，風險低；VM 層測試涵蓋失敗步驟的呈現。
    /// </remarks>
    public async Task<IReadOnlyList<DeployStep>> DeployAllAsync(
        ReportingDeployParameters parameters,
        IProgress<DeployStep>? progress = null,
        CancellationToken ct = default)
    {
        var results = new List<DeployStep>();

        await using var conn = await OpenMasterConnectionAsync(ct);

        foreach (var fileNumber in DeploySequence)
        {
            var script = _scripts.GetScript(fileNumber);
            var step = new DeployStep(script.FileName, $"執行 {script.FileName}", DeployStatus.Running, null);
            progress?.Report(step);

            var sql = _scripts.Render(fileNumber, parameters);
            var batches = await _executor.ExecuteAsync(conn, sql, null, ct);
            var failed = batches.FirstOrDefault(r => !r.Success);
            var final = failed == null
                ? step with { Status = DeployStatus.Success }
                : step with { Status = DeployStatus.Failed, Error = failed.Error };

            progress?.Report(final);
            results.Add(final);

            // 第一個失敗即停止後續步驟
            if (failed != null)
                break;
        }

        return results;
    }

    public async Task<DeployStep> DeployJobAsync(
        int fileNumber,
        ReportingDeployParameters parameters,
        IProgress<DeployStep>? progress = null,
        CancellationToken ct = default)
    {
        var script = _scripts.GetScript(fileNumber);
        var step = new DeployStep(script.FileName, $"執行 {script.FileName}", DeployStatus.Running, null);
        progress?.Report(step);

        var sql = _scripts.Render(fileNumber, parameters);
        await using var conn = await OpenMasterConnectionAsync(ct);

        var batches = await _executor.ExecuteAsync(conn, sql, null, ct);
        var failed = batches.FirstOrDefault(r => !r.Success);
        var final = failed == null
            ? step with { Status = DeployStatus.Success }
            : step with { Status = DeployStatus.Failed, Error = failed.Error };

        progress?.Report(final);
        return final;
    }

    public async Task<DeployStep> DropAllAsync(
        ReportingDeployParameters parameters,
        string confirmDatabaseName,
        IProgress<DeployStep>? progress = null,
        CancellationToken ct = default)
    {
        if (!string.Equals(confirmDatabaseName, parameters.TargetDatabase, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException(
                $"確認名稱「{confirmDatabaseName}」與目標資料庫「{parameters.TargetDatabase}」不符，已中止");

        var script = _scripts.GetScript(98);
        var step = new DeployStep(script.FileName, $"執行 {script.FileName}", DeployStatus.Running, null);
        progress?.Report(step);

        var sql = _scripts.Render(98, parameters);
        await using var conn = await OpenMasterConnectionAsync(ct);

        var batches = await _executor.ExecuteAsync(conn, sql, null, ct);
        var failed = batches.FirstOrDefault(r => !r.Success);
        var final = failed == null
            ? step with { Status = DeployStatus.Success }
            : step with { Status = DeployStatus.Failed, Error = failed.Error };

        progress?.Report(final);
        return final;
    }

    public async Task<ReportingInstallStatus> ScanInstallStatusAsync(CancellationToken ct = default)
    {
        var targetDb = new SqlConnectionStringBuilder(_connectionString).InitialCatalog;
        // 逸出識別符中的 ']'
        var safeDb = targetDb.Replace("]", "]]");

        await using var conn = await OpenMasterConnectionAsync(ct);

        // 確認目標資料庫存在
        await using var dbCmd = conn.CreateCommand();
        dbCmd.CommandText = "SELECT COUNT(*) FROM sys.databases WHERE name = @db";
        dbCmd.Parameters.AddWithValue("@db", targetDb);
        var dbCount = (int)(await dbCmd.ExecuteScalarAsync(ct))!;

        if (dbCount == 0)
            return new ReportingInstallStatus(false, false, 0, 0, 0);

        // 切換到目標資料庫查詢
        await using var useCmd = conn.CreateCommand();
        useCmd.CommandText = $"USE [{safeDb}]";
        await useCmd.ExecuteNonQueryAsync(ct);

        // 確認 Reporting schema 是否存在
        await using var schemaCmd = conn.CreateCommand();
        schemaCmd.CommandText = "SELECT COUNT(*) FROM sys.schemas WHERE name = 'Reporting'";
        var schemaCount = (int)(await schemaCmd.ExecuteScalarAsync(ct))!;

        if (schemaCount == 0)
            return new ReportingInstallStatus(true, false, 0, 0, 0);

        // 統計資料表、檢視表、預存程序數量（屬於 Reporting schema）
        await using var tableCmd = conn.CreateCommand();
        tableCmd.CommandText = "SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'Reporting'";
        var tableCount = (int)(await tableCmd.ExecuteScalarAsync(ct))!;

        await using var viewCmd = conn.CreateCommand();
        viewCmd.CommandText = "SELECT COUNT(*) FROM sys.views v JOIN sys.schemas s ON v.schema_id = s.schema_id WHERE s.name = 'Reporting'";
        var viewCount = (int)(await viewCmd.ExecuteScalarAsync(ct))!;

        await using var procCmd = conn.CreateCommand();
        procCmd.CommandText = "SELECT COUNT(*) FROM sys.procedures p JOIN sys.schemas s ON p.schema_id = s.schema_id WHERE s.name = 'Reporting'";
        var procCount = (int)(await procCmd.ExecuteScalarAsync(ct))!;

        return new ReportingInstallStatus(true, true, tableCount, viewCount, procCount);
    }

    // 部署/掃描一律連 master：01 需在目標庫尚未存在時建庫，其餘腳本各自 USE 切換 context。
    private async Task<SqlConnection> OpenMasterConnectionAsync(CancellationToken ct)
    {
        var masterCs = new SqlConnectionStringBuilder(_connectionString) { InitialCatalog = "master" }.ConnectionString;
        var conn = new SqlConnection(masterCs);
        await conn.OpenAsync(ct);
        return conn;
    }

    public string GenerateExportSql(ReportingDeployParameters parameters, bool includeDrop = false)
    {
        var sb = new StringBuilder();
        sb.AppendLine("-- =============================================");
        sb.AppendLine($"-- MoldPlan Reporting Deploy Export");
        sb.AppendLine($"-- TargetDatabase : {parameters.TargetDatabase}");
        sb.AppendLine($"-- SourceDatabase : {parameters.SourceDatabase}");
        sb.AppendLine($"-- GeneratedAt    : {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
        sb.AppendLine("-- =============================================");
        sb.AppendLine();

        if (includeDrop)
        {
            AppendScriptBlock(sb, 98, parameters);
        }

        foreach (var n in DeploySequence)
        {
            AppendScriptBlock(sb, n, parameters);
        }

        return sb.ToString();
    }

    private void AppendScriptBlock(StringBuilder sb, int fileNumber, ReportingDeployParameters parameters)
    {
        var script = _scripts.GetScript(fileNumber);
        sb.AppendLine($"-- === {script.FileName} ===");
        sb.AppendLine(_scripts.Render(fileNumber, parameters));
        sb.AppendLine("GO");
        sb.AppendLine();
    }
}
