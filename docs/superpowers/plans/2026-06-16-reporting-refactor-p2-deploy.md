# Reporting 重構 P2：部署重構 Implementation Plan

> ⚠ **歷史紀錄（保留作設計過程參考，內文未更新）**。文中關於 Reporting 部署腳本來源的描述（MoldPlanScriptsPath / MOLDPLAN_REPO / `<<CHANGE_ME>>` / 外部資料夾預設 / D:\Repos\MoldPlan-Workspace）已於 v1.4.x 變更：腳本改為**內嵌**、雙占位符 `<<Database>>`/`<<MAINDB>>`、源頭 repo＝`gitlab.com/wdmis/waydosoft.moldplan.docs`。現況請見 README。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 讓 Reporting 部署對齊新的 9 檔雙占位符腳本集（`<<Database>>` 目標報表庫 + `<<MAINDB>>` 來源主庫），腳本內嵌為 EmbeddedResource（可外部覆寫），新增「匯出 SQL」與安裝狀態掃描。

**Architecture:** 把 `D:\Repos\MoldPlan-Workspace\docs\scripts\Reporting` 的 9 個腳本 vendoring 進 repo 並標為 EmbeddedResource。重寫 `IReportingScriptProvider`（預設讀內嵌、可選外部覆寫、渲染雙占位符）與 `ReportingDeployService`（新序列 01→07、master 連線建庫、98 drop、安裝狀態掃描、匯出 SQL）。部署 ViewModel/Page 加入「目標報表庫名 + 來源主庫名」兩個輸入與匯出按鈕。

**Tech Stack:** .NET 9、Avalonia 11.3、CommunityToolkit.Mvvm、Microsoft.Data.SqlClient、xUnit + NSubstitute（既有 LocalDB fixture）。

> 對應 spec：`docs/superpowers/specs/2026-06-16-reporting-refactor-design.md`（區塊 B）。前置：P1 已完成（`DocumentViewModel`、`IActiveConnectionService`、`ActiveConnection`、Reporting 文件化）。
> **環境提醒：** pre-commit hook 會 build + 測試；App 執行中會鎖 `MoldplanDbSwitcher.exe`（`MSB3027/MSB3021`）導致失敗 → commit 前先關 App。指令見 `/dotnet-run` skill。

---

## 關鍵設計決策（本計畫採用，已在 spec 區塊 B 框架內）

1. **檔案重新編號**：新腳本集 `01_…Create_Database`（master）、`02_…Schema`、`03_…Tables`、`04_…Views`（含 `<<MAINDB>>`）、`05_…StoredProcedures`、`06_…DailyRefresh_Job`、`07_…HourlyRefresh_Job`、`98_…Drop_All`、`99_…Monitor`。**部署序列 = 01→07**；drop = 98；99 為監控查詢（P3 用，內嵌但部署不執行）。
2. **連線情境**：腳本各自以 `USE [...]`／`USE msdb` 切換 context（01 在 master 建庫、02–05/98 `USE [<<Database>>]`、06/07 `USE msdb`）。因此部署連線一律以 **`InitialCatalog=master`** 連到「目標庫所在 instance」，讓 01 能在目標庫尚未存在時建庫，其餘腳本靠自身 `USE` 切換。
3. **雙占位符**：`<<Database>>`→目標報表庫、`<<MAINDB>>`→來源主庫；Job 檔 owner 以 regex `@JobOwner\s*=\s*N'[^']*'` 取代。
4. **預設值**：目標報表庫預設 `MoldPlan-Reporting`；來源主庫預設＝目前連線的 DB（`ActiveConnection.Database`）。
5. **內嵌 vs 外部**：預設讀內嵌資源；若設定提供外部覆寫資料夾且存在對應檔則改讀外部（沿用 P1 的「內嵌為預設、可選外部覆寫」決策）。

---

## File Structure

新增：
- `src/MoldplanDbSwitcher/Scripts/Reporting/01_…sql … 99_…sql`（9 檔，EmbeddedResource）
- `src/MoldplanDbSwitcher/Models/ReportingDeployParameters.cs`
- `src/MoldplanDbSwitcher/Models/ReportingInstallStatus.cs`
- 對應測試

修改：
- `src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`（加 EmbeddedResource）
- `src/MoldplanDbSwitcher/Services/IReportingScriptProvider.cs` + `ReportingScriptProvider.cs`（內嵌＋雙占位符）
- `src/MoldplanDbSwitcher/Services/IReportingDeployService.cs` + `ReportingDeployService.cs`（新序列＋master 連線＋掃描＋匯出）
- `src/MoldplanDbSwitcher/ViewModels/ReportingDeployViewModel.cs`（兩輸入＋匯出）
- `src/MoldplanDbSwitcher/Views/ReportingDeployPage.axaml`（兩輸入＋匯出鈕＋跨 instance 提示）
- `src/MoldplanDbSwitcher/Program.cs`（DI 調整）

---

## Task 1：Vendoring 9 個腳本為 EmbeddedResource

**Files:**
- Create: `src/MoldplanDbSwitcher/Scripts/Reporting/{01..07,98,99}_*.sql`（自外部複製）
- Modify: `src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/EmbeddedReportingScriptsTests.cs`

- [ ] **Step 1: 複製腳本進 repo**

