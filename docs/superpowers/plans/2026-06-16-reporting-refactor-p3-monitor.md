# Reporting 重構 P3：監控儀表板 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 新增「Reporting 監控」MDI 文件：儀表板式呈現全部 SQL Agent Job 狀態 + 各寬表 RefreshLog，含狀態彙總卡與自動刷新（預設 30 秒），並可手動觸發 Reporting 兩個刷新 Job。

**Architecture:** 新增 `IJobMonitorService`（查 msdb 全部 Agent Job + 目標報表庫的 `Reporting.RefreshLog` + 觸發指定 Reporting Job）。新增 `MonitoringDocumentViewModel : DocumentViewModel`（狀態彙總 + 兩個 DataGrid + 手動/自動刷新指令），auto-refresh 計時器放在 View code-behind（`DispatcherTimer`）以保持 VM 可單元測試。比照 P1 的文件 + DI + 選單路由模式接入 shell。

**Tech Stack:** .NET 9、Avalonia 11.3、CommunityToolkit.Mvvm、Microsoft.Data.SqlClient、xUnit + NSubstitute。

> 對應 spec：`docs/superpowers/specs/2026-06-16-reporting-refactor-design.md`（區塊 C）。前置：P1（DocumentViewModel/IActiveConnectionService/shell）、P2（部署）已完成。
> **環境提醒：** pre-commit hook 會 build + 測試；App 執行中會鎖 `MoldplanDbSwitcher.exe`（`MSB3027/MSB3021`）→ commit 前先關 App。

---

## 設計決策（spec 區塊 C 框架內）

1. **Job 範圍＝全部 Agent Job**（使用者已確認）：查 `msdb.dbo.sysjobs` 全部，欄位對齊截圖（名稱、狀態啟用/停用、上次執行時間、上次結果、下次排程時間、上次耗時）。
2. **唯讀為主**：第一版只「手動觸發 Reporting Daily/Hourly Job」兩個動作；不開放任意 Job 啟用/停用/刪除。`TriggerJobAsync` 以白名單限定 `Reporting_DailyRefresh_MoldPlan` / `Reporting_HourlyRefresh_MoldPlan`。
3. **RefreshLog**：查目標報表庫 `Reporting.RefreshLog`（最近 N 筆：StartedAt/DurationMs/RowsAffected/Status/ErrorMessage）。重用既有 `RefreshLogEntry` record。
4. **自動刷新**：VM 暴露 `RefreshCommand`、`AutoRefreshEnabled`、`RefreshIntervalSeconds`（預設 30）。實際計時器在 View code-behind（`DispatcherTimer`），文件關閉/卸載時停止。VM 不持有計時器（保持可測）。
5. **連線**：監控查 msdb 與目標報表庫，沿用文件的 `UseConnectionAsync(ActiveConnection)`；Job 查 msdb 用連線字串（InitialCatalog 不影響 msdb 三段式查詢），RefreshLog 查 `ActiveConnection` 指向的庫（或部署的目標報表庫）。本版 RefreshLog 查「目前連線的 DB」（即 `ActiveConnection.Database`）。

---

## File Structure

新增：
- `src/MoldplanDbSwitcher/Models/AgentJobStatus.cs`
- `src/MoldplanDbSwitcher/Models/MonitorSummary.cs`
- `src/MoldplanDbSwitcher/Services/IJobMonitorService.cs` + `JobMonitorService.cs`
- `src/MoldplanDbSwitcher/ViewModels/Documents/MonitoringDocumentViewModel.cs`
- `src/MoldplanDbSwitcher/Views/Documents/MonitoringDocumentView.axaml` + `.axaml.cs`
- 對應測試

修改：
- `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`（`OpenReportingMonitorCommand`）
- `src/MoldplanDbSwitcher/Views/MainWindow.axaml`（選單項 + DataTemplate 路由）
- `src/MoldplanDbSwitcher/Program.cs`（DI：JobMonitorService 工廠 + 文件 transient + Func 工廠）

