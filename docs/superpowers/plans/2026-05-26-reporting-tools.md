# Reporting 查詢器 + 部署管理器 實作計畫

> ⚠ **歷史紀錄（保留作設計過程參考，內文未更新）**。文中關於 Reporting 部署腳本來源的描述（MoldPlanScriptsPath / MOLDPLAN_REPO / `<<CHANGE_ME>>` / 外部資料夾預設 / D:\Repos\MoldPlan-Workspace）已於 v1.4.x 變更：腳本改為**內嵌**、雙占位符 `<<Database>>`/`<<MAINDB>>`、源頭 repo＝`gitlab.com/wdmis/waydosoft.moldplan.docs`。現況請見 README。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 MoldplanDbSwitcher 新增兩個分頁 — Reporting 寬表查詢器（模組 A）與 Reporting 物件部署管理器（模組 B），讓 DBA 能在同一個桌面 App 切換連線、查詢寬表、部署 / 重建 SSDT 腳本。

**Architecture:** MVVM + Interface-first Services（沿用既有 `ISqlConnectionFactory` / `IConnectionSourceService`）。MainWindow 改為 TabControl 三頁。新增 5 個 Service（`ReportingObjectService`、`ReportingQueryService`、`ReportingDeployService`、`ReportingScriptProvider`、`SqlBatchExecutor`）、2 個 ViewModel、2 個 View。`MoldPlanScriptsPath` 由 `AppSettingsService` 管理，預設讀環境變數 `MOLDPLAN_REPO`，最後 fallback 至 `D:\Repos\MoldPlan-Workspace\docs\scripts\Reporting`。

**Tech Stack:** .NET 9 / Avalonia 11.3 / CommunityToolkit.Mvvm / Microsoft.Data.SqlClient / xUnit / NSubstitute

**全域決策（已確認）：**
- 腳本路徑：AppSettings + `MOLDPLAN_REPO` 環境變數
- Query Top N：預設 100，硬上限 10000
- Drop All 防呆：輸入 DB 名稱 + 二次確認對話框
- Agent Job UI：全平台顯示

---

## 檔案結構

### 新增（src/MoldplanDbSwitcher）

| 路徑 | 職責 |
|---|---|
| `Models/ReportingObject.cs` | `ReportingObject` record + `ReportingObjectKind` enum |
| `Models/ReportingColumn.cs` | `ReportingColumn` record |
| `Models/RefreshLogEntry.cs` | `RefreshLogEntry` record |
| `Models/DeployStep.cs` | `DeployStep` + `DeployStatus` enum |
| `Models/ReportingScript.cs` | `ReportingScript` record（FileNumber、FileName、Content） |
| `Services/IReportingObjectService.cs` + `ReportingObjectService.cs` | 列舉 Reporting schema 物件 |
| `Services/IReportingQueryService.cs` + `ReportingQueryService.cs` | 寬表 / View 唯讀查詢 |
| `Services/IReportingScriptProvider.cs` + `ReportingScriptProvider.cs` | 讀取 .sql、替換 `<<CHANGE_ME>>` |
| `Services/ISqlBatchExecutor.cs` + `SqlBatchExecutor.cs` | 切 GO batch、逐段執行 |
| `Services/IReportingDeployService.cs` + `ReportingDeployService.cs` | 部署 / Drop 流程協調 |
| `ViewModels/ReportingQueryViewModel.cs` | 模組 A ViewModel |
| `ViewModels/ReportingDeployViewModel.cs` | 模組 B ViewModel |
| `ViewModels/DropConfirmDialogViewModel.cs` | Drop 確認對話框 ViewModel |
| `Views/ReportingQueryPage.axaml` + `.axaml.cs` | 模組 A View（UserControl） |
| `Views/ReportingDeployPage.axaml` + `.axaml.cs` | 模組 B View（UserControl） |
| `Views/DropConfirmDialog.axaml` + `.axaml.cs` | Drop 確認對話框 |

### 修改

| 路徑 | 修改點 |
|---|---|
| `src/MoldplanDbSwitcher/Models/AppSettings.cs` | 新增 `MoldPlanScriptsPath` 屬性 |
| `src/MoldplanDbSwitcher/Services/AppSettingsService.cs` | 預設值邏輯（環境變數 fallback） |
| `src/MoldplanDbSwitcher/Views/MainWindow.axaml` | 改為 TabControl 三頁 |
| `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs` | TabControl code-behind |
| `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` | 暴露 `ReportingQueryViewModel` / `ReportingDeployViewModel` 給 View |
| `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml` | 新增 `MoldPlanScriptsPath` 輸入欄 |
| `src/MoldplanDbSwitcher/Program.cs` | DI 註冊新 Services + ViewModels |

### 測試（tests/MoldplanDbSwitcher.Tests）

| 路徑 | 對應 |
|---|---|
| `Services/ReportingScriptProviderTests.cs` | 純檔案 IO、替換邏輯 |
| `Services/SqlBatchExecutorTests.cs` | GO 切割邏輯（不需 DB） |
| `Services/ReportingObjectServiceTests.cs` | 需 LocalDB；標記 `[Trait("Category", "Integration")]` |
| `Services/ReportingQueryServiceTests.cs` | 需 LocalDB；whitelist 防 injection |
| `Services/ReportingDeployServiceTests.cs` | 需 LocalDB；端對端部署測試 |
| `ViewModels/ReportingQueryViewModelTests.cs` | NSubstitute mock Services |
| `ViewModels/ReportingDeployViewModelTests.cs` | NSubstitute mock Services |
| `TestHelpers/LocalDbFixture.cs` | LocalDB 啟動 / 釋放 helper |

---

## Phase 1：Service 層基礎

### Task 1: ReportingScript Model + ReportingScriptProvider

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/ReportingScript.cs`
- Create: `src/MoldplanDbSwitcher/Services/IReportingScriptProvider.cs`
- Create: `src/MoldplanDbSwitcher/Services/ReportingScriptProvider.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ReportingScriptProviderTests.cs`

- [ ] **Step 1: 寫失敗測試（讀取存在的腳本）**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/ReportingScriptProviderTests.cs
using System.IO;
using MoldplanDbSwitcher.Services;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class ReportingScriptProviderTests : IDisposable
{
    private readonly string _tempDir;

    public ReportingScriptProviderTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "rsp_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir)) Directory.Delete(_tempDir, true);
    }

    [Fact]
    public void GetScript_ExistingFile_ReturnsContent()
    {
        File.WriteAllText(Path.Combine(_tempDir, "01_Reporting_Create_Schema.sql"), "CREATE SCHEMA Reporting;");
        var sut = new ReportingScriptProvider(_tempDir);

        var script = sut.GetScript(1);

        Assert.Equal(1, script.FileNumber);
        Assert.Equal("01_Reporting_Create_Schema.sql", script.FileName);
        Assert.Contains("CREATE SCHEMA Reporting", script.Content);
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingScriptProviderTests"`
Expected: FAIL（`ReportingScriptProvider` 不存在 / 編譯錯）

- [ ] **Step 3: 寫 Model + Interface + 最小實作**

```csharp
// src/MoldplanDbSwitcher/Models/ReportingScript.cs
namespace MoldplanDbSwitcher.Models;

public record ReportingScript(int FileNumber, string FileName, string Content);
```

```csharp
// src/MoldplanDbSwitcher/Services/IReportingScriptProvider.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IReportingScriptProvider
{
    ReportingScript GetScript(int fileNumber);
    string RenderJobScript(int fileNumber, string databaseName, string jobOwner);
    IReadOnlyList<ReportingScript> ListAvailable();
}
```

```csharp
// src/MoldplanDbSwitcher/Services/ReportingScriptProvider.cs
using System.IO;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ReportingScriptProvider : IReportingScriptProvider
{
    private readonly string _scriptsDir;

    public ReportingScriptProvider(string scriptsDir)
    {
        _scriptsDir = scriptsDir;
    }

    public ReportingScript GetScript(int fileNumber)
    {
        var prefix = fileNumber.ToString("D2") + "_";
        var file = Directory.EnumerateFiles(_scriptsDir, "*.sql")
            .FirstOrDefault(f => Path.GetFileName(f).StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            ?? throw new FileNotFoundException($"找不到編號 {fileNumber:D2} 的腳本", _scriptsDir);
        return new ReportingScript(fileNumber, Path.GetFileName(file), File.ReadAllText(file));
    }

    public string RenderJobScript(int fileNumber, string databaseName, string jobOwner)
    {
        if (string.IsNullOrWhiteSpace(databaseName))
            throw new ArgumentException("databaseName 不可為空", nameof(databaseName));
        var script = GetScript(fileNumber);
        return script.Content
            .Replace("<<CHANGE_ME>>", databaseName)
            .Replace("@JobOwner = N'sa'", $"@JobOwner = N'{jobOwner}'");
    }

    public IReadOnlyList<ReportingScript> ListAvailable()
    {
        if (!Directory.Exists(_scriptsDir)) return Array.Empty<ReportingScript>();
        return Directory.EnumerateFiles(_scriptsDir, "*.sql")
            .Select(f => Path.GetFileName(f))
            .Where(n => n.Length >= 3 && char.IsDigit(n[0]) && char.IsDigit(n[1]) && n[2] == '_')
            .Select(n => GetScript(int.Parse(n.Substring(0, 2))))
            .OrderBy(s => s.FileNumber)
            .ToList();
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingScriptProviderTests.GetScript_ExistingFile_ReturnsContent"`
Expected: PASS