把 `D:/Repos/MoldPlan-Workspace/docs/scripts/Reporting/` 下這 9 個 `.sql` 複製到 `src/MoldplanDbSwitcher/Scripts/Reporting/`（保留原檔名）：`01_Reporting_Create_Database.sql`、`02_Reporting_Create_Schema.sql`、`03_Reporting_Create_Tables.sql`、`04_Reporting_Create_Views.sql`、`05_Reporting_Create_StoredProcedures.sql`、`06_Reporting_DailyRefresh_Job.sql`、`07_Reporting_HourlyRefresh_Job.sql`、`98_Reporting_Drop_All.sql`、`99_Reporting_Monitor.sql`。

去除 UTF-8 BOM（README 已載明 BOM 會造成 `Incorrect syntax near '﻿'`）：
```bash
cd "C:/Users/zihao/source/repos/moldplan-change-database/src/MoldplanDbSwitcher/Scripts/Reporting"
perl -i -pe 's/\xEF\xBB\xBF//g' *.sql
```

- [ ] **Step 2: csproj 加 EmbeddedResource**

在 `MoldplanDbSwitcher.csproj` 既有 `<ItemGroup>`（含 AvaloniaResource 那段）附近新增：
```xml
  <ItemGroup>
    <EmbeddedResource Include="Scripts\Reporting\*.sql" />
  </ItemGroup>
```

- [ ] **Step 3: 寫失敗測試**

`tests/MoldplanDbSwitcher.Tests/Services/EmbeddedReportingScriptsTests.cs`：
```csharp
using System.Linq;
using System.Reflection;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class EmbeddedReportingScriptsTests
{
    [Theory]
    [InlineData("01_Reporting_Create_Database.sql")]
    [InlineData("02_Reporting_Create_Schema.sql")]
    [InlineData("03_Reporting_Create_Tables.sql")]
    [InlineData("04_Reporting_Create_Views.sql")]
    [InlineData("05_Reporting_Create_StoredProcedures.sql")]
    [InlineData("06_Reporting_DailyRefresh_Job.sql")]
    [InlineData("07_Reporting_HourlyRefresh_Job.sql")]
    [InlineData("98_Reporting_Drop_All.sql")]
    [InlineData("99_Reporting_Monitor.sql")]
    public void EmbeddedScript_IsPresent_AndNonEmpty(string fileName)
    {
        var asm = typeof(MoldplanDbSwitcher.Services.ReportingScriptProvider).Assembly;
        var name = asm.GetManifestResourceNames()
            .FirstOrDefault(n => n.EndsWith(fileName, System.StringComparison.OrdinalIgnoreCase));
        Assert.NotNull(name);
        using var s = asm.GetManifestResourceStream(name!);
        Assert.NotNull(s);
        using var r = new System.IO.StreamReader(s!);
        var content = r.ReadToEnd();
        Assert.False(string.IsNullOrWhiteSpace(content));
        Assert.False(content.StartsWith('﻿'), "不應含 BOM");
    }
}
```

- [ ] **Step 4: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "EmbeddedReportingScriptsTests"`
Expected: FAIL（資源尚未嵌入或 BOM 未去）。

- [ ] **Step 5: 建置使資源嵌入，再跑測試**

Run: `dotnet build src/MoldplanDbSwitcher/` 然後 `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "EmbeddedReportingScriptsTests"`
Expected: PASS（9 筆）。若 BOM assertion 失敗，回 Step 1 重跑 perl 去 BOM。

- [ ] **Step 6: commit**

```bash
git add src/MoldplanDbSwitcher/Scripts/Reporting/ src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj tests/MoldplanDbSwitcher.Tests/Services/EmbeddedReportingScriptsTests.cs
git commit -m "feat: 內嵌 Reporting 9 個部署腳本為 EmbeddedResource"
```

---

## Task 2：ReportingDeployParameters + 重寫 ScriptProvider（內嵌＋雙占位符）

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/ReportingDeployParameters.cs`
- Modify: `src/MoldplanDbSwitcher/Services/IReportingScriptProvider.cs`
- Modify: `src/MoldplanDbSwitcher/Services/ReportingScriptProvider.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ReportingScriptProviderTests.cs`（既有檔，重寫）

- [ ] **Step 1: 新增參數 record**

`src/MoldplanDbSwitcher/Models/ReportingDeployParameters.cs`：
```csharp
namespace MoldplanDbSwitcher.Models;

/// <summary>部署參數：目標報表庫名（&lt;&lt;Database&gt;&gt;）、來源主庫名（&lt;&lt;MAINDB&gt;&gt;）、Job 擁有者。</summary>
public record ReportingDeployParameters(string TargetDatabase, string SourceDatabase, string JobOwner = "sa");
```

- [ ] **Step 2: 寫失敗測試（重寫既有 ReportingScriptProviderTests.cs）**