---

## Task 1：AgentJobStatus 與 MonitorSummary 模型

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/AgentJobStatus.cs`
- Create: `src/MoldplanDbSwitcher/Models/MonitorSummary.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Models/MonitorSummaryTests.cs`

- [ ] **Step 1: 失敗測試（彙總計算）**

```csharp
using System;
using System.Collections.Generic;
using MoldplanDbSwitcher.Models;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Models;

public class MonitorSummaryTests
{
    private static AgentJobStatus Job(string name, bool enabled, string outcome) =>
        new(name, enabled, null, outcome, null, null);

    [Fact]
    public void FromJobs_CountsSucceededFailedDisabled()
    {
        var jobs = new List<AgentJobStatus>
        {
            Job("A", true, "成功"),
            Job("B", true, "失敗"),
            Job("C", false, "成功"),
        };
        var s = MonitorSummary.FromJobs(jobs);
        Assert.Equal(2, s.SucceededCount);   // A, C (last outcome 成功)
        Assert.Equal(1, s.FailedCount);      // B
        Assert.Equal(1, s.DisabledCount);    // C
        Assert.Equal(3, s.TotalJobs);
    }

    [Fact]
    public void FromJobs_Empty_AllZero()
    {
        var s = MonitorSummary.FromJobs(new List<AgentJobStatus>());
        Assert.Equal(0, s.TotalJobs);
        Assert.Equal(0, s.FailedCount);
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MonitorSummaryTests"`
Expected: 編譯失敗（型別不存在）。

- [ ] **Step 3: 建立模型**

`src/MoldplanDbSwitcher/Models/AgentJobStatus.cs`：
```csharp
using System;

namespace MoldplanDbSwitcher.Models;

/// <summary>一個 SQL Server Agent Job 的狀態快照（對齊監控頁欄位）。</summary>
public record AgentJobStatus(
    string JobName,
    bool Enabled,
    DateTime? LastRunTime,
    string LastRunOutcome,   // 成功 / 失敗 / 重試 / 取消 / 未執行
    DateTime? NextRunTime,
    int? LastDurationSeconds);
```

`src/MoldplanDbSwitcher/Models/MonitorSummary.cs`：
```csharp
using System.Collections.Generic;
using System.Linq;

namespace MoldplanDbSwitcher.Models;

/// <summary>監控頁頂部狀態彙總卡的計數。</summary>
public record MonitorSummary(int TotalJobs, int SucceededCount, int FailedCount, int DisabledCount)
{
    public static MonitorSummary FromJobs(IReadOnlyList<AgentJobStatus> jobs) => new(
        TotalJobs: jobs.Count,
        SucceededCount: jobs.Count(j => j.LastRunOutcome == "成功"),
        FailedCount: jobs.Count(j => j.LastRunOutcome == "失敗"),
        DisabledCount: jobs.Count(j => !j.Enabled));
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MonitorSummaryTests"`
Expected: PASS（2 筆）。

- [ ] **Step 5: commit**

```bash
git add src/MoldplanDbSwitcher/Models/AgentJobStatus.cs src/MoldplanDbSwitcher/Models/MonitorSummary.cs tests/MoldplanDbSwitcher.Tests/Models/MonitorSummaryTests.cs
git commit -m "feat: 新增 AgentJobStatus 與 MonitorSummary 監控模型"
```

---

## Task 2：IJobMonitorService 與 JobMonitorService

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IJobMonitorService.cs`
- Create: `src/MoldplanDbSwitcher/Services/JobMonitorService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/JobMonitorServiceTests.cs`

說明：`ListJobsAsync` 查 msdb 全部 Job；`GetRefreshLogAsync` 查目標庫 `Reporting.RefreshLog`；`TriggerJobAsync` 白名單觸發。msdb 在 LocalDB 存在（`sysjobs` 等表存在，內容為空），故 `ListJobsAsync` 可整合測試（回空清單、不報錯）。`TriggerJobAsync` 白名單守衛純單元可測。

- [ ] **Step 0: 讀現況**

讀 `src/MoldplanDbSwitcher/Services/ReportingObjectService.cs` 的 `GetRefreshLogAsync`（第 125 行起）了解既有 RefreshLog 查詢與 `RefreshLogEntry` 對應、識別符防呆方式、連線開法（`Microsoft.Data.SqlClient`，`new SqlConnection(connStr)`）。讀 `D:/Repos/MoldPlan-Workspace/docs/scripts/Reporting/99_Reporting_Monitor.sql`（已內嵌於 `src/.../Scripts/Reporting/99_*.sql`）作為 Job/RefreshLog 查詢參考。

- [ ] **Step 1: 失敗測試**

```csharp
using System.Threading.Tasks;
using MoldplanDbSwitcher.Services;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class JobMonitorServiceTests
{
    // LocalDB 連線字串：沿用本測試專案既有 fixture 的取得方式（見其他 *ServiceTests / LocalDbFixture）。
    private static string LocalDbConnString() => MoldplanDbSwitcher.Tests.LocalDbFixture.ConnectionString;

    [Fact]
    public async Task ListJobsAsync_AgainstMsdb_ReturnsListWithoutError()
    {
        var svc = new JobMonitorService(LocalDbConnString());
        var jobs = await svc.ListJobsAsync();
        Assert.NotNull(jobs);   // LocalDB 通常無 Agent Job → 空清單；重點是查詢不報錯
    }

    [Theory]
    [InlineData("DROP TABLE x")]
    [InlineData("SomeOtherJob")]
    [InlineData("Reporting_DailyRefresh_MoldPlan; DROP")]
    public async Task TriggerJobAsync_NonWhitelistedName_Throws(string name)
    {
        var svc = new JobMonitorService(LocalDbConnString());
        await Assert.ThrowsAsync<System.InvalidOperationException>(() => svc.TriggerJobAsync(name));
    }
}
```
> 若本測試專案沒有 `LocalDbFixture.ConnectionString` 公開取得方式，改用其他 Service 測試（如 `ReportingObjectServiceTests`）取得連線字串的同一手法；`ListJobsAsync` 測試可標記為與既有整合測試相同的 trait/collection。若 LocalDB 在 CI 不可用，將 `ListJobsAsync` 測試對齊既有整合測試的略過策略。

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "JobMonitorServiceTests"`
Expected: FAIL（型別不存在）。

- [ ] **Step 3: 介面**

`src/MoldplanDbSwitcher/Services/IJobMonitorService.cs`：
```csharp
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IJobMonitorService
{
    /// <summary>查 msdb 全部 Agent Job 狀態。</summary>
    Task<IReadOnlyList<AgentJobStatus>> ListJobsAsync(CancellationToken ct = default);
    /// <summary>查目標庫 Reporting.RefreshLog 最近 top 筆。</summary>
    Task<IReadOnlyList<RefreshLogEntry>> GetRefreshLogAsync(int top = 50, CancellationToken ct = default);
    /// <summary>觸發指定 Reporting 刷新 Job（白名單外拋例外）。</summary>
    Task TriggerJobAsync(string jobName, CancellationToken ct = default);
}
```

- [ ] **Step 4: 實作**

`src/MoldplanDbSwitcher/Services/JobMonitorService.cs`：
```csharp
using System;
using System.Collections.Generic;
using System.Linq;
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
        // sysjobs（全部 Job）＋ sysjobservers（上次結果/時間）＋ sysjobschedules/sysschedules 之下次執行時間。
        // run_date(int yyyymmdd)+run_time(int hhmmss) → datetime；next_run 同理。
        const string sql = @"
SELECT j.name AS JobName,
       j.enabled AS Enabled,
       js.last_run_date AS LastRunDate,
       js.last_run_time AS LastRunTime,
       js.last_run_outcome AS LastOutcome,
       js.last_run_duration AS LastDuration,
       sch.next_run_date AS NextRunDate,
       sch.next_run_time AS NextRunTime
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobservers js ON js.job_id = j.job_id
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
        // 表不存在則回空（避免未部署時報錯）
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
        await using var cmd = new SqlCommand("msdb.dbo.sp_start_job", conn) { CommandType = System.Data.CommandType.StoredProcedure };
        cmd.Parameters.AddWithValue("@job_name", jobName);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    private static int? AsInt(object o) => o is DBNull ? null : Convert.ToInt32(o);

    // run_date=yyyymmdd, run_time=hhmmss（皆為 int）。0 或 null → null。
    private static DateTime? ToDateTime(int? date, int? time)
    {
        if (date is null or 0) return null;
        var d = date.Value; var t = time ?? 0;
        try
        {
            return new DateTime(d / 10000, d / 100 % 100, d % 100, t / 10000, t / 100 % 100, t % 100);
        }
        catch { return null; }
    }

    // sysjobservers.last_run_duration 為 HHMMSS 格式 int → 秒
    private static int DurationToSeconds(int hhmmss) =>
        (hhmmss / 10000) * 3600 + (hhmmss / 100 % 100) * 60 + hhmmss % 100;

    private static string OutcomeText(int? outcome) => outcome switch
    {
        1 => "成功",
        0 => "失敗",
        3 => "取消",
        2 => "重試",
        _ => "未執行",
    };
}
```
> ⚠ msdb 系統表欄位語意（特別是 `sysjobservers.last_run_date/time/outcome/duration` 與 `sysjobschedules.next_run_date/time`）請對照實際 SQL Server 文件/環境驗證；若 LocalDB 的 msdb 缺某些欄位或回傳格式不同，調整對應。日期/時間 int 解碼的邊界（0 表示「未執行/未排程」）已處理為 null。

- [ ] **Step 5: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "JobMonitorServiceTests"`
Expected: PASS（白名單測試必過；`ListJobsAsync` 若 LocalDB 可用則過，否則對齊既有整合測試略過策略）。

- [ ] **Step 6: commit**

```bash
git add src/MoldplanDbSwitcher/Services/IJobMonitorService.cs src/MoldplanDbSwitcher/Services/JobMonitorService.cs tests/MoldplanDbSwitcher.Tests/Services/JobMonitorServiceTests.cs
git commit -m "feat: 新增 IJobMonitorService（查全部 Agent Job、RefreshLog、白名單觸發）"
```

---

## Task 3：MonitoringDocumentViewModel

**Files:**
- Create: `src/MoldplanDbSwitcher/ViewModels/Documents/MonitoringDocumentViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/MonitoringDocumentViewModelTests.cs`

- [ ] **Step 1: 失敗測試**

```csharp
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels.Documents;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class MonitoringDocumentViewModelTests
{
    private static MonitoringDocumentViewModel Create(IJobMonitorService? monitor = null)
    {
        monitor ??= Substitute.For<IJobMonitorService>();
        monitor.ListJobsAsync(Arg.Any<CancellationToken>()).Returns(new List<AgentJobStatus>());
        monitor.GetRefreshLogAsync(Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(new List<RefreshLogEntry>());
        return new MonitoringDocumentViewModel(_ => monitor, initialConnectionString: "Server=x;Database=d;");
    }

    [Fact]
    public void DocumentType_And_Title()
    {
        var vm = Create();
        Assert.Equal("ReportingMonitor", vm.DocumentType);
        Assert.Equal("Reporting 監控", vm.Title);
        Assert.True(vm.CanClose);
        Assert.Equal(30, vm.RefreshIntervalSeconds);
    }

    [Fact]
    public async Task Refresh_LoadsJobsRefreshLog_AndComputesSummary()
    {
        var monitor = Substitute.For<IJobMonitorService>();
        monitor.ListJobsAsync(Arg.Any<CancellationToken>()).Returns(new List<AgentJobStatus>
        {
            new("A", true, null, "成功", null, null),
            new("B", true, null, "失敗", null, null),
        });
        monitor.GetRefreshLogAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
               .Returns(new List<RefreshLogEntry> { new(System.DateTime.Now, 100, 5, "Success", null) });
        var vm = Create(monitor);

        await vm.RefreshCommand.ExecuteAsync(null);

        Assert.Equal(2, vm.Jobs.Count);
        Assert.Single(vm.RefreshLog);
        Assert.Equal(2, vm.Summary.TotalJobs);
        Assert.Equal(1, vm.Summary.FailedCount);
    }

    [Fact]
    public async Task TriggerDailyJob_CallsServiceWithDailyJobName()
    {
        var monitor = Substitute.For<IJobMonitorService>();
        monitor.ListJobsAsync(Arg.Any<CancellationToken>()).Returns(new List<AgentJobStatus>());
        monitor.GetRefreshLogAsync(Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(new List<RefreshLogEntry>());
        var vm = Create(monitor);

        await vm.TriggerDailyJobCommand.ExecuteAsync(null);

        await monitor.Received().TriggerJobAsync("Reporting_DailyRefresh_MoldPlan", Arg.Any<CancellationToken>());
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MonitoringDocumentViewModelTests"`
Expected: FAIL（型別不存在）。

- [ ] **Step 3: 實作 ViewModel**

`src/MoldplanDbSwitcher/ViewModels/Documents/MonitoringDocumentViewModel.cs`：
```csharp
using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels.Documents;

public partial class MonitoringDocumentViewModel : DocumentViewModel
{
    public const string DailyJobName = "Reporting_DailyRefresh_MoldPlan";
    public const string HourlyJobName = "Reporting_HourlyRefresh_MoldPlan";

    private readonly Func<string, IJobMonitorService> _monitorFactory;
    private IJobMonitorService _monitor;

    public MonitoringDocumentViewModel(Func<string, IJobMonitorService> monitorFactory, string initialConnectionString)
    {
        _monitorFactory = monitorFactory;
        _monitor = monitorFactory(initialConnectionString);
        Title = "Reporting 監控";
    }

    public override string DocumentType => "ReportingMonitor";

    public ObservableCollection<AgentJobStatus> Jobs { get; } = new();
    public ObservableCollection<RefreshLogEntry> RefreshLog { get; } = new();

    [ObservableProperty] private MonitorSummary _summary = new(0, 0, 0, 0);
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _errorMessage;
    [ObservableProperty] private bool _autoRefreshEnabled = true;
    [ObservableProperty] private int _refreshIntervalSeconds = 30;

    public override async Task UseConnectionAsync(ActiveConnection connection)
    {
        _monitor = _monitorFactory(connection.ConnectionString);
        await RefreshAsync();
    }

    [RelayCommand]
    private async Task RefreshAsync()
    {
        try
        {
            IsBusy = true; ErrorMessage = null;
            var jobs = await _monitor.ListJobsAsync();
            Jobs.Clear();
            foreach (var j in jobs) Jobs.Add(j);
            Summary = MonitorSummary.FromJobs(jobs);

            var log = await _monitor.GetRefreshLogAsync();
            RefreshLog.Clear();
            foreach (var e in log) RefreshLog.Add(e);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private Task TriggerDailyJobAsync() => TriggerAsync(DailyJobName);

    [RelayCommand]
    private Task TriggerHourlyJobAsync() => TriggerAsync(HourlyJobName);

    private async Task TriggerAsync(string jobName)
    {
        try
        {
            IsBusy = true; ErrorMessage = null;
            await _monitor.TriggerJobAsync(jobName);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MonitoringDocumentViewModelTests"`
Expected: PASS（3 筆）。

- [ ] **Step 5: commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/Documents/MonitoringDocumentViewModel.cs tests/MoldplanDbSwitcher.Tests/ViewModels/MonitoringDocumentViewModelTests.cs
git commit -m "feat: 新增 MonitoringDocumentViewModel（彙總 + 刷新 + 觸發 Job）"
```

---

## Task 4：MonitoringDocumentView（含自動刷新計時器）

**Files:**
- Create: `src/MoldplanDbSwitcher/Views/Documents/MonitoringDocumentView.axaml`
- Create: `src/MoldplanDbSwitcher/Views/Documents/MonitoringDocumentView.axaml.cs`

- [ ] **Step 1: AXAML**

`MonitoringDocumentView.axaml`：
```xml
<UserControl xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:vm="using:MoldplanDbSwitcher.ViewModels.Documents"
             x:Class="MoldplanDbSwitcher.Views.Documents.MonitoringDocumentView"
             x:DataType="vm:MonitoringDocumentViewModel">
  <DockPanel Margin="8">
    <!-- 工具列 -->
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Spacing="8" Margin="0,0,0,8">
      <Button Content="重新整理" Command="{Binding RefreshCommand}" IsEnabled="{Binding !IsBusy}" />
      <CheckBox Content="自動刷新" IsChecked="{Binding AutoRefreshEnabled}" VerticalAlignment="Center" />
      <TextBlock Text="間隔(秒)：" VerticalAlignment="Center" />
      <NumericUpDown Value="{Binding RefreshIntervalSeconds}" Minimum="5" Maximum="3600" Width="110" />
      <Button Content="觸發 Daily Job" Command="{Binding TriggerDailyJobCommand}" IsEnabled="{Binding !IsBusy}" />
      <Button Content="觸發 Hourly Job" Command="{Binding TriggerHourlyJobCommand}" IsEnabled="{Binding !IsBusy}" />
    </StackPanel>
    <!-- 狀態彙總卡 -->
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Spacing="16" Margin="0,0,0,8">
      <TextBlock Text="{Binding Summary.TotalJobs, StringFormat='Job 總數：{0}'}" />
      <TextBlock Text="{Binding Summary.SucceededCount, StringFormat='成功：{0}'}" Foreground="Green" />
      <TextBlock Text="{Binding Summary.FailedCount, StringFormat='失敗：{0}'}" Foreground="Crimson" />
      <TextBlock Text="{Binding Summary.DisabledCount, StringFormat='停用：{0}'}" Foreground="Gray" />
    </StackPanel>
    <TextBlock DockPanel.Dock="Bottom" Text="{Binding ErrorMessage}" Foreground="Crimson"
               IsVisible="{Binding ErrorMessage, Converter={x:Static StringConverters.IsNotNullOrEmpty}}" />
    <!-- 上：Job 清單；下：RefreshLog -->
    <Grid RowDefinitions="*,8,*">
      <DataGrid Grid.Row="0" ItemsSource="{Binding Jobs}" IsReadOnly="True" AutoGenerateColumns="False"
                GridLinesVisibility="Horizontal">
        <DataGrid.Columns>
          <DataGridTextColumn Header="Job 名稱" Binding="{Binding JobName}" Width="*" />
          <DataGridTextColumn Header="狀態" Width="80"
                              Binding="{Binding Enabled, Converter={x:Static BoolConverters.Not}, ConverterParameter=停用}" />
          <DataGridTextColumn Header="上次執行時間" Binding="{Binding LastRunTime}" Width="160" />
          <DataGridTextColumn Header="上次結果" Binding="{Binding LastRunOutcome}" Width="90" />
          <DataGridTextColumn Header="下次排程時間" Binding="{Binding NextRunTime}" Width="160" />
          <DataGridTextColumn Header="耗時(秒)" Binding="{Binding LastDurationSeconds}" Width="90" />
        </DataGrid.Columns>
      </DataGrid>
      <GridSplitter Grid.Row="1" Height="6" HorizontalAlignment="Stretch" />
      <DataGrid Grid.Row="2" ItemsSource="{Binding RefreshLog}" IsReadOnly="True" AutoGenerateColumns="True" />
    </Grid>
  </DockPanel>
</UserControl>
```
> 「狀態」欄用 BoolConverters.Not + ConverterParameter 顯示「停用」當 Enabled=false——若該 converter 不支援字串參數則改為簡單顯示 Enabled（true/false）或在 VM 補一個 `EnabledText` 屬性。建置若報 binding 問題即改用後者（在 AgentJobStatus 加 `public string StatusText => Enabled ? "啟用" : "停用";`）。

- [ ] **Step 2: code-behind（DispatcherTimer 自動刷新）**

`MonitoringDocumentView.axaml.cs`：
```csharp
using System;
using Avalonia.Controls;
using Avalonia.Threading;
using MoldplanDbSwitcher.ViewModels.Documents;

namespace MoldplanDbSwitcher.Views.Documents;

public partial class MonitoringDocumentView : UserControl
{
    private readonly DispatcherTimer _timer;

    public MonitoringDocumentView()
    {
        InitializeComponent();
        _timer = new DispatcherTimer();
        _timer.Tick += OnTick;
        AttachedToVisualTree += (_, _) => StartTimer();
        DetachedFromVisualTree += (_, _) => _timer.Stop();
        Loaded += async (_, _) => { if (DataContext is MonitoringDocumentViewModel vm) await vm.RefreshCommand.ExecuteAsync(null); };
    }

    private void StartTimer()
    {
        if (DataContext is not MonitoringDocumentViewModel vm) return;
        _timer.Interval = TimeSpan.FromSeconds(Math.Max(5, vm.RefreshIntervalSeconds));
        _timer.Start();
    }

    private void OnTick(object? sender, EventArgs e)
    {
        if (DataContext is not MonitoringDocumentViewModel vm) { _timer.Stop(); return; }
        if (!vm.AutoRefreshEnabled || vm.IsBusy) return;
        _timer.Interval = TimeSpan.FromSeconds(Math.Max(5, vm.RefreshIntervalSeconds));
        _ = vm.RefreshCommand.ExecuteAsync(null);
    }
}
```
> 自動刷新計時器只存在於 View（UI 關注點），文件卸載即停止；VM 維持無計時器、可單元測試。

- [ ] **Step 3: build（驗證 compiled bindings）**

Run: `dotnet build src/MoldplanDbSwitcher/`
Expected: 0 error（3 個既有 AVLN3001 OK）。修正任何 binding 錯誤（如「狀態」欄 converter 問題依 Step 1 備註改 `StatusText`）。

- [ ] **Step 4: commit**

```bash
git add src/MoldplanDbSwitcher/Views/Documents/MonitoringDocumentView.axaml src/MoldplanDbSwitcher/Views/Documents/MonitoringDocumentView.axaml.cs
git commit -m "feat: 新增 MonitoringDocumentView（儀表板 + 自動刷新計時器）"
```

---

## Task 5：接入 shell（選單 + 路由 + DI）

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`
- Modify: `src/MoldplanDbSwitcher/Program.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs`

- [ ] **Step 1: 失敗測試（shell 開啟監控文件）**

於 `MainWindowViewModelTests.cs` 加（沿用該檔建構 shell 的既有方式，並為新工廠提供 `Func<MonitoringDocumentViewModel>`）：
```csharp
[Fact]
public void OpenReportingMonitor_AddsDocument_AndActivates_Singleton()
{
    var vm = Create();   // 沿用既有 shell 測試工廠（見下方 Step 3 對 Create 的調整）
    vm.OpenReportingMonitorCommand.Execute(null);
    vm.OpenReportingMonitorCommand.Execute(null);
    Assert.Equal(1, vm.Documents.Count(d => d.DocumentType == "ReportingMonitor"));
    Assert.Equal("ReportingMonitor", vm.SelectedDocument!.DocumentType);
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MainWindowViewModelTests.OpenReportingMonitor_AddsDocument_AndActivates_Singleton"`
Expected: FAIL（命令/工廠不存在）。

- [ ] **Step 3: MainWindowViewModel 加監控工廠與命令**

於 `MainWindowViewModel.cs`：
1. 建構式新增參數 `Func<MonitoringDocumentViewModel> monitorFactory`，存為欄位 `_monitorFactory`。
2. 加命令：
```csharp
[RelayCommand] private void OpenReportingMonitor() => OpenOrActivate(_monitorFactory);
```
3. 同步更新 `MainWindowViewModelTests` 的 `Create()` 輔助：為新參數提供 `() => <一個用 mock IJobMonitorService 建構的 MonitoringDocumentViewModel>`（mock 的 `ListJobsAsync`/`GetRefreshLogAsync` 回空清單）。

- [ ] **Step 4: MainWindow.axaml 加選單項與路由**

於「報表(_R)」選單，在 Reporting 部署之後加：
```xml
<MenuItem Header="Reporting 監控(_M)" Command="{Binding OpenReportingMonitorCommand}" />
```
於 `ContentControl.DataTemplates` 加路由：
```xml
<DataTemplate DataType="docs:MonitoringDocumentViewModel">
  <dviews:MonitoringDocumentView />
</DataTemplate>
```
（`docs:` = `MoldplanDbSwitcher.ViewModels.Documents`、`dviews:` = `MoldplanDbSwitcher.Views.Documents`，皆已於 MainWindow.axaml 宣告。）

- [ ] **Step 5: Program.cs DI**

```csharp
services.AddTransient<Func<string, IJobMonitorService>>(_ => connStr => new JobMonitorService(connStr));
services.AddTransient<MonitoringDocumentViewModel>(sp =>
{
    var factory = sp.GetRequiredService<ISqlConnectionFactory>();
    var settings = sp.GetRequiredService<ISettingsService>();
    var profile = settings.LoadProfiles().FirstOrDefault();
    var connStr = profile != null ? factory.Create(profile).ConnectionString : "";
    return new MonitoringDocumentViewModel(
        sp.GetRequiredService<Func<string, IJobMonitorService>>(), connStr);
});
services.AddTransient<Func<MonitoringDocumentViewModel>>(sp => () => sp.GetRequiredService<MonitoringDocumentViewModel>());
```
（鏡像 P1/P2 既有 Reporting 文件工廠的註冊風格。）

- [ ] **Step 6: build + 全測試 + 啟動煙霧**

Run: `dotnet build src/MoldplanDbSwitcher/` 然後 `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: 0 error、全綠。
（可選）啟動 App → 報表選單開「Reporting 監控」，確認文件開啟、自動刷新不爆例外（無連線時顯示 ErrorMessage 即可）；測畢關閉 App。

- [ ] **Step 7: commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs src/MoldplanDbSwitcher/Views/MainWindow.axaml src/MoldplanDbSwitcher/Program.cs tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs
git commit -m "feat: shell 接入 Reporting 監控文件（選單 + 路由 + DI）"
```

---

## 完成準則（P3）

- [ ] 報表選單可開「Reporting 監控」文件（singleton），顯示全部 Agent Job + RefreshLog。
- [ ] 頂部狀態彙總卡顯示 Job 總數/成功/失敗/停用。
- [ ] 自動刷新（預設 30 秒、可調、可關），文件關閉即停止。
- [ ] 可手動觸發 Reporting Daily/Hourly Job；非白名單 Job 名稱被拒。
- [ ] 連線切換經 `IActiveConnectionService` 傳播後監控自動重查。
- [ ] 全測試綠；UI 文字繁體中文（Law 1）。

> 下一步：P4（查詢微調：`SELECT` 投影選定欄位取代 `SELECT *`）。