- [ ] **Step 5: 補測試（替換、找不到、列出全部）**

```csharp
[Fact]
public void RenderJobScript_ReplacesChangeMePlaceholder()
{
    File.WriteAllText(Path.Combine(_tempDir, "05_Reporting_DailyRefresh_Job.sql"),
        "DECLARE @DatabaseName NVARCHAR(128) = N'<<CHANGE_ME>>';");
    var sut = new ReportingScriptProvider(_tempDir);

    var rendered = sut.RenderJobScript(5, "MoldPlan", "sa");

    Assert.Contains("N'MoldPlan'", rendered);
    Assert.DoesNotContain("<<CHANGE_ME>>", rendered);
}

[Fact]
public void RenderJobScript_EmptyDatabaseName_Throws()
{
    var sut = new ReportingScriptProvider(_tempDir);
    Assert.Throws<ArgumentException>(() => sut.RenderJobScript(5, "", "sa"));
}

[Fact]
public void GetScript_MissingFile_Throws()
{
    var sut = new ReportingScriptProvider(_tempDir);
    Assert.Throws<FileNotFoundException>(() => sut.GetScript(1));
}

[Fact]
public void ListAvailable_ReturnsAllNumbered()
{
    File.WriteAllText(Path.Combine(_tempDir, "01_a.sql"), "a");
    File.WriteAllText(Path.Combine(_tempDir, "02_b.sql"), "b");
    File.WriteAllText(Path.Combine(_tempDir, "README.md"), "skip");
    var sut = new ReportingScriptProvider(_tempDir);

    var list = sut.ListAvailable();

    Assert.Equal(2, list.Count);
    Assert.Equal(new[] { 1, 2 }, list.Select(s => s.FileNumber));
}
```

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingScriptProviderTests"`
Expected: 全部 PASS

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/Models/ReportingScript.cs \
        src/MoldplanDbSwitcher/Services/IReportingScriptProvider.cs \
        src/MoldplanDbSwitcher/Services/ReportingScriptProvider.cs \
        tests/MoldplanDbSwitcher.Tests/Services/ReportingScriptProviderTests.cs
git commit -m "feat: 新增 ReportingScriptProvider 讀取部署腳本"
```

---

### Task 2: SqlBatchExecutor（GO 切割）

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/ISqlBatchExecutor.cs`
- Create: `src/MoldplanDbSwitcher/Services/SqlBatchExecutor.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/SqlBatchExecutorTests.cs`