先讀內嵌的 `02_…Schema.sql`、`04_…Views.sql`、`06_…DailyRefresh_Job.sql` 確認占位符實際字串（`<<Database>>`、`<<MAINDB>>`、`@JobOwner ... = N'sa'`）。測試：
```csharp
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class ReportingScriptProviderTests
{
    private static ReportingScriptProvider Embedded() => new(externalOverrideDir: null);

    [Fact]
    public void GetScript_Embedded_ReturnsContentByFileNumber()
    {
        var s = Embedded().GetScript(2);   // 02 schema
        Assert.Equal(2, s.FileNumber);
        Assert.Contains("Reporting", s.Content);
    }

    [Fact]
    public void Render_ReplacesBothPlaceholders()
    {
        var p = new ReportingDeployParameters("MoldPlan-Reporting", "gma-staging");
        var sql = Embedded().Render(4, p);   // 04 views 含 <<MAINDB>>
        Assert.DoesNotContain("<<Database>>", sql);
        Assert.DoesNotContain("<<MAINDB>>", sql);
        Assert.Contains("gma-staging", sql);
    }

    [Fact]
    public void Render_JobScript_SubstitutesDatabaseAndOwner()
    {
        var p = new ReportingDeployParameters("MoldPlan-Reporting", "gma-staging", JobOwner: "deployer");
        var sql = Embedded().Render(6, p);   // 06 daily job
        Assert.DoesNotContain("<<Database>>", sql);
        Assert.Contains("MoldPlan-Reporting", sql);
        Assert.Contains("N'deployer'", sql);
    }

    [Fact]
    public void Render_EmptyTarget_Throws()
    {
        Assert.Throws<System.ArgumentException>(() =>
            Embedded().Render(2, new ReportingDeployParameters("", "main")));
    }

    [Fact]
    public void ExternalOverride_WhenFileExists_PrefersExternalContent()
    {
        var dir = System.IO.Path.Combine(System.IO.Path.GetTempPath(), System.IO.Path.GetRandomFileName());
        System.IO.Directory.CreateDirectory(dir);
        try
        {
            System.IO.File.WriteAllText(System.IO.Path.Combine(dir, "02_Override.sql"), "USE [<<Database>>]; -- EXTERNAL");
            var sql = new ReportingScriptProvider(externalOverrideDir: dir)
                .Render(2, new ReportingDeployParameters("DB", "main"));
            Assert.Contains("EXTERNAL", sql);
        }
        finally { System.IO.Directory.Delete(dir, true); }
    }

    [Fact]
    public void ListAvailable_Embedded_ReturnsNineScripts()
    {
        Assert.Equal(9, Embedded().ListAvailable().Count);
    }
}
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingScriptProviderTests"`
Expected: FAIL（`Render`、新建構式不存在）。

- [ ] **Step 4: 重寫介面**

`src/MoldplanDbSwitcher/Services/IReportingScriptProvider.cs`：
```csharp
using System.Collections.Generic;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IReportingScriptProvider
{
    ReportingScript GetScript(int fileNumber);
    IReadOnlyList<ReportingScript> ListAvailable();
    /// <summary>渲染雙占位符；Job 檔（06/07）一併替換 @JobOwner。</summary>
    string Render(int fileNumber, ReportingDeployParameters parameters);
}
```

- [ ] **Step 5: 重寫實作**

`src/MoldplanDbSwitcher/Services/ReportingScriptProvider.cs`：
```csharp
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ReportingScriptProvider : IReportingScriptProvider
{
    private const string EmbeddedPrefix = "MoldplanDbSwitcher.Scripts.Reporting.";
    private readonly string? _externalOverrideDir;
    private static readonly Assembly Asm = typeof(ReportingScriptProvider).Assembly;

    /// <param name="externalOverrideDir">非 null 且該編號檔存在時，改讀外部；否則讀內嵌。</param>
    public ReportingScriptProvider(string? externalOverrideDir)
    {
        _externalOverrideDir = externalOverrideDir;
    }

    public ReportingScript GetScript(int fileNumber)
    {
        var prefix = fileNumber.ToString("D2") + "_";

        if (!string.IsNullOrWhiteSpace(_externalOverrideDir) && Directory.Exists(_externalOverrideDir))
        {
            var ext = Directory.EnumerateFiles(_externalOverrideDir, "*.sql")
                .FirstOrDefault(f => Path.GetFileName(f).StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
            if (ext != null)
                return new ReportingScript(fileNumber, Path.GetFileName(ext), ReadNoBom(File.ReadAllText(ext)));
        }

        var resName = Asm.GetManifestResourceNames()
            .FirstOrDefault(n => n.StartsWith(EmbeddedPrefix + prefix, StringComparison.OrdinalIgnoreCase))
            ?? throw new FileNotFoundException($"找不到編號 {fileNumber:D2} 的內嵌腳本");
        using var s = Asm.GetManifestResourceStream(resName)!;
        using var r = new StreamReader(s);
        var fileName = resName.Substring(EmbeddedPrefix.Length);
        return new ReportingScript(fileNumber, fileName, ReadNoBom(r.ReadToEnd()));
    }

    public string Render(int fileNumber, ReportingDeployParameters p)
    {
        if (string.IsNullOrWhiteSpace(p.TargetDatabase))
            throw new ArgumentException("TargetDatabase 不可為空", nameof(p));
        var content = GetScript(fileNumber).Content
            .Replace("<<Database>>", p.TargetDatabase)
            .Replace("<<MAINDB>>", p.SourceDatabase ?? "");
        // Job 檔 owner：@JobOwner ... = N'sa' → N'{owner}'
        content = Regex.Replace(content, @"@JobOwner(\s*)=(\s*)N'[^']*'", $"@JobOwner$1=$2N'{p.JobOwner}'");
        return content;
    }

    public IReadOnlyList<ReportingScript> ListAvailable()
    {
        var numbers = Asm.GetManifestResourceNames()
            .Where(n => n.StartsWith(EmbeddedPrefix, StringComparison.OrdinalIgnoreCase) && n.EndsWith(".sql"))
            .Select(n => n.Substring(EmbeddedPrefix.Length))
            .Where(f => f.Length >= 3 && char.IsDigit(f[0]) && char.IsDigit(f[1]) && f[2] == '_')
            .Select(f => int.Parse(f.Substring(0, 2)))
            .Distinct().OrderBy(x => x);
        return numbers.Select(GetScript).ToList();
    }

    private static string ReadNoBom(string s) => s.StartsWith('﻿') ? s.Substring(1) : s;
}
```
> 讀 04/06 確認 `@JobOwner` 的實際空白格式；上方 regex 對 `@JobOwner         = N'sa'`（多空白）也可正確匹配。若 02–05 的 `USE [<<Database>>]` 與 06/07 的 `@DatabaseName = N'<<Database>>'` 都靠 `<<Database>>` 取代，則無需特別處理 `@DatabaseName`。

