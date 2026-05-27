using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ReportingDeployService : IReportingDeployService
{
    private readonly string _connectionString;
    private readonly IReportingScriptProvider _scripts;
    private readonly ISqlBatchExecutor _executor;

    public ReportingDeployService(string connectionString, IReportingScriptProvider scripts, ISqlBatchExecutor executor)
    {
        _connectionString = connectionString;
        _scripts = scripts;
        _executor = executor;
    }

    public Task<DeployStep> DeploySchemaAsync(IProgress<DeployStep>? p = null, CancellationToken ct = default) =>
        RunFileAsync(1, null, null, p, ct);

    public Task<DeployStep> DeployTablesAsync(IProgress<DeployStep>? p = null, CancellationToken ct = default) =>
        RunFileAsync(2, null, null, p, ct);

    public Task<DeployStep> DeployViewsAsync(IProgress<DeployStep>? p = null, CancellationToken ct = default) =>
        RunFileAsync(3, null, null, p, ct);

    public Task<DeployStep> DeployProceduresAsync(IProgress<DeployStep>? p = null, CancellationToken ct = default) =>
        RunFileAsync(4, null, null, p, ct);

    public Task<DeployStep> DeployJobAsync(int fileNumber, string databaseName, string jobOwner,
        IProgress<DeployStep>? p = null, CancellationToken ct = default) =>
        RunFileAsync(fileNumber, databaseName, jobOwner, p, ct);

    public async Task<DeployStep> DropAllAsync(string confirmDatabaseName, IProgress<DeployStep>? p = null, CancellationToken ct = default)
    {
        var builder = new SqlConnectionStringBuilder(_connectionString);
        if (!string.Equals(confirmDatabaseName, builder.InitialCatalog, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException(
                $"確認名稱「{confirmDatabaseName}」與目標資料庫「{builder.InitialCatalog}」不符，已中止");
        return await RunFileAsync(98, null, null, p, ct);
    }

    private async Task<DeployStep> RunFileAsync(int fileNumber, string? dbName, string? jobOwner,
        IProgress<DeployStep>? progress, CancellationToken ct)
    {
        var script = _scripts.GetScript(fileNumber);
        var sql = dbName != null ? _scripts.RenderJobScript(fileNumber, dbName, jobOwner ?? "sa") : script.Content;
        var step = new DeployStep(script.FileName, $"執行 {script.FileName}", DeployStatus.Running, null);
        progress?.Report(step);

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        var results = await _executor.ExecuteAsync(conn, sql, null, ct);
        var failed = results.FirstOrDefault(r => !r.Success);
        var final = failed == null
            ? step with { Status = DeployStatus.Success }
            : step with { Status = DeployStatus.Failed, Error = failed.Error };
        progress?.Report(final);
        return final;
    }
}