- [ ] **Step 1: 寫失敗測試（純切割邏輯，不打 DB）**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/SqlBatchExecutorTests.cs
using MoldplanDbSwitcher.Services;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class SqlBatchExecutorTests
{
    [Fact]
    public void SplitBatches_SimpleGoSeparated_ReturnsTwo()
    {
        const string sql = "SELECT 1;\nGO\nSELECT 2;\nGO";
        var batches = SqlBatchExecutor.SplitBatches(sql);
        Assert.Equal(2, batches.Count);
        Assert.Contains("SELECT 1", batches[0]);
        Assert.Contains("SELECT 2", batches[1]);
    }

    [Fact]
    public void SplitBatches_GoInsideString_NotSplit()
    {
        const string sql = "PRINT 'this has GO inside';\nGO\nPRINT 'second';";
        var batches = SqlBatchExecutor.SplitBatches(sql);
        Assert.Equal(2, batches.Count);
        Assert.Contains("this has GO inside", batches[0]);
    }

    [Fact]
    public void SplitBatches_GoIndented_StillSplits()
    {
        const string sql = "SELECT 1;\n  GO  \nSELECT 2;";
        var batches = SqlBatchExecutor.SplitBatches(sql);
        Assert.Equal(2, batches.Count);
    }

    [Fact]
    public void SplitBatches_EmptyBatches_Skipped()
    {
        const string sql = "GO\nGO\nSELECT 1;\nGO";
        var batches = SqlBatchExecutor.SplitBatches(sql);
        Assert.Single(batches);
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "SqlBatchExecutorTests"`
Expected: FAIL

- [ ] **Step 3: 寫 Interface + 實作（含靜態切割方法）**

```csharp
// src/MoldplanDbSwitcher/Services/ISqlBatchExecutor.cs
using Microsoft.Data.SqlClient;

namespace MoldplanDbSwitcher.Services;

public record BatchResult(int BatchIndex, bool Success, string? Error, int? RowsAffected);

public interface ISqlBatchExecutor
{
    Task<IReadOnlyList<BatchResult>> ExecuteAsync(
        SqlConnection connection, string sql, IProgress<BatchResult>? progress = null, CancellationToken ct = default);
}
```

```csharp
// src/MoldplanDbSwitcher/Services/SqlBatchExecutor.cs
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace MoldplanDbSwitcher.Services;

public class SqlBatchExecutor : ISqlBatchExecutor
{
    private static readonly Regex GoLineRegex = new(
        @"^\s*GO\s*(?:--.*)?$",
        RegexOptions.IgnoreCase | RegexOptions.Multiline | RegexOptions.Compiled);

    public static IReadOnlyList<string> SplitBatches(string sql)
    {
        var batches = new List<string>();
        var lines = sql.Split('\n');
        var current = new System.Text.StringBuilder();
        var inSingleQuote = false;

        foreach (var rawLine in lines)
        {
            var line = rawLine.TrimEnd('\r');
            if (!inSingleQuote && GoLineRegex.IsMatch(line))
            {
                var batch = current.ToString().Trim();
                if (batch.Length > 0) batches.Add(batch);
                current.Clear();
                continue;
            }

            foreach (var c in line)
                if (c == '\'') inSingleQuote = !inSingleQuote;

            current.AppendLine(line);
        }

        var last = current.ToString().Trim();
        if (last.Length > 0) batches.Add(last);
        return batches;
    }

    public async Task<IReadOnlyList<BatchResult>> ExecuteAsync(
        SqlConnection connection, string sql, IProgress<BatchResult>? progress = null, CancellationToken ct = default)
    {
        var batches = SplitBatches(sql);
        var results = new List<BatchResult>();
        if (connection.State != System.Data.ConnectionState.Open)
            await connection.OpenAsync(ct);

        for (var i = 0; i < batches.Count; i++)
        {
            BatchResult result;
            try
            {
                await using var cmd = connection.CreateCommand();
                cmd.CommandText = batches[i];
                cmd.CommandTimeout = 300;
                var affected = await cmd.ExecuteNonQueryAsync(ct);
                result = new BatchResult(i, true, null, affected);
            }
            catch (Exception ex)
            {
                result = new BatchResult(i, false, ex.Message, null);
            }

            results.Add(result);
            progress?.Report(result);
            if (!result.Success) break;
        }
        return results;
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "SqlBatchExecutorTests"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/ISqlBatchExecutor.cs \
        src/MoldplanDbSwitcher/Services/SqlBatchExecutor.cs \
        tests/MoldplanDbSwitcher.Tests/Services/SqlBatchExecutorTests.cs
git commit -m "feat: 新增 SqlBatchExecutor 切 GO 並逐段執行"
```

---

### Task 3: Reporting Models（Object / Column / RefreshLog / DeployStep）

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/ReportingObject.cs`
- Create: `src/MoldplanDbSwitcher/Models/ReportingColumn.cs`
- Create: `src/MoldplanDbSwitcher/Models/RefreshLogEntry.cs`
- Create: `src/MoldplanDbSwitcher/Models/DeployStep.cs`

- [ ] **Step 1: 寫 Models（純資料型別，免測試）**

```csharp
// src/MoldplanDbSwitcher/Models/ReportingObject.cs
namespace MoldplanDbSwitcher.Models;

public enum ReportingObjectKind { BaseTable, SummaryTable, SystemTable, View, Procedure, AgentJob }

public record ReportingObject(string Schema, string Name, ReportingObjectKind Kind, string? Description);
```

```csharp
// src/MoldplanDbSwitcher/Models/ReportingColumn.cs
namespace MoldplanDbSwitcher.Models;

public record ReportingColumn(string Name, string DataType, bool IsNullable, string? Description);
```

```csharp
// src/MoldplanDbSwitcher/Models/RefreshLogEntry.cs
namespace MoldplanDbSwitcher.Models;

public record RefreshLogEntry(
    DateTime StartTime, DateTime? EndTime, string Status, int? RowCount, string? Error);
```

```csharp
// src/MoldplanDbSwitcher/Models/DeployStep.cs
namespace MoldplanDbSwitcher.Models;

public enum DeployStatus { Pending, Running, Success, Failed, Skipped }

public record DeployStep(string FileName, string Description, DeployStatus Status, string? Error);
```

- [ ] **Step 2: 編譯確認**

Run: `dotnet build src/MoldplanDbSwitcher/`
Expected: 0 error

- [ ] **Step 3: Commit**

```bash
git add src/MoldplanDbSwitcher/Models/ReportingObject.cs \
        src/MoldplanDbSwitcher/Models/ReportingColumn.cs \
        src/MoldplanDbSwitcher/Models/RefreshLogEntry.cs \
        src/MoldplanDbSwitcher/Models/DeployStep.cs
git commit -m "feat: 新增 Reporting 相關 Models"
```

---

### Task 4: LocalDbFixture（測試 Helper）

**Files:**
- Create: `tests/MoldplanDbSwitcher.Tests/TestHelpers/LocalDbFixture.cs`

> 此 Fixture 用 `(localdb)\MSSQLLocalDB`，為每個測試類別建立唯一資料庫，並於 Dispose 時 DROP。Task 5/6/7/8 都會用到。需要本機已安裝 SQL Server Express LocalDB（dev 環境前提）。

- [ ] **Step 1: 寫 Fixture**

```csharp
// tests/MoldplanDbSwitcher.Tests/TestHelpers/LocalDbFixture.cs
using Microsoft.Data.SqlClient;

namespace MoldplanDbSwitcher.Tests.TestHelpers;

public class LocalDbFixture : IAsyncLifetime
{
    public string DatabaseName { get; } = "MoldplanTest_" + Guid.NewGuid().ToString("N").Substring(0, 8);
    public string MasterConnectionString => "Server=(localdb)\\MSSQLLocalDB;Database=master;Integrated Security=true;TrustServerCertificate=true;";
    public string ConnectionString => $"Server=(localdb)\\MSSQLLocalDB;Database={DatabaseName};Integrated Security=true;TrustServerCertificate=true;";

    public async Task InitializeAsync()
    {
        await using var conn = new SqlConnection(MasterConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = $"CREATE DATABASE [{DatabaseName}];";
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DisposeAsync()
    {
        await using var conn = new SqlConnection(MasterConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = $"ALTER DATABASE [{DatabaseName}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DatabaseName}];";
        try { await cmd.ExecuteNonQueryAsync(); } catch { /* best effort */ }
    }

    public SqlConnection CreateConnection() => new(ConnectionString);
}
```

- [ ] **Step 2: 編譯**

Run: `dotnet build tests/MoldplanDbSwitcher.Tests/`
Expected: 0 error

- [ ] **Step 3: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/TestHelpers/LocalDbFixture.cs
git commit -m "test: 新增 LocalDbFixture 整合測試 helper"
```

---

### Task 5: ReportingObjectService

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IReportingObjectService.cs`
- Create: `src/MoldplanDbSwitcher/Services/ReportingObjectService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ReportingObjectServiceTests.cs`

- [ ] **Step 1: 寫失敗測試（用 LocalDbFixture 建假 schema）**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/ReportingObjectServiceTests.cs
using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Tests.TestHelpers;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

[Trait("Category", "Integration")]
public class ReportingObjectServiceTests : IClassFixture<LocalDbFixture>
{
    private readonly LocalDbFixture _db;
    public ReportingObjectServiceTests(LocalDbFixture db) { _db = db; }

    private async Task SeedAsync(string sql)
    {
        await using var conn = _db.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        await cmd.ExecuteNonQueryAsync();
    }

    [Fact]
    public async Task SchemaExists_AfterCreate_ReturnsTrue()
    {
        await SeedAsync("IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');");
        var sut = new ReportingObjectService(_db.ConnectionString);

        var exists = await sut.SchemaExistsAsync();

        Assert.True(exists);
    }

    [Fact]
    public async Task ListTablesAsync_ClassifiesKnownTables()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.SalesOrderRowData') IS NULL CREATE TABLE Reporting.SalesOrderRowData (Id INT);
            IF OBJECT_ID('Reporting.MoldCostSummary') IS NULL CREATE TABLE Reporting.MoldCostSummary (Id INT);
            IF OBJECT_ID('Reporting.RefreshLog') IS NULL CREATE TABLE Reporting.RefreshLog (Id INT);
        ");
        var sut = new ReportingObjectService(_db.ConnectionString);

        var tables = await sut.ListTablesAsync();

        Assert.Contains(tables, t => t.Name == "SalesOrderRowData" && t.Kind == ReportingObjectKind.BaseTable);
        Assert.Contains(tables, t => t.Name == "MoldCostSummary" && t.Kind == ReportingObjectKind.SummaryTable);
        Assert.Contains(tables, t => t.Name == "RefreshLog" && t.Kind == ReportingObjectKind.SystemTable);
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingObjectServiceTests"`
Expected: FAIL

- [ ] **Step 3: 寫 Interface + 實作**

```csharp
// src/MoldplanDbSwitcher/Services/IReportingObjectService.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IReportingObjectService
{
    Task<bool> SchemaExistsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<ReportingObject>> ListTablesAsync(CancellationToken ct = default);
    Task<IReadOnlyList<ReportingObject>> ListViewsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<ReportingObject>> ListProceduresAsync(CancellationToken ct = default);
    Task<IReadOnlyList<ReportingObject>> ListAllAsync(CancellationToken ct = default);
}
```

```csharp
// src/MoldplanDbSwitcher/Services/ReportingObjectService.cs
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
```

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingObjectServiceTests"`
Expected: PASS（需本機已啟動 LocalDB）

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/IReportingObjectService.cs \
        src/MoldplanDbSwitcher/Services/ReportingObjectService.cs \
        tests/MoldplanDbSwitcher.Tests/Services/ReportingObjectServiceTests.cs
git commit -m "feat: 新增 ReportingObjectService 列舉 Reporting schema 物件"
```

---

### Task 5b: ReportingObjectService — 欄位與 RefreshLog 查詢

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/IReportingObjectService.cs`
- Modify: `src/MoldplanDbSwitcher/Services/ReportingObjectService.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/Services/ReportingObjectServiceTests.cs`

- [ ] **Step 1: 新增測試**

```csharp
[Fact]
public async Task GetColumnsAsync_ReturnsSchemaInfo()
{
    await SeedAsync(@"
        IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
        IF OBJECT_ID('Reporting.T1') IS NOT NULL DROP TABLE Reporting.T1;
        CREATE TABLE Reporting.T1 (Id INT NOT NULL, Name NVARCHAR(50) NULL);
    ");
    var sut = new ReportingObjectService(_db.ConnectionString);

    var cols = await sut.GetColumnsAsync("T1");

    Assert.Equal(2, cols.Count);
    Assert.Equal("Id", cols[0].Name);
    Assert.False(cols[0].IsNullable);
    Assert.True(cols[1].IsNullable);
}

[Fact]
public async Task GetColumnsAsync_InvalidName_Throws()
{
    var sut = new ReportingObjectService(_db.ConnectionString);
    await Assert.ThrowsAsync<ArgumentException>(() => sut.GetColumnsAsync("T1; DROP TABLE x--"));
}
```

- [ ] **Step 2: 擴充 Interface**

```csharp
Task<IReadOnlyList<ReportingColumn>> GetColumnsAsync(string objectName, CancellationToken ct = default);
Task<IReadOnlyList<RefreshLogEntry>> GetRefreshLogAsync(string tableName, int top = 5, CancellationToken ct = default);
```

- [ ] **Step 3: 加上實作**

```csharp
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
```

- [ ] **Step 4: 跑測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingObjectServiceTests"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: ReportingObjectService 支援欄位資訊與 RefreshLog 查詢"
```

---

### Task 6: ReportingQueryService

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IReportingQueryService.cs`
- Create: `src/MoldplanDbSwitcher/Services/ReportingQueryService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ReportingQueryServiceTests.cs`

- [ ] **Step 1: 寫失敗測試（含 SQL injection 防禦）**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/ReportingQueryServiceTests.cs
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Tests.TestHelpers;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

[Trait("Category", "Integration")]
public class ReportingQueryServiceTests : IClassFixture<LocalDbFixture>
{
    private readonly LocalDbFixture _db;
    public ReportingQueryServiceTests(LocalDbFixture db) { _db = db; }

    private async Task SeedAsync(string sql)
    {
        await using var conn = _db.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        await cmd.ExecuteNonQueryAsync();
    }

    [Fact]
    public async Task QueryTopN_ReturnsRows()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.QT1') IS NOT NULL DROP TABLE Reporting.QT1;
            CREATE TABLE Reporting.QT1 (Id INT, Name NVARCHAR(50));
            INSERT INTO Reporting.QT1 VALUES (1,'a'),(2,'b'),(3,'c');
        ");
        var sut = new ReportingQueryService(_db.ConnectionString);

        var result = await sut.QueryTopNAsync("QT1", top: 10, where: null, orderBy: "Id");

        Assert.Equal(2, result.Columns.Count);
        Assert.Equal(3, result.Rows.Count);
    }

    [Fact]
    public async Task QueryTopN_InvalidObjectName_Throws()
    {
        var sut = new ReportingQueryService(_db.ConnectionString);
        await Assert.ThrowsAsync<ArgumentException>(
            () => sut.QueryTopNAsync("QT1; DROP TABLE QT1--", 10, null, null));
    }

    [Fact]
    public async Task QueryTopN_TopExceedsCap_Clamped()
    {
        var sut = new ReportingQueryService(_db.ConnectionString);
        Assert.Equal(10000, ReportingQueryService.MaxTopN);
        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(
            () => sut.QueryTopNAsync("QT1", top: 99999, null, null));
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingQueryServiceTests"`
Expected: FAIL

- [ ] **Step 3: Interface + 實作**

```csharp
// src/MoldplanDbSwitcher/Services/IReportingQueryService.cs
namespace MoldplanDbSwitcher.Services;

public record QueryResult(IReadOnlyList<string> Columns, IReadOnlyList<IReadOnlyList<object?>> Rows);

public interface IReportingQueryService
{
    Task<QueryResult> QueryTopNAsync(string objectName, int top, string? where, string? orderBy, CancellationToken ct = default);
}
```

```csharp
// src/MoldplanDbSwitcher/Services/ReportingQueryService.cs
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
```

> 註：WHERE / ORDER BY 採用「黑名單字元」防呆已足，因為查詢服務僅供 DBA 內部使用（非對外輸入）。若日後需更嚴格可改成 token whitelist。

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingQueryServiceTests"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/IReportingQueryService.cs \
        src/MoldplanDbSwitcher/Services/ReportingQueryService.cs \
        tests/MoldplanDbSwitcher.Tests/Services/ReportingQueryServiceTests.cs
git commit -m "feat: 新增 ReportingQueryService 提供寬表 Top N 查詢"
```

---

### Task 7: ReportingDeployService

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IReportingDeployService.cs`
- Create: `src/MoldplanDbSwitcher/Services/ReportingDeployService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ReportingDeployServiceTests.cs`

- [ ] **Step 1: 寫失敗測試（端對端：跑 01_Schema 後驗證 SchemaExists）**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/ReportingDeployServiceTests.cs
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Tests.TestHelpers;
using System.IO;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

[Trait("Category", "Integration")]
public class ReportingDeployServiceTests : IClassFixture<LocalDbFixture>, IDisposable
{
    private readonly LocalDbFixture _db;
    private readonly string _scriptsDir;

    public ReportingDeployServiceTests(LocalDbFixture db)
    {
        _db = db;
        _scriptsDir = Path.Combine(Path.GetTempPath(), "rds_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_scriptsDir);
        File.WriteAllText(Path.Combine(_scriptsDir, "01_Reporting_Create_Schema.sql"),
            "IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');\nGO");
    }

    public void Dispose() { if (Directory.Exists(_scriptsDir)) Directory.Delete(_scriptsDir, true); }

    [Fact]
    public async Task DeploySchema_CreatesReportingSchema()
    {
        var provider = new ReportingScriptProvider(_scriptsDir);
        var executor = new SqlBatchExecutor();
        var objectSvc = new ReportingObjectService(_db.ConnectionString);
        var sut = new ReportingDeployService(_db.ConnectionString, provider, executor);

        var step = await sut.DeploySchemaAsync();

        Assert.Equal(DeployStatus.Success, step.Status);
        Assert.True(await objectSvc.SchemaExistsAsync());
    }

    [Fact]
    public async Task DropAllAsync_WrongConfirmName_Throws()
    {
        var provider = new ReportingScriptProvider(_scriptsDir);
        var sut = new ReportingDeployService(_db.ConnectionString, provider, new SqlBatchExecutor());
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => sut.DropAllAsync(confirmDatabaseName: "wrong-name"));
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingDeployServiceTests"`
Expected: FAIL

- [ ] **Step 3: Interface + 實作**

```csharp
// src/MoldplanDbSwitcher/Services/IReportingDeployService.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IReportingDeployService
{
    Task<DeployStep> DeploySchemaAsync(IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DeployTablesAsync(IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DeployViewsAsync(IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DeployProceduresAsync(IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DeployJobAsync(int fileNumber, string databaseName, string jobOwner, IProgress<DeployStep>? progress = null, CancellationToken ct = default);
    Task<DeployStep> DropAllAsync(string confirmDatabaseName, IProgress<DeployStep>? progress = null, CancellationToken ct = default);
}
```

```csharp
// src/MoldplanDbSwitcher/Services/ReportingDeployService.cs
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
```

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingDeployServiceTests"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/IReportingDeployService.cs \
        src/MoldplanDbSwitcher/Services/ReportingDeployService.cs \
        tests/MoldplanDbSwitcher.Tests/Services/ReportingDeployServiceTests.cs
git commit -m "feat: 新增 ReportingDeployService 部署 Reporting 物件"
```

---

## Phase 2：AppSettings 擴充 + ViewModels

### Task 8: AppSettings 新增 MoldPlanScriptsPath

**Files:**
- Modify: `src/MoldplanDbSwitcher/Models/AppSettings.cs`
- Modify: `src/MoldplanDbSwitcher/Services/AppSettingsService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/AppSettingsServiceTests.cs`（既有）

- [ ] **Step 1: 先讀現有 AppSettings.cs 與 AppSettingsService.cs，了解結構**

Run: `cat src/MoldplanDbSwitcher/Models/AppSettings.cs src/MoldplanDbSwitcher/Services/AppSettingsService.cs`

- [ ] **Step 2: 寫測試（環境變數 fallback）**

加入下列測試到 `AppSettingsServiceTests.cs`：

```csharp
[Fact]
public void GetMoldPlanScriptsPath_EnvVarSet_UsesEnvVar()
{
    var temp = Path.Combine(Path.GetTempPath(), "mp_" + Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(Path.Combine(temp, "docs", "scripts", "Reporting"));
    try
    {
        Environment.SetEnvironmentVariable("MOLDPLAN_REPO", temp);
        var sut = new AppSettingsService(Path.Combine(_tempDir, "settings.json"));
        var path = sut.GetMoldPlanScriptsPath();
        Assert.Equal(Path.Combine(temp, "docs", "scripts", "Reporting"), path);
    }
    finally
    {
        Environment.SetEnvironmentVariable("MOLDPLAN_REPO", null);
        if (Directory.Exists(temp)) Directory.Delete(temp, true);
    }
}

[Fact]
public void GetMoldPlanScriptsPath_SettingsOverride_TakesPrecedence()
{
    var sut = new AppSettingsService(Path.Combine(_tempDir, "settings.json"));
    sut.Save(new AppSettings { MoldPlanScriptsPath = @"C:\custom\path" });
    Assert.Equal(@"C:\custom\path", sut.GetMoldPlanScriptsPath());
}
```

- [ ] **Step 3: 擴充 AppSettings**

加到 `AppSettings.cs`：
```csharp
public string? MoldPlanScriptsPath { get; set; }
```

加到 `IAppSettingsService.cs`：
```csharp
string GetMoldPlanScriptsPath();
```

加到 `AppSettingsService.cs`：
```csharp
private const string DefaultScriptsRelative = @"docs\scripts\Reporting";
private const string FallbackAbsolute = @"D:\Repos\MoldPlan-Workspace\docs\scripts\Reporting";

public string GetMoldPlanScriptsPath()
{
    var settings = Load();
    if (!string.IsNullOrWhiteSpace(settings.MoldPlanScriptsPath))
        return settings.MoldPlanScriptsPath;

    var envRepo = Environment.GetEnvironmentVariable("MOLDPLAN_REPO");
    if (!string.IsNullOrWhiteSpace(envRepo))
        return Path.Combine(envRepo, DefaultScriptsRelative);

    return FallbackAbsolute;
}
```

- [ ] **Step 4: 跑測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "AppSettingsServiceTests"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: AppSettings 新增 MoldPlanScriptsPath（環境變數 fallback）"
```

---

### Task 9: ReportingQueryViewModel

**Files:**
- Create: `src/MoldplanDbSwitcher/ViewModels/ReportingQueryViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingQueryViewModelTests.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
// tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingQueryViewModelTests.cs
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ReportingQueryViewModelTests
{
    [Fact]
    public async Task LoadObjectsAsync_PopulatesGroupedNodes()
    {
        var objectSvc = Substitute.For<IReportingObjectService>();
        var querySvc = Substitute.For<IReportingQueryService>();
        objectSvc.ListTablesAsync(Arg.Any<CancellationToken>())
            .Returns(new List<ReportingObject> {
                new("Reporting", "SalesOrderRowData", ReportingObjectKind.BaseTable, null),
                new("Reporting", "RefreshLog", ReportingObjectKind.SystemTable, null)
            });
        objectSvc.ListViewsAsync(Arg.Any<CancellationToken>())
            .Returns(new List<ReportingObject> {
                new("Reporting", "SalesOrderRowDataView", ReportingObjectKind.View, null)
            });
        objectSvc.ListProceduresAsync(Arg.Any<CancellationToken>())
            .Returns(new List<ReportingObject>());

        var vm = new ReportingQueryViewModel(objectSvc, querySvc);
        await vm.LoadObjectsCommand.ExecuteAsync(null);

        Assert.Equal(3, vm.Objects.Count);
        Assert.Contains(vm.Objects, o => o.Name == "SalesOrderRowData");
    }

    [Fact]
    public async Task QueryAsync_PopulatesGrid()
    {
        var objectSvc = Substitute.For<IReportingObjectService>();
        var querySvc = Substitute.For<IReportingQueryService>();
        querySvc.QueryTopNAsync("T1", 100, null, null, Arg.Any<CancellationToken>())
            .Returns(new QueryResult(new[] { "Id", "Name" },
                new List<IReadOnlyList<object?>> { new object?[] { 1, "a" } }));

        var vm = new ReportingQueryViewModel(objectSvc, querySvc)
        {
            SelectedObject = new ReportingObject("Reporting", "T1", ReportingObjectKind.BaseTable, null),
            TopN = 100
        };
        await vm.QueryCommand.ExecuteAsync(null);

        Assert.Equal(2, vm.ResultColumns.Count);
        Assert.Single(vm.ResultRows);
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingQueryViewModelTests"`
Expected: FAIL

- [ ] **Step 3: 實作 ViewModel**

```csharp
// src/MoldplanDbSwitcher/ViewModels/ReportingQueryViewModel.cs
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportingQueryViewModel : ObservableObject
{
    private readonly IReportingObjectService _objects;
    private readonly IReportingQueryService _query;

    public ReportingQueryViewModel(IReportingObjectService objects, IReportingQueryService query)
    {
        _objects = objects;
        _query = query;
    }

    public ObservableCollection<ReportingObject> Objects { get; } = new();
    public ObservableCollection<string> ResultColumns { get; } = new();
    public ObservableCollection<IReadOnlyList<object?>> ResultRows { get; } = new();
    public ObservableCollection<ReportingColumn> SelectedColumns { get; } = new();
    public ObservableCollection<RefreshLogEntry> RefreshLog { get; } = new();

    [ObservableProperty] private ReportingObject? _selectedObject;
    [ObservableProperty] private int _topN = 100;
    [ObservableProperty] private string? _whereClause;
    [ObservableProperty] private string? _orderByClause;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _errorMessage;

    partial void OnSelectedObjectChanged(ReportingObject? value)
    {
        _ = LoadObjectDetailAsync(value);
    }

    [RelayCommand]
    private async Task LoadObjectsAsync()
    {
        try
        {
            IsBusy = true;
            Objects.Clear();
            foreach (var o in await _objects.ListTablesAsync()) Objects.Add(o);
            foreach (var o in await _objects.ListViewsAsync()) Objects.Add(o);
            foreach (var o in await _objects.ListProceduresAsync()) Objects.Add(o);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task QueryAsync()
    {
        if (SelectedObject == null) return;
        try
        {
            IsBusy = true;
            ErrorMessage = null;
            var result = await _query.QueryTopNAsync(SelectedObject.Name, TopN, WhereClause, OrderByClause);
            ResultColumns.Clear();
            foreach (var c in result.Columns) ResultColumns.Add(c);
            ResultRows.Clear();
            foreach (var r in result.Rows) ResultRows.Add(r);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    private async Task LoadObjectDetailAsync(ReportingObject? obj)
    {
        SelectedColumns.Clear();
        RefreshLog.Clear();
        if (obj == null) return;
        try
        {
            foreach (var c in await _objects.GetColumnsAsync(obj.Name)) SelectedColumns.Add(c);
            if (obj.Kind != ReportingObjectKind.SystemTable && obj.Kind != ReportingObjectKind.Procedure)
                foreach (var l in await _objects.GetRefreshLogAsync(obj.Name)) RefreshLog.Add(l);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
    }
}
```

- [ ] **Step 4: 跑測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingQueryViewModelTests"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: 新增 ReportingQueryViewModel"
```

---

### Task 10: ReportingDeployViewModel

**Files:**
- Create: `src/MoldplanDbSwitcher/ViewModels/ReportingDeployViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingDeployViewModelTests.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
// tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingDeployViewModelTests.cs
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ReportingDeployViewModelTests
{
    private static ReportingDeployViewModel CreateSut(
        IReportingObjectService? objects = null,
        IReportingDeployService? deploy = null)
    {
        objects ??= Substitute.For<IReportingObjectService>();
        deploy ??= Substitute.For<IReportingDeployService>();
        return new ReportingDeployViewModel(objects, deploy, targetDatabaseName: "MoldPlan");
    }

    [Fact]
    public async Task ScanEnvironmentAsync_PopulatesStatus()
    {
        var objects = Substitute.For<IReportingObjectService>();
        objects.SchemaExistsAsync(Arg.Any<CancellationToken>()).Returns(true);
        objects.ListTablesAsync(Arg.Any<CancellationToken>())
            .Returns(new List<ReportingObject> {
                new("Reporting", "T1", ReportingObjectKind.BaseTable, null)
            });
        var sut = CreateSut(objects);

        await sut.ScanEnvironmentCommand.ExecuteAsync(null);

        Assert.True(sut.SchemaExists);
        Assert.Equal(1, sut.TableCount);
    }

    [Fact]
    public async Task DeployAllAsync_RunsAllSteps()
    {
        var deploy = Substitute.For<IReportingDeployService>();
        deploy.DeploySchemaAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>())
            .Returns(new DeployStep("01.sql", "schema", DeployStatus.Success, null));
        deploy.DeployTablesAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>())
            .Returns(new DeployStep("02.sql", "tables", DeployStatus.Success, null));
        deploy.DeployViewsAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>())
            .Returns(new DeployStep("03.sql", "views", DeployStatus.Success, null));
        deploy.DeployProceduresAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>())
            .Returns(new DeployStep("04.sql", "sp", DeployStatus.Success, null));
        var sut = CreateSut(deploy: deploy);

        await sut.DeployAllCommand.ExecuteAsync(null);

        Assert.Equal(4, sut.Steps.Count);
        Assert.All(sut.Steps, s => Assert.Equal(DeployStatus.Success, s.Status));
    }

    [Fact]
    public async Task DeployAllAsync_StopsOnFailure()
    {
        var deploy = Substitute.For<IReportingDeployService>();
        deploy.DeploySchemaAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>())
            .Returns(new DeployStep("01.sql", "schema", DeployStatus.Failed, "boom"));
        var sut = CreateSut(deploy: deploy);

        await sut.DeployAllCommand.ExecuteAsync(null);

        Assert.Single(sut.Steps);
        await deploy.DidNotReceive().DeployTablesAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>());
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingDeployViewModelTests"`
Expected: FAIL

- [ ] **Step 3: 實作 ViewModel**

```csharp
// src/MoldplanDbSwitcher/ViewModels/ReportingDeployViewModel.cs
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportingDeployViewModel : ObservableObject
{
    private readonly IReportingObjectService _objects;
    private readonly IReportingDeployService _deploy;

    public ReportingDeployViewModel(
        IReportingObjectService objects, IReportingDeployService deploy, string targetDatabaseName)
    {
        _objects = objects;
        _deploy = deploy;
        TargetDatabaseName = targetDatabaseName;
        JobOwner = "sa";
    }

    public ObservableCollection<DeployStep> Steps { get; } = new();

    [ObservableProperty] private string _targetDatabaseName;
    [ObservableProperty] private string _jobOwner;
    [ObservableProperty] private bool _schemaExists;
    [ObservableProperty] private int _tableCount;
    [ObservableProperty] private int _viewCount;
    [ObservableProperty] private int _procedureCount;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _errorMessage;

    [RelayCommand]
    private async Task ScanEnvironmentAsync()
    {
        try
        {
            IsBusy = true;
            SchemaExists = await _objects.SchemaExistsAsync();
            TableCount = (await _objects.ListTablesAsync()).Count;
            ViewCount = (await _objects.ListViewsAsync()).Count;
            ProcedureCount = (await _objects.ListProceduresAsync()).Count;
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task DeployAllAsync()
    {
        Steps.Clear();
        IsBusy = true;
        try
        {
            var progress = new Progress<DeployStep>(s => Steps.Add(s));
            var schema = await _deploy.DeploySchemaAsync();
            Steps.Add(schema);
            if (schema.Status != DeployStatus.Success) return;

            var tables = await _deploy.DeployTablesAsync();
            Steps.Add(tables);
            if (tables.Status != DeployStatus.Success) return;

            var views = await _deploy.DeployViewsAsync();
            Steps.Add(views);
            if (views.Status != DeployStatus.Success) return;

            var sp = await _deploy.DeployProceduresAsync();
            Steps.Add(sp);
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task DeployDailyJobAsync()
    {
        IsBusy = true;
        try
        {
            var step = await _deploy.DeployJobAsync(5, TargetDatabaseName, JobOwner);
            Steps.Add(step);
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task DeployHourlyJobAsync()
    {
        IsBusy = true;
        try
        {
            var step = await _deploy.DeployJobAsync(6, TargetDatabaseName, JobOwner);
            Steps.Add(step);
        }
        finally { IsBusy = false; }
    }

    public async Task DropAllAsync(string confirmName)
    {
        IsBusy = true;
        try
        {
            var step = await _deploy.DropAllAsync(confirmName);
            Steps.Add(step);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }
}
```

- [ ] **Step 4: 跑測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingDeployViewModelTests"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: 新增 ReportingDeployViewModel"
```

---

## Phase 3：View 與整合

### Task 11: ReportingQueryPage View

**Files:**
- Create: `src/MoldplanDbSwitcher/Views/ReportingQueryPage.axaml`
- Create: `src/MoldplanDbSwitcher/Views/ReportingQueryPage.axaml.cs`

- [ ] **Step 1: 建立 UserControl AXAML**

```xml
<!-- src/MoldplanDbSwitcher/Views/ReportingQueryPage.axaml -->
<UserControl xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:vm="using:MoldplanDbSwitcher.ViewModels"
             x:Class="MoldplanDbSwitcher.Views.ReportingQueryPage"
             x:DataType="vm:ReportingQueryViewModel">
  <Grid ColumnDefinitions="280,*" Margin="8">
    <DockPanel Grid.Column="0">
      <Button DockPanel.Dock="Top" Content="重新整理"
              Command="{Binding LoadObjectsCommand}" Margin="0,0,0,8" />
      <ListBox ItemsSource="{Binding Objects}"
               SelectedItem="{Binding SelectedObject}">
        <ListBox.ItemTemplate>
          <DataTemplate>
            <StackPanel Orientation="Horizontal" Spacing="6">
              <TextBlock Text="{Binding Kind}" FontSize="10" Foreground="Gray" />
              <TextBlock Text="{Binding Name}" />
            </StackPanel>
          </DataTemplate>
        </ListBox.ItemTemplate>
      </ListBox>
    </DockPanel>

    <DockPanel Grid.Column="1" Margin="8,0,0,0">
      <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Spacing="8" Margin="0,0,0,8">
        <TextBlock Text="Top:" VerticalAlignment="Center" />
        <NumericUpDown Value="{Binding TopN}" Minimum="1" Maximum="10000" Width="100" />
        <TextBlock Text="WHERE:" VerticalAlignment="Center" />
        <TextBox Text="{Binding WhereClause}" Width="200" Watermark="可空白" />
        <TextBlock Text="ORDER BY:" VerticalAlignment="Center" />
        <TextBox Text="{Binding OrderByClause}" Width="150" Watermark="可空白" />
        <Button Content="查詢" Command="{Binding QueryCommand}" />
      </StackPanel>
      <TextBlock DockPanel.Dock="Top" Text="{Binding ErrorMessage}"
                 Foreground="Red" IsVisible="{Binding ErrorMessage, Converter={x:Static StringConverters.IsNotNullOrEmpty}}" />
      <TabControl>
        <TabItem Header="預覽">
          <DataGrid ItemsSource="{Binding ResultRows}" IsReadOnly="True" AutoGenerateColumns="False" />
        </TabItem>
        <TabItem Header="欄位">
          <DataGrid ItemsSource="{Binding SelectedColumns}" IsReadOnly="True" AutoGenerateColumns="True" />
        </TabItem>
        <TabItem Header="RefreshLog">
          <DataGrid ItemsSource="{Binding RefreshLog}" IsReadOnly="True" AutoGenerateColumns="True" />
        </TabItem>
      </TabControl>
    </DockPanel>
  </Grid>
</UserControl>
```

> 註：`ResultRows` 是動態欄位，需在 code-behind 監聽 `ResultColumns.CollectionChanged` 動態加 `DataGridTextColumn`（DataGrid 不支援純綁定動態欄位）。

- [ ] **Step 2: code-behind 處理動態欄位**

```csharp
// src/MoldplanDbSwitcher/Views/ReportingQueryPage.axaml.cs
using System.Collections.Specialized;
using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ReportingQueryPage : UserControl
{
    private DataGrid? _resultGrid;

    public ReportingQueryPage()
    {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    private void OnDataContextChanged(object? sender, EventArgs e)
    {
        _resultGrid ??= this.FindControl<TabControl>("ResultTabs")?
            .GetVisualDescendants().OfType<DataGrid>().FirstOrDefault();
        if (DataContext is ReportingQueryViewModel vm)
        {
            vm.ResultColumns.CollectionChanged += (_, _) => RebuildColumns(vm);
            RebuildColumns(vm);
        }
    }

    private void RebuildColumns(ReportingQueryViewModel vm)
    {
        var grid = this.GetVisualDescendants().OfType<DataGrid>().FirstOrDefault(g => g.ItemsSource == vm.ResultRows);
        if (grid == null) return;
        grid.Columns.Clear();
        for (var i = 0; i < vm.ResultColumns.Count; i++)
        {
            var idx = i;
            grid.Columns.Add(new DataGridTextColumn
            {
                Header = vm.ResultColumns[i],
                Binding = new Avalonia.Data.Binding($"[{idx}]")
            });
        }
    }
}
```

- [ ] **Step 3: 編譯**

Run: `dotnet build src/MoldplanDbSwitcher/`
Expected: 0 error

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Views/ReportingQueryPage.axaml \
        src/MoldplanDbSwitcher/Views/ReportingQueryPage.axaml.cs
git commit -m "feat: 新增 Reporting 查詢頁 View"
```

---

### Task 12: ReportingDeployPage View + Drop Confirm Dialog

**Files:**
- Create: `src/MoldplanDbSwitcher/Views/ReportingDeployPage.axaml` (+ .cs)
- Create: `src/MoldplanDbSwitcher/Views/DropConfirmDialog.axaml` (+ .cs)
- Create: `src/MoldplanDbSwitcher/ViewModels/DropConfirmDialogViewModel.cs`

- [ ] **Step 1: Drop 確認對話框 ViewModel**

```csharp
// src/MoldplanDbSwitcher/ViewModels/DropConfirmDialogViewModel.cs
using CommunityToolkit.Mvvm.ComponentModel;

namespace MoldplanDbSwitcher.ViewModels;

public partial class DropConfirmDialogViewModel : ObservableObject
{
    public string TargetDatabase { get; }
    public DropConfirmDialogViewModel(string targetDatabase) { TargetDatabase = targetDatabase; }

    [ObservableProperty] private string _typedName = "";
    public bool CanConfirm => string.Equals(TypedName, TargetDatabase, StringComparison.OrdinalIgnoreCase);

    partial void OnTypedNameChanged(string value) => OnPropertyChanged(nameof(CanConfirm));
}
```

- [ ] **Step 2: DropConfirmDialog AXAML**

```xml
<!-- src/MoldplanDbSwitcher/Views/DropConfirmDialog.axaml -->
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:MoldplanDbSwitcher.ViewModels"
        x:Class="MoldplanDbSwitcher.Views.DropConfirmDialog"
        x:DataType="vm:DropConfirmDialogViewModel"
        Title="⚠️ 確認移除 Reporting 物件"
        Width="500" Height="240"
        WindowStartupLocation="CenterOwner">
  <StackPanel Margin="16" Spacing="12">
    <TextBlock TextWrapping="Wrap" Foreground="Red"
               Text="此操作將完整移除 Reporting schema 及所有相依物件（Table / View / SP / Agent Job / RefreshLog）。無法復原！" />
    <TextBlock>
      <Run Text="請輸入目標資料庫名稱「" />
      <Run Text="{Binding TargetDatabase}" FontWeight="Bold" />
      <Run Text="」以確認：" />
    </TextBlock>
    <TextBox Text="{Binding TypedName}" />
    <StackPanel Orientation="Horizontal" Spacing="8" HorizontalAlignment="Right">
      <Button Content="取消" Click="OnCancel" />
      <Button Content="確認移除" Background="Crimson" Foreground="White"
              IsEnabled="{Binding CanConfirm}" Click="OnConfirm" />
    </StackPanel>
  </StackPanel>
</Window>
```

- [ ] **Step 3: DropConfirmDialog code-behind**

```csharp
// src/MoldplanDbSwitcher/Views/DropConfirmDialog.axaml.cs
using Avalonia.Controls;
using Avalonia.Markup.Xaml;

namespace MoldplanDbSwitcher.Views;

public partial class DropConfirmDialog : Window
{
    public DropConfirmDialog() => AvaloniaXamlLoader.Load(this);

    private void OnCancel(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close(false);
    private void OnConfirm(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close(true);
}
```

- [ ] **Step 4: ReportingDeployPage AXAML**

```xml
<!-- src/MoldplanDbSwitcher/Views/ReportingDeployPage.axaml -->
<UserControl xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:vm="using:MoldplanDbSwitcher.ViewModels"
             x:Class="MoldplanDbSwitcher.Views.ReportingDeployPage"
             x:DataType="vm:ReportingDeployViewModel">
  <DockPanel Margin="8">
    <!-- 環境掃描 -->
    <Border DockPanel.Dock="Top" BorderBrush="Gray" BorderThickness="1" Padding="8" Margin="0,0,0,8">
      <StackPanel Orientation="Horizontal" Spacing="16">
        <TextBlock Text="{Binding TargetDatabaseName, StringFormat='目標 DB: {0}'}" FontWeight="Bold" />
        <TextBlock Text="{Binding SchemaExists, StringFormat='Schema: {0}'}" />
        <TextBlock Text="{Binding TableCount, StringFormat='Tables: {0}'}" />
        <TextBlock Text="{Binding ViewCount, StringFormat='Views: {0}'}" />
        <TextBlock Text="{Binding ProcedureCount, StringFormat='SP: {0}'}" />
        <Button Content="重新掃描" Command="{Binding ScanEnvironmentCommand}" />
      </StackPanel>
    </Border>

    <!-- 操作按鈕 -->
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Spacing="8" Margin="0,0,0,8">
      <Button Content="部署全部 (01→04)" Command="{Binding DeployAllCommand}" />
      <Button Content="部署 Daily Job (05)" Command="{Binding DeployDailyJobCommand}" />
      <Button Content="部署 Hourly Job (06)" Command="{Binding DeployHourlyJobCommand}" />
      <TextBlock Text="Job Owner:" VerticalAlignment="Center" Margin="16,0,0,0" />
      <TextBox Text="{Binding JobOwner}" Width="120" />
      <Button Content="⚠ 移除全部 (98)" Background="Crimson" Foreground="White"
              Click="OnDropAllClick" />
    </StackPanel>

    <!-- 執行 log -->
    <DataGrid ItemsSource="{Binding Steps}" IsReadOnly="True" AutoGenerateColumns="True" />
  </DockPanel>
</UserControl>
```

- [ ] **Step 5: ReportingDeployPage code-behind（Drop 流程開對話框）**

```csharp
// src/MoldplanDbSwitcher/Views/ReportingDeployPage.axaml.cs
using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ReportingDeployPage : UserControl
{
    public ReportingDeployPage() => AvaloniaXamlLoader.Load(this);

    private async void OnDropAllClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not ReportingDeployViewModel vm) return;
        var dialog = new DropConfirmDialog
        {
            DataContext = new DropConfirmDialogViewModel(vm.TargetDatabaseName)
        };
        var owner = TopLevel.GetTopLevel(this) as Window;
        if (owner == null) return;
        var ok = await dialog.ShowDialog<bool>(owner);
        if (ok) await vm.DropAllAsync(vm.TargetDatabaseName);
    }
}
```

- [ ] **Step 6: 編譯 + Commit**

Run: `dotnet build src/MoldplanDbSwitcher/`
Expected: 0 error

```bash
git add -A
git commit -m "feat: 新增 Reporting 部署頁 View 與 Drop 確認對話框"
```

---

### Task 13: MainWindow 改為 TabControl

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`

- [ ] **Step 1: 讀現有 MainWindow.axaml 與 MainWindowViewModel.cs**

Run: `cat src/MoldplanDbSwitcher/Views/MainWindow.axaml src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`

- [ ] **Step 2: MainWindowViewModel 暴露兩個 child VM**

加入到 `MainWindowViewModel.cs`：

```csharp
public ReportingQueryViewModel ReportingQuery { get; }
public ReportingDeployViewModel ReportingDeploy { get; }
```

並調整建構式（保留現有依賴）：

```csharp
public MainWindowViewModel(
    // ... existing dependencies ...
    ReportingQueryViewModel reportingQuery,
    ReportingDeployViewModel reportingDeploy)
{
    // ... existing init ...
    ReportingQuery = reportingQuery;
    ReportingDeploy = reportingDeploy;
}
```

- [ ] **Step 3: MainWindow.axaml 包進 TabControl**

把 `<DockPanel Margin="16">` 整個內容包成第一個 TabItem，新增兩個 TabItem：

```xml
<TabControl Margin="16">
  <TabItem Header="連線切換">
    <!-- 原本 DockPanel 的內容（Menu + 篩選 + 列表）整段搬進來 -->
  </TabItem>
  <TabItem Header="Reporting 查詢">
    <views:ReportingQueryPage DataContext="{Binding ReportingQuery}" />
  </TabItem>
  <TabItem Header="Reporting 部署">
    <views:ReportingDeployPage DataContext="{Binding ReportingDeploy}" />
  </TabItem>
</TabControl>
```

並在 `Window` 開頭加 `xmlns:views="using:MoldplanDbSwitcher.Views"`，視窗尺寸調整為 `Width="900" Height="650"`。

- [ ] **Step 4: 編譯**

Run: `dotnet build src/MoldplanDbSwitcher/`
Expected: 0 error

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: MainWindow 改為 TabControl 三分頁"
```

---

### Task 14: DI 註冊 + SettingsDialog 新增腳本路徑欄位

**Files:**
- Modify: `src/MoldplanDbSwitcher/Program.cs`
- Modify: `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml`

- [ ] **Step 1: Program.cs 註冊新 Services 與 ViewModels**

加到 DI container 設定區（依當前選定的連線取得連線字串。若 MainWindow 啟動時尚未選連線，先注入 placeholder，由 ViewModel 在選定後重建 — 為了避免複雜化，建議改用 `Func<ConnectionProfile, IReportingQueryService>` factory 模式）：

```csharp
services.AddSingleton<IReportingScriptProvider>(sp =>
    new ReportingScriptProvider(sp.GetRequiredService<IAppSettingsService>().GetMoldPlanScriptsPath()));
services.AddSingleton<ISqlBatchExecutor, SqlBatchExecutor>();

services.AddTransient<Func<string, IReportingObjectService>>(_ => connStr => new ReportingObjectService(connStr));
services.AddTransient<Func<string, IReportingQueryService>>(_ => connStr => new ReportingQueryService(connStr));
services.AddTransient<Func<string, IReportingDeployService>>(sp => connStr =>
    new ReportingDeployService(connStr,
        sp.GetRequiredService<IReportingScriptProvider>(),
        sp.GetRequiredService<ISqlBatchExecutor>()));

services.AddSingleton<ReportingQueryViewModel>(sp =>
{
    var factory = sp.GetRequiredService<ISqlConnectionFactory>();
    var settings = sp.GetRequiredService<ISettingsService>();
    // 用第一個連線；MainWindow 切換時 ViewModel 內部要支援切換連線
    var profile = settings.LoadConnections().FirstOrDefault();
    var connStr = profile != null ? factory.Create(profile).ConnectionString : "";
    return new ReportingQueryViewModel(
        sp.GetRequiredService<Func<string, IReportingObjectService>>()(connStr),
        sp.GetRequiredService<Func<string, IReportingQueryService>>()(connStr));
});

services.AddSingleton<ReportingDeployViewModel>(sp =>
{
    var factory = sp.GetRequiredService<ISqlConnectionFactory>();
    var settings = sp.GetRequiredService<ISettingsService>();
    var profile = settings.LoadConnections().FirstOrDefault();
    var connStr = profile != null ? factory.Create(profile).ConnectionString : "";
    return new ReportingDeployViewModel(
        sp.GetRequiredService<Func<string, IReportingObjectService>>()(connStr),
        sp.GetRequiredService<Func<string, IReportingDeployService>>()(connStr),
        profile?.Database ?? "");
});
```

> ⚠️ 注意：依現有 `MainWindowViewModel` 連線切換邏輯，ReportingQueryViewModel/ReportingDeployViewModel 需要能「切換連線」。若直接綁定首個連線會限制使用情境，建議下一個 Task 15 補上「切換連線時通知 Reporting VM 重建」機制（詳見 Task 15）。

- [ ] **Step 2: SettingsDialog.axaml 新增腳本路徑欄位**

在現有設定欄位之後新增：

```xml
<TextBlock Text="MoldPlan 腳本路徑：" Margin="0,8,0,4" />
<TextBox Text="{Binding MoldPlanScriptsPath}" Watermark="預設讀 MOLDPLAN_REPO 環境變數" />
<TextBlock Text="留白時將自動使用環境變數 MOLDPLAN_REPO\docs\scripts\Reporting"
           FontSize="10" Foreground="Gray" />
```

並在 `SettingsDialogViewModel`（若有；若沒有就在 dialog code-behind）暴露 `MoldPlanScriptsPath` 屬性綁定到 `AppSettings.MoldPlanScriptsPath`。

- [ ] **Step 3: 編譯**

Run: `dotnet build src/MoldplanDbSwitcher/`
Expected: 0 error

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: DI 註冊 Reporting 服務並在設定加入腳本路徑欄位"
```

---

### Task 15: 連線切換通知 Reporting VM 重建連線字串

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/ReportingQueryViewModel.cs`
- Modify: `src/MoldplanDbSwitcher/ViewModels/ReportingDeployViewModel.cs`
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingQueryViewModelTests.cs`

- [ ] **Step 1: 寫測試（切換連線後重新建立 Service）**

```csharp
[Fact]
public async Task UseConnection_SwapsServices_AndReloads()
{
    var calls = new List<string>();
    Func<string, IReportingObjectService> oFactory = cs =>
    {
        calls.Add($"obj:{cs}");
        var s = Substitute.For<IReportingObjectService>();
        s.ListTablesAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        s.ListViewsAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        s.ListProceduresAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        return s;
    };
    Func<string, IReportingQueryService> qFactory = cs => Substitute.For<IReportingQueryService>();

    var vm = new ReportingQueryViewModel(oFactory, qFactory, initialConnectionString: "first");
    await vm.UseConnectionAsync("second");

    Assert.Contains("obj:first", calls);
    Assert.Contains("obj:second", calls);
}
```

- [ ] **Step 2: 改 ReportingQueryViewModel 建構式接受 factory**

```csharp
public partial class ReportingQueryViewModel : ObservableObject
{
    private readonly Func<string, IReportingObjectService> _objectsFactory;
    private readonly Func<string, IReportingQueryService> _queryFactory;
    private IReportingObjectService _objects;
    private IReportingQueryService _query;

    public ReportingQueryViewModel(
        Func<string, IReportingObjectService> objectsFactory,
        Func<string, IReportingQueryService> queryFactory,
        string initialConnectionString)
    {
        _objectsFactory = objectsFactory;
        _queryFactory = queryFactory;
        _objects = objectsFactory(initialConnectionString);
        _query = queryFactory(initialConnectionString);
    }

    public async Task UseConnectionAsync(string connectionString)
    {
        _objects = _objectsFactory(connectionString);
        _query = _queryFactory(connectionString);
        Objects.Clear();
        ResultColumns.Clear();
        ResultRows.Clear();
        await LoadObjectsAsync();
    }

    // ... 既有 commands 改為 call _objects / _query ...
}
```

> Task 9 既有測試也要同步更新（建立 VM 時用 factory 包裝 mock）。

- [ ] **Step 3: ReportingDeployViewModel 同步改為 factory 注入**

加入：

```csharp
public async Task UseConnectionAsync(string connectionString, string databaseName)
{
    _objects = _objectsFactory(connectionString);
    _deploy = _deployFactory(connectionString);
    TargetDatabaseName = databaseName;
    await ScanEnvironmentAsync();
}
```

- [ ] **Step 4: MainWindowViewModel 監聽 SelectedConnection 變更**

```csharp
partial void OnSelectedConnectionChanged(ConnectionProfile? value)
{
    if (value == null) return;
    var connStr = _connectionFactory.Create(value).ConnectionString;
    _ = ReportingQuery.UseConnectionAsync(connStr);
    _ = ReportingDeploy.UseConnectionAsync(connStr, value.Database);
}
```

（依據既有 MainWindowViewModel 內 SelectedConnection 屬性名稱微調）

- [ ] **Step 5: 跑全部測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: 全部 PASS

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: Reporting VM 跟隨選定連線即時切換"
```

---

## Phase 4：端對端驗證

### Task 16: 手動驗證

**Files:** （無新增）

- [ ] **Step 1: 在本機建立一個測試資料庫**

```sql
-- SSMS 連到本機 SQL Server
CREATE DATABASE MoldplanReportingTest;
```

- [ ] **Step 2: 把該 DB 加入 MoldplanDbSwitcher 的自訂連線清單**

啟動 App → 自訂連線 → 新增

- [ ] **Step 3: 啟動 App，切換到「Reporting 部署」頁**

Run: `dotnet run --project src/MoldplanDbSwitcher/`

- [ ] **Step 4: 點「部署全部 (01→04)」**

預期 4 個 Step 都 Success。切到 SSMS 確認 `MoldplanReportingTest` 已有 `Reporting` schema、14 張 Table、13 個 View、13 個 SP。

- [ ] **Step 5: 切到「Reporting 查詢」頁**

預期左側列表能看到所有物件，選一個 base table → 點查詢 → 預覽分頁應為空（無資料但欄位 schema 對）。

- [ ] **Step 6: 測試 Drop**

回到部署頁 → 點「⚠ 移除全部 (98)」→ 對話框出現 → 輸入錯名 → 確認鈕應停用 → 改打對名稱 → 確認 → 預期 Reporting schema 被移除。

- [ ] **Step 7: 清理測試 DB**

```sql
DROP DATABASE MoldplanReportingTest;
```

- [ ] **Step 8: 整合測試全跑一次**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: 全部 PASS

- [ ] **Step 9: Commit（若有手動測試發現的 bug fix）**

```bash
git add -A
git commit -m "fix: 手動驗證後修正 Reporting 流程細節"
```

---

## Self-Review Notes

- **Spec coverage**：模組 A 全 View/Table 查詢（Task 6、9、11）；模組 B 建立 Table/View/SP/Job（Task 7、10、12）；防呆 Drop（Task 12）；連線切換整合（Task 15）。
- **未涵蓋（刻意延後）**：CSV 匯出、選擇性「只重建單一物件」進階流程、Agent Job 權限不足 UX 處理。建議列為 v2。
- **跨平台**：所有 SQL 流程透過 Microsoft.Data.SqlClient，macOS / Linux 可執行；Agent Job 依賴 msdb（Windows SQL Server），但 UI 全平台顯示（依設定決策）。
- **TDD 紀律**：所有 Service 與 ViewModel 皆先寫測試後實作；View 為手動驗證（Avalonia UI 測試成本過高）。