- [ ] **Step 6: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingScriptProviderTests"`
Expected: PASS（6 筆）。

- [ ] **Step 7: commit**

```bash
git add src/MoldplanDbSwitcher/Models/ReportingDeployParameters.cs src/MoldplanDbSwitcher/Services/IReportingScriptProvider.cs src/MoldplanDbSwitcher/Services/ReportingScriptProvider.cs tests/MoldplanDbSwitcher.Tests/Services/ReportingScriptProviderTests.cs
git commit -m "feat: ScriptProvider 改內嵌載入並渲染雙占位符（可外部覆寫）"
```

---

## Task 3：重寫 ReportingDeployService（新序列＋master 連線＋掃描＋匯出）

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/ReportingInstallStatus.cs`
- Modify: `src/MoldplanDbSwitcher/Services/IReportingDeployService.cs`
- Modify: `src/MoldplanDbSwitcher/Services/ReportingDeployService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ReportingDeployServiceTests.cs`（既有檔，重寫/擴充）

- [ ] **Step 1: 安裝狀態 model**

`src/MoldplanDbSwitcher/Models/ReportingInstallStatus.cs`：
```csharp
namespace MoldplanDbSwitcher.Models;

public record ReportingInstallStatus(
    bool DatabaseExists, bool SchemaExists,
    int TableCount, int ViewCount, int ProcedureCount)
{
    public bool IsFullyDeployed =>
        DatabaseExists && SchemaExists && TableCount >= 14 && ViewCount >= 13 && ProcedureCount >= 13;
}
```

- [ ] **Step 2: 寫失敗測試**

重點：`GenerateExportSql` 純字串組合（不需 DB，可純單元測試）；部署/掃描需 LocalDB（沿用既有 `ReportingDeployServiceTests` 的 LocalDbFixture 模式 — 先讀該檔了解 fixture 用法）。先加可純測的匯出測試：
```csharp
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class ReportingDeployServiceExportTests
{
    private static ReportingDeployService Create()
    {
        var provider = new ReportingScriptProvider(externalOverrideDir: null);
        var executor = Substitute.For<ISqlBatchExecutor>();
        return new ReportingDeployService(
            "Server=tcp:host;Database=MoldPlan-Reporting;User Id=sa;Password=x;TrustServerCertificate=True",
            provider, executor);
    }

    [Fact]
    public void GenerateExportSql_SubstitutesPlaceholders_AndOrders01To07()
    {
        var sql = Create().GenerateExportSql(
            new ReportingDeployParameters("MoldPlan-Reporting", "gma-staging"));
        Assert.DoesNotContain("<<Database>>", sql);
        Assert.DoesNotContain("<<MAINDB>>", sql);
        Assert.Contains("gma-staging", sql);
        // 01 在 05 之前
        Assert.True(sql.IndexOf("Create_Database", System.StringComparison.OrdinalIgnoreCase)
                  < sql.IndexOf("StoredProcedures", System.StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void GenerateExportSql_IncludeDrop_AppendsDropScript()
    {
        var withDrop = Create().GenerateExportSql(
            new ReportingDeployParameters("MoldPlan-Reporting", "main"), includeDrop: true);
        Assert.Contains("Drop", withDrop, System.StringComparison.OrdinalIgnoreCase);
    }
}
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingDeployServiceExportTests"`
Expected: FAIL（`GenerateExportSql` 不存在）。

- [ ] **Step 4: 重寫介面**

`src/MoldplanDbSwitcher/Services/IReportingDeployService.cs`：
```csharp
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IReportingDeployService
{
    /// <summary>依序部署 01→07（建庫→schema→tables→views→SP→daily job→hourly job）。任一步失敗即停。</summary>
    Task<IReadOnlyList<DeployStep>> DeployAllAsync(ReportingDeployParameters parameters,
        IProgress<DeployStep>? progress = null, CancellationToken ct = default);

    /// <summary>單獨部署某個 Job 檔（6=daily, 7=hourly）。</summary>
    Task<DeployStep> DeployJobAsync(int fileNumber, ReportingDeployParameters parameters,
        IProgress<DeployStep>? progress = null, CancellationToken ct = default);

    /// <summary>移除全部（98）。confirmDatabaseName 須等於 parameters.TargetDatabase 才執行。</summary>
    Task<DeployStep> DropAllAsync(ReportingDeployParameters parameters, string confirmDatabaseName,
        IProgress<DeployStep>? progress = null, CancellationToken ct = default);

    Task<ReportingInstallStatus> ScanInstallStatusAsync(CancellationToken ct = default);

    /// <summary>合併 01→07（含占位符替換）成單一可貼 SSMS 執行的 SQL；includeDrop 時於最前面附上 98。</summary>
    string GenerateExportSql(ReportingDeployParameters parameters, bool includeDrop = false);
}
```

- [ ] **Step 5: 重寫實作**

`src/MoldplanDbSwitcher/Services/ReportingDeployService.cs`：
```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

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

    // 建庫腳本(01)需在目標庫尚未存在時執行 → 一律連 master，腳本各自 USE 切換 context。
    private string MasterConnectionString()
    {
        var b = new SqlConnectionStringBuilder(_connectionString) { InitialCatalog = "master" };
        return b.ConnectionString;
    }

    public async Task<IReadOnlyList<DeployStep>> DeployAllAsync(ReportingDeployParameters p,
        IProgress<DeployStep>? progress = null, CancellationToken ct = default)
    {
        var steps = new List<DeployStep>();
        await using var conn = new SqlConnection(MasterConnectionString());
        await conn.OpenAsync(ct);
        foreach (var n in DeploySequence)
        {
            var step = await RunFileAsync(conn, n, p, progress, ct);
            steps.Add(step);
            if (step.Status == DeployStatus.Failed) break;
        }
        return steps;
    }

    public async Task<DeployStep> DeployJobAsync(int fileNumber, ReportingDeployParameters p,
        IProgress<DeployStep>? progress = null, CancellationToken ct = default)
    {
        await using var conn = new SqlConnection(MasterConnectionString());
        await conn.OpenAsync(ct);
        return await RunFileAsync(conn, fileNumber, p, progress, ct);
    }

    public async Task<DeployStep> DropAllAsync(ReportingDeployParameters p, string confirmDatabaseName,
        IProgress<DeployStep>? progress = null, CancellationToken ct = default)
    {
        if (!string.Equals(confirmDatabaseName, p.TargetDatabase, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException(
                $"確認名稱「{confirmDatabaseName}」與目標報表庫「{p.TargetDatabase}」不符，已中止");
        await using var conn = new SqlConnection(MasterConnectionString());
        await conn.OpenAsync(ct);
        return await RunFileAsync(conn, 98, p, progress, ct);
    }

    public async Task<ReportingInstallStatus> ScanInstallStatusAsync(CancellationToken ct = default)
    {
        var b = new SqlConnectionStringBuilder(_connectionString);
        var target = b.InitialCatalog;
        await using var conn = new SqlConnection(MasterConnectionString());
        await conn.OpenAsync(ct);

        var dbExists = await ScalarIntAsync(conn,
            "SELECT COUNT(*) FROM sys.databases WHERE name = @db",
            ("@db", target), ct) > 0;
        if (!dbExists) return new ReportingInstallStatus(false, false, 0, 0, 0);

        string q(string body) => $"USE [{Escape(target)}]; {body}";
        var schemaExists = await ScalarIntAsync(conn,
            q("SELECT COUNT(*) FROM sys.schemas WHERE name = 'Reporting'"), ct: ct) > 0;
        var tables = await ScalarIntAsync(conn,
            q("SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id WHERE s.name='Reporting'"), ct: ct);
        var views = await ScalarIntAsync(conn,
            q("SELECT COUNT(*) FROM sys.views v JOIN sys.schemas s ON v.schema_id=s.schema_id WHERE s.name='Reporting'"), ct: ct);
        var procs = await ScalarIntAsync(conn,
            q("SELECT COUNT(*) FROM sys.procedures p JOIN sys.schemas s ON p.schema_id=s.schema_id WHERE s.name='Reporting'"), ct: ct);
        return new ReportingInstallStatus(true, schemaExists, tables, views, procs);
    }

    public string GenerateExportSql(ReportingDeployParameters p, bool includeDrop = false)
    {
        var sb = new StringBuilder();
        sb.AppendLine("-- Reporting 部署匯出（請在 SSMS 直接執行；建庫步驟需 master 權限）");
        sb.AppendLine($"-- 目標報表庫: {p.TargetDatabase}  來源主庫: {p.SourceDatabase}");
        sb.AppendLine();
        if (includeDrop)
        {
            sb.AppendLine(_scripts.Render(98, p));
            sb.AppendLine("GO");
        }
        foreach (var n in DeploySequence)
        {
            sb.AppendLine(_scripts.Render(n, p));
            sb.AppendLine("GO");
        }
        return sb.ToString();
    }

    private async Task<DeployStep> RunFileAsync(SqlConnection conn, int fileNumber,
        ReportingDeployParameters p, IProgress<DeployStep>? progress, CancellationToken ct)
    {
        var script = _scripts.GetScript(fileNumber);
        var sql = _scripts.Render(fileNumber, p);
        var step = new DeployStep(script.FileName, $"執行 {script.FileName}", DeployStatus.Running, null);
        progress?.Report(step);
        var results = await _executor.ExecuteAsync(conn, sql, null, ct);
        var failed = results.FirstOrDefault(r => !r.Success);
        var final = failed == null
            ? step with { Status = DeployStatus.Success }
            : step with { Status = DeployStatus.Failed, Error = failed.Error };
        progress?.Report(final);
        return final;
    }

    private static string Escape(string ident) => ident.Replace("]", "]]");

    private static async Task<int> ScalarIntAsync(SqlConnection conn, string sql,
        (string, object)? param = null, CancellationToken ct = default)
    {
        await using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 30 };
        if (param is { } pr) cmd.Parameters.AddWithValue(pr.Item1, pr.Item2);
        var o = await cmd.ExecuteScalarAsync(ct);
        return o is null or DBNull ? 0 : Convert.ToInt32(o);
    }
}
```
> 注意：`ISqlBatchExecutor.ExecuteAsync(conn, sql, progress, ct)` 沿用既有簽章（依 `GO` 分批）。`RunFileAsync` 改為共用一條已開啟的 master 連線（腳本自身 `USE` 切換 DB），避免每檔重開連線。
> 讀既有 `ReportingDeployServiceTests.cs` 確認 LocalDbFixture 與 `ISqlBatchExecutor` 真實/mock 用法；本服務的整合測試（實連 LocalDB 跑 01→05）可選擇沿用既有 fixture，若 LocalDB 不支援 Agent Job（06/07）則整合測試僅驗 01→05 並 mock executor 驗 06/07 被以正確 SQL 呼叫。

- [ ] **Step 6: 跑匯出測試 + 既有部署測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingDeployServiceExportTests|ReportingDeployServiceTests"`
Expected: 匯出 PASS；既有部署測試若因介面變更而編譯失敗，於本步一併更新為新介面（DeployAllAsync/ScanInstallStatusAsync/DropAllAsync(params,confirm)）。全綠。

- [ ] **Step 7: commit**

```bash
git add src/MoldplanDbSwitcher/Models/ReportingInstallStatus.cs src/MoldplanDbSwitcher/Services/IReportingDeployService.cs src/MoldplanDbSwitcher/Services/ReportingDeployService.cs tests/MoldplanDbSwitcher.Tests/Services/
git commit -m "feat: DeployService 對齊 01→07 序列、master 連線建庫、安裝掃描與匯出 SQL"
```

---

## Task 4：ReportingDeployViewModel — 兩輸入＋新流程＋匯出

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/ReportingDeployViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingDeployViewModelTests.cs`

- [ ] **Step 1: 寫失敗測試**

加入（沿用該檔 mock 建構方式；`_deployFactory` 回傳的 `IReportingDeployService` 用 NSubstitute）：
```csharp
[Fact]
public void SourceDatabaseName_DefaultsFromConnection_OnUseConnection()
{
    var vm = CreateViewModel();                 // 沿用既有工廠
    // UseConnectionAsync 應把來源主庫帶入 SourceDatabaseName（=連線 DB）
    // 依既有測試風格斷言（見下方說明）
}

[Fact]
public async Task DeployAll_UsesParameters_WithTargetAndSource()
{
    var deploy = Substitute.For<IReportingDeployService>();
    deploy.DeployAllAsync(Arg.Any<ReportingDeployParameters>(), Arg.Any<IProgress<DeployStep>?>(), Arg.Any<CancellationToken>())
          .Returns(new List<DeployStep> { new("01", "x", DeployStatus.Success, null) });
    var vm = CreateViewModel(deploy);           // 注入 mock deploy
    vm.TargetDatabaseName = "MoldPlan-Reporting";
    vm.SourceDatabaseName = "gma-staging";

    await vm.DeployAllCommand.ExecuteAsync(null);

    await deploy.Received().DeployAllAsync(
        Arg.Is<ReportingDeployParameters>(p => p.TargetDatabase == "MoldPlan-Reporting" && p.SourceDatabase == "gma-staging"),
        Arg.Any<IProgress<DeployStep>?>(), Arg.Any<CancellationToken>());
}

[Fact]
public async Task ExportSql_WritesToSaveCallbackPath()
{
    var deploy = Substitute.For<IReportingDeployService>();
    deploy.GenerateExportSql(Arg.Any<ReportingDeployParameters>(), Arg.Any<bool>()).Returns("-- SQL");
    var vm = CreateViewModel(deploy);
    string? written = null;
    vm.SaveExportSqlCallback = (content) => { written = content; return Task.FromResult<string?>("C:/x.sql"); };

    await vm.ExportSqlCommand.ExecuteAsync(null);

    Assert.Equal("-- SQL", written);
}
```
> 依該測試類別現有的 `CreateViewModel(...)` 工廠調整：需能注入 mock `IReportingDeployService`。若沒有可注入 deploy 的多載，新增一個。

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingDeployViewModelTests"`
Expected: FAIL（`SourceDatabaseName`/`ExportSqlCommand`/`SaveExportSqlCallback` 不存在；舊 DeployAll 簽章）。

- [ ] **Step 3: 修改 ViewModel**

於 `ReportingDeployViewModel.cs`：
1. 新增屬性與回呼：
```csharp
[ObservableProperty] private string _sourceDatabaseName = "";
public Func<string, Task<string?>>? SaveExportSqlCallback { get; set; }

private ReportingDeployParameters BuildParameters() =>
    new(TargetDatabaseName, SourceDatabaseName, JobOwner);
```
2. `UseConnectionAsync(string, string)` 中設 `SourceDatabaseName = databaseName;`（來源主庫預設＝目前連線 DB）；`TargetDatabaseName` 若為空則預設 `"MoldPlan-Reporting"`：
```csharp
public async Task UseConnectionAsync(string connectionString, string databaseName)
{
    _objects = _objectsFactory(connectionString);
    _deploy = _deployFactory(connectionString);
    SourceDatabaseName = databaseName;
    if (string.IsNullOrWhiteSpace(TargetDatabaseName)) TargetDatabaseName = "MoldPlan-Reporting";
    await ScanEnvironmentAsync();
}
```
3. 重寫 `DeployAllAsync` 用新服務：
```csharp
[RelayCommand]
private async Task DeployAllAsync()
{
    Steps.Clear();
    IsBusy = true;
    try
    {
        var progress = new Progress<DeployStep>(s =>
        {
            var idx = -1;
            for (int i = 0; i < Steps.Count; i++) if (Steps[i].FileName == s.FileName) { idx = i; break; }
            if (idx >= 0) Steps[idx] = s; else Steps.Add(s);
        });
        await _deploy.DeployAllAsync(BuildParameters(), progress);
    }
    catch (Exception ex) { ErrorMessage = ex.Message; }
    finally { IsBusy = false; await ScanEnvironmentAsync(); }
}
```
4. Job 部署改新編號與參數（daily=6、hourly=7）：
```csharp
[RelayCommand] private async Task DeployDailyJobAsync()  { IsBusy = true; try { Steps.Add(await _deploy.DeployJobAsync(6, BuildParameters())); } finally { IsBusy = false; } }
[RelayCommand] private async Task DeployHourlyJobAsync() { IsBusy = true; try { Steps.Add(await _deploy.DeployJobAsync(7, BuildParameters())); } finally { IsBusy = false; } }
```
5. `DropAllAsync(string confirmName)` 改用 params：
```csharp
public async Task DropAllAsync(string confirmName)
{
    IsBusy = true;
    try { Steps.Add(await _deploy.DropAllAsync(BuildParameters(), confirmName)); }
    catch (Exception ex) { ErrorMessage = ex.Message; }
    finally { IsBusy = false; await ScanEnvironmentAsync(); }
}
```
6. 匯出命令：
```csharp
[RelayCommand]
private async Task ExportSqlAsync()
{
    if (SaveExportSqlCallback is null) return;
    var sql = _deploy.GenerateExportSql(BuildParameters());
    await SaveExportSqlCallback(sql);
}
```
7. `ScanEnvironmentAsync` 改用 `ScanInstallStatusAsync`（一次取回，較精簡）：
```csharp
[RelayCommand]
private async Task ScanEnvironmentAsync()
{
    try
    {
        IsBusy = true; ErrorMessage = null;
        var st = await _deploy.ScanInstallStatusAsync();
        SchemaExists = st.SchemaExists;
        TableCount = st.TableCount; ViewCount = st.ViewCount; ProcedureCount = st.ProcedureCount;
    }
    catch (Exception ex) { ErrorMessage = ex.Message; }
    finally { IsBusy = false; }
}
```
8. **移除已死的 `IReportingObjectService` 依賴**：掃描改走 `_deploy.ScanInstallStatusAsync()` 後，`_objects`/`_objectsFactory` 不再被使用（且舊掃描連到目標庫，無法偵測「庫尚未存在」）。從 `ReportingDeployViewModel` 移除欄位 `_objectsFactory`、`_objects`，並把建構式參數 `Func<string, IReportingObjectService> objectsFactory` 拿掉：
```csharp
public ReportingDeployViewModel(
    Func<string, IReportingDeployService> deployFactory,
    string initialConnectionString,
    string initialDatabaseName)
{
    _deployFactory = deployFactory;
    _deploy = deployFactory(initialConnectionString);
    _sourceDatabaseName = initialDatabaseName;
    _targetDatabaseName = "MoldPlan-Reporting";
    _jobOwner = "sa";
    Title = "Reporting 部署";
}
```
`UseConnectionAsync(string, string)` 內移除 `_objects = _objectsFactory(connectionString);` 那行。
> 此變更牽動 Task 6 DI 工廠（少傳 objectsFactory）與 `ReportingDeployViewModelTests` 建構（少一個 mock 參數）——於 Task 4 Step 1 測試與 Step 3 一併更新，Task 6 同步調整。避免遺留死碼（code-quality 會抓）。

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingDeployViewModelTests"`
Expected: PASS（含新測試與既有回歸）。

- [ ] **Step 5: commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/ReportingDeployViewModel.cs tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingDeployViewModelTests.cs
git commit -m "feat: 部署 ViewModel 加入來源主庫輸入、新部署序列與匯出 SQL"
```

---

## Task 5：ReportingDeployPage UI — 兩輸入＋匯出鈕＋跨 instance 提示

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/ReportingDeployPage.axaml`
- Modify: `src/MoldplanDbSwitcher/Views/ReportingDeployPage.axaml.cs`（若需 SaveExportSqlCallback 接 StorageProvider）

- [ ] **Step 1: 讀現況**

讀 `src/MoldplanDbSwitcher/Views/ReportingDeployPage.axaml` 與其 code-behind，了解既有「目標 DB / Job Owner / 部署全部 / Daily / Hourly / 移除全部」版面與 `x:DataType`。

- [ ] **Step 2: 加入來源主庫輸入與匯出鈕**

於頂部輸入區，將原本只有「目標 DB」改為兩個 `TextBox`：
```xml
<StackPanel Orientation="Horizontal" Spacing="8">
  <TextBlock Text="目標報表庫：" VerticalAlignment="Center" />
  <TextBox Text="{Binding TargetDatabaseName}" Width="200" />
  <TextBlock Text="來源主庫：" VerticalAlignment="Center" />
  <TextBox Text="{Binding SourceDatabaseName}" Width="200" />
  <TextBlock Text="Job Owner：" VerticalAlignment="Center" />
  <TextBox Text="{Binding JobOwner}" Width="100" />
</StackPanel>
```
按鈕列加入「匯出 SQL」：
```xml
<Button Content="匯出 SQL" Click="OnExportSqlClick" />
```
（其餘「部署全部」「Daily」「Hourly」「移除全部」沿用既有綁定；確認「部署全部」綁 `DeployAllCommand`、Daily 綁 `DeployDailyJobCommand`、Hourly 綁 `DeployHourlyJobCommand`。）
加入跨 instance 提示文字：
```xml
<TextBlock Text="⚠ 報表庫須與來源主庫位於同一個 SQL Server instance（View 以三段式跨庫參照）。"
           Foreground="Orange" TextWrapping="Wrap" Margin="0,4,0,0" />
```

- [ ] **Step 3: code-behind 接匯出存檔**

於 `ReportingDeployPage.axaml.cs` 加（沿用專案既有 StorageProvider 存檔模式，如 MainWindow 的匯出 Excel）：
```csharp
private async void OnExportSqlClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
{
    if (DataContext is not MoldplanDbSwitcher.ViewModels.ReportingDeployViewModel vm) return;
    var top = Avalonia.Controls.TopLevel.GetTopLevel(this);
    if (top is null) return;
    vm.SaveExportSqlCallback = async (content) =>
    {
        var file = await top.StorageProvider.SaveFilePickerAsync(new Avalonia.Platform.Storage.FilePickerSaveOptions
        {
            Title = "匯出 Reporting 部署 SQL",
            DefaultExtension = "sql",
            SuggestedFileName = "Reporting_Deploy",
            FileTypeChoices = new[] { new Avalonia.Platform.Storage.FilePickerFileType("SQL 檔案") { Patterns = new[] { "*.sql" } } }
        });
        if (file is null) return null;
        await using var stream = await file.OpenWriteAsync();
        await using var writer = new System.IO.StreamWriter(stream);
        await writer.WriteAsync(content);
        return file.Path.LocalPath;
    };
    await vm.ExportSqlCommand.ExecuteAsync(null);
}
```

- [ ] **Step 4: build + 全測試**

Run: `dotnet build src/MoldplanDbSwitcher/` 然後 `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: build 0 error（容許既有 3 個 AVLN3001）；測試全綠。

- [ ] **Step 5: commit**

```bash
git add src/MoldplanDbSwitcher/Views/ReportingDeployPage.axaml src/MoldplanDbSwitcher/Views/ReportingDeployPage.axaml.cs
git commit -m "feat: 部署頁加入來源主庫輸入、匯出 SQL 與跨 instance 提示"
```

---

## Task 6：Program.cs DI 調整

**Files:**
- Modify: `src/MoldplanDbSwitcher/Program.cs`

- [ ] **Step 1: 調整註冊**

`IReportingScriptProvider` 改為新建構式（外部覆寫路徑來自設定；無則 null → 純內嵌）：
```csharp
services.AddSingleton<IReportingScriptProvider>(sp =>
{
    var settings = sp.GetRequiredService<IAppSettingsService>();
    // 沿用既有取外部腳本路徑的設定；若無此設定則傳 null（純內嵌）
    var overrideDir = settings.GetMoldPlanScriptsPath();   // 既有方法；可能回空字串
    return new ReportingScriptProvider(string.IsNullOrWhiteSpace(overrideDir) ? null : overrideDir);
});
```
`Func<string, IReportingDeployService>` 工廠不變（仍 `new ReportingDeployService(connStr, scripts, executor)`）。

因 Task 4 移除了 `ReportingDeployViewModel` 的 `objectsFactory` 參數，更新其 transient 註冊（P1 設於 Program.cs），拿掉 `Func<string, IReportingObjectService>` 引數：
```csharp
services.AddTransient<ReportingDeployViewModel>(sp =>
{
    var factory = sp.GetRequiredService<ISqlConnectionFactory>();
    var settings = sp.GetRequiredService<ISettingsService>();
    var profile = settings.LoadProfiles().FirstOrDefault();
    var connStr = profile != null ? factory.Create(profile).ConnectionString : "";
    return new ReportingDeployViewModel(
        sp.GetRequiredService<Func<string, IReportingDeployService>>(),
        connStr,
        profile?.Database ?? "");
});
```

- [ ] **Step 2: build + 全測試 + 啟動煙霧測試**

Run: `dotnet build src/MoldplanDbSwitcher/` 然後 `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: 0 error、全綠。
（可選）啟動 App 確認部署頁顯示兩個輸入框、匯出鈕，且 DI 無啟動例外；測畢關閉 App。

- [ ] **Step 3: commit**

```bash
git add src/MoldplanDbSwitcher/Program.cs
git commit -m "chore: DI 改用內嵌 ScriptProvider（可外部覆寫）"
```

---

## 完成準則（P2）

- [ ] 9 個腳本內嵌於發佈包；`ListAvailable()` 回 9 筆，皆無 BOM。
- [ ] `Render` 正確替換 `<<Database>>`/`<<MAINDB>>` 與 Job owner。
- [ ] `DeployAllAsync` 依 01→07 序列、以 master 連線建庫後逐檔執行；任一失敗即停。
- [ ] `ScanInstallStatusAsync` 正確回報 DB/schema 存在與 14/13/13 計數。
- [ ] `GenerateExportSql` 產出可貼 SSMS 的合併、已替換占位符 SQL。
- [ ] 部署頁有「目標報表庫 / 來源主庫」兩輸入、匯出鈕、跨 instance 提示；移除全部仍需打字確認。
- [ ] 全測試綠；UI 文字繁體中文（Law 1）。

> 下一步：P2 介面落地後，撰寫 P3（監控儀表板：`IJobMonitorService` + RefreshLog + 狀態彙總 + 自動刷新）。
