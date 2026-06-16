using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class JobMonitorService : IJobMonitorService
{
    private static readonly HashSet<string> AllowedJobs = new(StringComparer.OrdinalIgnoreCase)
    {
        "Reporting_DailyRefresh_MoldPlan",
        "Reporting_HourlyRefresh_MoldPlan",
    };

    private readonly string _connectionString;
    public JobMonitorService(string connectionString) => _connectionString = connectionString;

    public async Task<IReadOnlyList<AgentJobStatus>> ListJobsAsync(CancellationToken ct = default)
    {
        const string sql = @"
SELECT j.name AS JobName,
       j.enabled AS Enabled,
       js.last_run_date AS LastRunDate,
       js.last_run_time AS LastRunTime,
       js.last_run_outcome AS LastOutcome,
       js.last_run_duration AS LastDuration,
       sch.next_run_date AS NextRunDate,
       sch.next_run_time AS NextRunTime
-- OUTER APPLY 確保多目標伺服器（MSX）環境下每個 Job 僅回傳一筆
FROM msdb.dbo.sysjobs j
OUTER APPLY (
    SELECT TOP 1 jsv.last_run_date, jsv.last_run_time, jsv.last_run_outcome, jsv.last_run_duration
    FROM msdb.dbo.sysjobservers jsv
    WHERE jsv.job_id = j.job_id
) js
OUTER APPLY (
    SELECT TOP 1 jsc.next_run_date, jsc.next_run_time
    FROM msdb.dbo.sysjobschedules jsc
    WHERE jsc.job_id = j.job_id
    ORDER BY jsc.next_run_date, jsc.next_run_time
) sch
ORDER BY j.name;";

        var list = new List<AgentJobStatus>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        await using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 30 };
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            var name = r.GetString(0);
            var enabled = Convert.ToInt32(r["Enabled"]) == 1;
            var lastRun = ToDateTime(AsInt(r["LastRunDate"]), AsInt(r["LastRunTime"]));
            var outcome = OutcomeText(r["LastOutcome"] is DBNull ? (int?)null : Convert.ToInt32(r["LastOutcome"]));
            var nextRun = ToDateTime(AsInt(r["NextRunDate"]), AsInt(r["NextRunTime"]));
            var dur = r["LastDuration"] is DBNull ? (int?)null : DurationToSeconds(Convert.ToInt32(r["LastDuration"]));
            list.Add(new AgentJobStatus(name, enabled, lastRun, outcome, nextRun, dur));
        }
        return list;
    }

    public async Task<IReadOnlyList<RefreshLogEntry>> GetRefreshLogAsync(int top = 50, CancellationToken ct = default)
    {
        if (top is <= 0 or > 1000) top = 50;
        var list = new List<RefreshLogEntry>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        await using (var check = new SqlCommand(
            "SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id WHERE s.name='Reporting' AND t.name='RefreshLog'", conn))
        {
            if (Convert.ToInt32(await check.ExecuteScalarAsync(ct)) == 0) return list;
        }
        var sql = $@"SELECT TOP ({top}) StartedAt, DurationMs, RowsAffected, Status, ErrorMessage
                     FROM Reporting.RefreshLog ORDER BY StartedAt DESC;";
        await using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 30 };
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            list.Add(new RefreshLogEntry(
                r.GetDateTime(0), r.GetInt32(1), r.GetInt32(2), r.GetString(3),
                r[4] is DBNull ? null : r.GetString(4)));
        }
        return list;
    }

    public async Task TriggerJobAsync(string jobName, CancellationToken ct = default)
    {
        if (!AllowedJobs.Contains(jobName))
            throw new InvalidOperationException($"不允許觸發非 Reporting 刷新 Job：{jobName}");
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        await using var cmd = new SqlCommand("msdb.dbo.sp_start_job", conn)
        {
            CommandType = System.Data.CommandType.StoredProcedure,
            CommandTimeout = 10
        };
        cmd.Parameters.AddWithValue("@job_name", jobName);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    private static int? AsInt(object o) => o is DBNull ? null : Convert.ToInt32(o);

    private static DateTime? ToDateTime(int? date, int? time)
    {
        if (date is null or 0) return null;
        var d = date.Value; var t = time ?? 0;
        try { return new DateTime(d / 10000, d / 100 % 100, d % 100, t / 10000, t / 100 % 100, t % 100); }
        catch { return null; }
    }

    private static int DurationToSeconds(int hhmmss) =>
        (hhmmss / 10000) * 3600 + (hhmmss / 100 % 100) * 60 + hhmmss % 100;

    private static string OutcomeText(int? outcome) => outcome switch
    {
        1 => "成功", 0 => "失敗", 3 => "取消", 2 => "重試", _ => "未執行",
    };
}
