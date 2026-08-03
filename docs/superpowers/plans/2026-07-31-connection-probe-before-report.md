# 報表匯出前的連線預檢 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 匯出報表前平行探測所有連線，連不通的直接跳過，不再為每個不通的連線各付一次 10 秒的連線 timeout。

**Architecture:** 新增 `IConnectionProbeService`，在 ViewModel 兩個匯出流程中、連線篩選之後查詢之前插入預檢。探測只做 `OpenAsync`，不下查詢。單一連線的可達性測試抽成 `IConnectionTester`，讓平行探測與分類邏輯可被單元測試。

**Tech Stack:** .NET 9、Avalonia 11.3、Microsoft.Data.SqlClient、CommunityToolkit.Mvvm、xUnit + NSubstitute

## Global Constraints

- 所有 UI 文字、commit 訊息、文件、註解使用繁體中文；程式碼識別符維持英文
- TDD：先寫失敗測試，確認失敗，再寫最小實作
- 每個 Service 必須有 interface
- 預檢的連線 timeout 為 **5** 秒；未指定時維持既有的 **10** 秒
- 探測只呼叫 `OpenAsync`，**不得**執行任何 SQL 查詢
- `Reachable` 的順序必須與傳入的 `profiles` 一致
- 測試框架 xUnit + NSubstitute，命名 `方法名_情境_預期結果`
- 執行測試：`dotnet test tests/MoldplanDbSwitcher.Tests/`
- 建置：`dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`

---

## File Structure

| 檔案 | 責任 |
|---|---|
| `src/MoldplanDbSwitcher/Services/ISqlConnectionFactory.cs`（改） | 連線建立，新增可選的 connect timeout |
| `src/MoldplanDbSwitcher/Services/IConnectionTester.cs`（新） | 單一連線可達性測試的抽象 |
| `src/MoldplanDbSwitcher/Services/SqlConnectionTester.cs`（新） | 實際開 SQL 連線的實作，5 秒 timeout |
| `src/MoldplanDbSwitcher/Services/IConnectionProbeService.cs`（新） | 批次探測介面 + `ConnectionProbeResult` |
| `src/MoldplanDbSwitcher/Services/ConnectionProbeService.cs`（新） | 平行探測與分類 |
| `src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs`（改） | 兩個匯出流程插入預檢 |
| `src/MoldplanDbSwitcher/Program.cs`（改） | DI 註冊 |

---

### Task 1: 連線工廠支援自訂 timeout，並加上可達性測試器

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/ISqlConnectionFactory.cs`
- Modify: `src/MoldplanDbSwitcher/Services/SqlConnectionFactory.cs`
- Create: `src/MoldplanDbSwitcher/Services/IConnectionTester.cs`
- Create: `src/MoldplanDbSwitcher/Services/SqlConnectionTester.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/SqlConnectionFactoryTests.cs`

**Interfaces:**
- Produces: `ISqlConnectionFactory.Create(ConnectionProfile profile, int? connectTimeoutSeconds = null) → SqlConnection`
- Produces: `IConnectionTester.CanConnectAsync(ConnectionProfile profile, CancellationToken ct = default) → Task<bool>`

> **關於紅燈：** 這一步的紅燈以編譯錯誤呈現——新測試呼叫還不存在的兩參數多載。這是 C# 強型別下「功能不存在」的正常表現形式，不要為了讓它編譯過而先加參數。

- [ ] **Step 1: 寫失敗測試**

在 `tests/MoldplanDbSwitcher.Tests/Services/SqlConnectionFactoryTests.cs` 的 `Create_SqlAuth_UsesUsernamePassword` 之後加入：

```csharp
    [Fact]
    public void Create_指定ConnectTimeout_連線字串使用該值()
    {
        var profile = new ConnectionProfile { Server = "127.0.0.1", Database = "mis" };

        using var conn = _factory.Create(profile, 5);

        var builder = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(conn.ConnectionString);
        Assert.Equal(5, builder.ConnectTimeout);
    }

    [Fact]
    public void Create_未指定ConnectTimeout_維持預設10秒()
    {
        var profile = new ConnectionProfile { Server = "127.0.0.1", Database = "mis" };

        using var conn = _factory.Create(profile);

        var builder = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(conn.ConnectionString);
        Assert.Equal(10, builder.ConnectTimeout);
    }
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "SqlConnectionFactoryTests"`
Expected: FAIL — 編譯錯誤 `CS1501`，訊息大意為「`Create` 方法沒有多載採用 2 個引數」。

- [ ] **Step 3: 介面加上可選參數**

`src/MoldplanDbSwitcher/Services/ISqlConnectionFactory.cs` 全檔替換為：

```csharp
using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface ISqlConnectionFactory
{
    /// <summary>建立連線。connectTimeoutSeconds 為 null 時使用預設的 10 秒。</summary>
    SqlConnection Create(ConnectionProfile profile, int? connectTimeoutSeconds = null);
}
```

- [ ] **Step 4: 實作對應變更**

`src/MoldplanDbSwitcher/Services/SqlConnectionFactory.cs` 中，把方法簽章與 `ConnectTimeout` 兩行改為：

```csharp
    public SqlConnection Create(ConnectionProfile profile, int? connectTimeoutSeconds = null)
    {
        var builder = new SqlConnectionStringBuilder
        {
            DataSource = profile.Server,
            InitialCatalog = profile.Database,
            TrustServerCertificate = true,
            ConnectTimeout = connectTimeoutSeconds ?? 10
        };
```

方法其餘部分不動。

- [ ] **Step 5: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "SqlConnectionFactoryTests"`
Expected: PASS，4 個測試通過

- [ ] **Step 6: 新增可達性測試器**

建立 `src/MoldplanDbSwitcher/Services/IConnectionTester.cs`：

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

/// <summary>單一連線的可達性測試。抽成介面是為了讓 ConnectionProbeService 可被單元測試
/// （SqlConnection.OpenAsync 無法 mock）。</summary>
public interface IConnectionTester
{
    Task<bool> CanConnectAsync(ConnectionProfile profile, CancellationToken ct = default);
}
```

建立 `src/MoldplanDbSwitcher/Services/SqlConnectionTester.cs`：

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class SqlConnectionTester : IConnectionTester
{
    /// <summary>探測用的連線 timeout。比一般查詢的 10 秒短，因為只要判斷通不通。</summary>
    private const int ProbeTimeoutSeconds = 5;

    private readonly ISqlConnectionFactory _connectionFactory;

    public SqlConnectionTester(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<bool> CanConnectAsync(ConnectionProfile profile, CancellationToken ct = default)
    {
        try
        {
            await using var connection = _connectionFactory.Create(profile, ProbeTimeoutSeconds);
            await connection.OpenAsync(ct);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
```

`SqlConnectionTester` 不寫測試：它只是 `Create` → `OpenAsync` → try/catch，沒有可測的邏輯，測它等同測 SqlClient。

- [ ] **Step 7: 建置並跑全部測試**

Run: `dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
Expected: 建置成功

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: PASS（既有呼叫端因為是可選參數，全部不受影響）

- [ ] **Step 8: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/ISqlConnectionFactory.cs src/MoldplanDbSwitcher/Services/SqlConnectionFactory.cs src/MoldplanDbSwitcher/Services/IConnectionTester.cs src/MoldplanDbSwitcher/Services/SqlConnectionTester.cs tests/MoldplanDbSwitcher.Tests/Services/SqlConnectionFactoryTests.cs
git commit -m "feat: 連線工廠支援自訂 timeout，新增連線可達性測試器"
```

---

### Task 2: 平行探測服務

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IConnectionProbeService.cs`
- Create: `src/MoldplanDbSwitcher/Services/ConnectionProbeService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ConnectionProbeServiceTests.cs`

**Interfaces:**
- Consumes: `IConnectionTester.CanConnectAsync(ConnectionProfile, CancellationToken) → Task<bool>`（Task 1 產出）
- Produces: `ConnectionProbeResult(List<ConnectionProfile> Reachable, List<string> Unreachable)`
- Produces: `IConnectionProbeService.ProbeAsync(IReadOnlyList<ConnectionProfile>, IProgress<string>?, CancellationToken) → Task<ConnectionProbeResult>`

- [ ] **Step 1: 寫失敗測試**

建立 `tests/MoldplanDbSwitcher.Tests/Services/ConnectionProbeServiceTests.cs`：

```csharp
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class ConnectionProbeServiceTests
{
    private readonly IConnectionTester _tester = Substitute.For<IConnectionTester>();

    private static ConnectionProfile P(string name) =>
        new() { Name = name, Server = "s", Database = "d" };

    [Fact]
    public async Task ProbeAsync_全部可連線_Unreachable為空()
    {
        _tester.CanConnectAsync(Arg.Any<ConnectionProfile>(), Arg.Any<CancellationToken>())
            .Returns(true);
        var sut = new ConnectionProbeService(_tester);

        var result = await sut.ProbeAsync([P("甲"), P("乙")]);

        Assert.Equal(2, result.Reachable.Count);
        Assert.Empty(result.Unreachable);
    }

    [Fact]
    public async Task ProbeAsync_部分不可連線_正確分成兩堆()
    {
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "通"), Arg.Any<CancellationToken>())
            .Returns(true);
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "不通"), Arg.Any<CancellationToken>())
            .Returns(false);
        var sut = new ConnectionProbeService(_tester);

        var result = await sut.ProbeAsync([P("通"), P("不通")]);

        Assert.Single(result.Reachable);
        Assert.Equal("通", result.Reachable[0].Name);
        Assert.Single(result.Unreachable);
        Assert.Equal("不通", result.Unreachable[0]);
    }

    [Fact]
    public async Task ProbeAsync_Reachable順序與輸入一致()
    {
        _tester.CanConnectAsync(Arg.Any<ConnectionProfile>(), Arg.Any<CancellationToken>())
            .Returns(true);
        var sut = new ConnectionProbeService(_tester);

        var result = await sut.ProbeAsync([P("甲"), P("乙"), P("丙"), P("丁")]);

        Assert.Equal(new[] { "甲", "乙", "丙", "丁" },
            result.Reachable.Select(p => p.Name).ToArray());
    }

    [Fact]
    public async Task ProbeAsync_回報可連線與跳過的數量()
    {
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "通"), Arg.Any<CancellationToken>())
            .Returns(true);
        _tester.CanConnectAsync(Arg.Is<ConnectionProfile>(p => p.Name == "不通"), Arg.Any<CancellationToken>())
            .Returns(false);
        var sut = new ConnectionProbeService(_tester);
        var progress = new SyncProgress();

        await sut.ProbeAsync([P("通"), P("不通")], progress);

        Assert.Contains(progress.Messages, m => m.Contains("正在檢查 2 個連線"));
        Assert.Contains(progress.Messages, m => m.Contains("1 個可連線，跳過 1 個"));
    }

    /// <summary>同步收集回報內容。用 Progress&lt;T&gt; 會經由 SynchronizationContext 非同步排程，
    /// 測試得靠 delay 等待，不穩定。</summary>
    private sealed class SyncProgress : IProgress<string>
    {
        public List<string> Messages { get; } = [];
        public void Report(string value) => Messages.Add(value);
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionProbeServiceTests"`
Expected: FAIL — 編譯錯誤 `CS0246`，找不到型別 `ConnectionProbeService`。

- [ ] **Step 3: 寫介面與結果型別**

建立 `src/MoldplanDbSwitcher/Services/IConnectionProbeService.cs`：

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

/// <summary>探測結果。Unreachable 存連線名稱，與報表既有的 FailedConnections 風格一致。</summary>
public record ConnectionProbeResult(
    List<ConnectionProfile> Reachable,
    List<string> Unreachable);

public interface IConnectionProbeService
{
    /// <summary>平行探測所有連線，只做 OpenAsync 不執行查詢。</summary>
    Task<ConnectionProbeResult> ProbeAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null,
        CancellationToken ct = default);
}
```

- [ ] **Step 4: 寫實作**

建立 `src/MoldplanDbSwitcher/Services/ConnectionProbeService.cs`：

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ConnectionProbeService : IConnectionProbeService
{
    private readonly IConnectionTester _tester;

    public ConnectionProbeService(IConnectionTester tester)
    {
        _tester = tester;
    }

    public async Task<ConnectionProbeResult> ProbeAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null,
        CancellationToken ct = default)
    {
        progress?.Report($"正在檢查 {profiles.Count} 個連線...");

        // Task.WhenAll 保留輸入順序，Reachable 因此與 profiles 同序
        var results = await Task.WhenAll(profiles.Select(async p =>
            (Profile: p, CanConnect: await _tester.CanConnectAsync(p, ct))));

        var reachable = results.Where(r => r.CanConnect).Select(r => r.Profile).ToList();
        var unreachable = results.Where(r => !r.CanConnect).Select(r => r.Profile.Name).ToList();

        progress?.Report($"{reachable.Count} 個可連線，跳過 {unreachable.Count} 個");

        return new ConnectionProbeResult(reachable, unreachable);
    }
}
```

- [ ] **Step 5: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionProbeServiceTests"`
Expected: PASS，4 個測試通過

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/IConnectionProbeService.cs src/MoldplanDbSwitcher/Services/ConnectionProbeService.cs tests/MoldplanDbSwitcher.Tests/Services/ConnectionProbeServiceTests.cs
git commit -m "feat: 新增連線平行探測服務"
```

---

### Task 3: 兩個匯出流程接上預檢

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs`
- Modify: `src/MoldplanDbSwitcher/Program.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionSwitchDocumentViewModelTests.cs`

**Interfaces:**
- Consumes: `IConnectionProbeService.ProbeAsync(...)` 與 `ConnectionProbeResult`（Task 2 產出）

> **注意：** `ConnectionSwitchDocumentViewModel` 的建構式要多一個參數，測試檔中有**兩個** helper 會建構它（`CreateVm()` 與靜態 `Create()`），兩處都要更新。

- [ ] **Step 1: 寫失敗測試**

在 `tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionSwitchDocumentViewModelTests.cs`：

1. 欄位區加入（放在 `_connectionFactory` 宣告之後）：

```csharp
    private readonly IConnectionProbeService _connectionProbe;
```

2. 建構式中加入（放在 `_connectionFactory` 的設定之後、`_activeConnection` 之前）。預設所有連線都可連線，既有測試才不受影響：

```csharp
        _connectionProbe = Substitute.For<IConnectionProbeService>();
        _connectionProbe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult(new ConnectionProbeResult(
                call.Arg<IReadOnlyList<ConnectionProfile>>().ToList(), [])));
```

3. `CreateVm()` 改為：

```csharp
    private ConnectionSwitchDocumentViewModel CreateVm() => new(
        _connectionSource, _serverTxtService, _settingsService,
        _featureReportService, _connectionExportService, _usageReportService,
        _ansibleSyncService, _appSettingsService, _appSettingsDevService,
        _connectionFactory, _connectionProbe, _activeConnection);
```

4. 靜態 `Create()` helper 的結尾（`active ??= new ActiveConnectionService();` 那行起至方法結束）替換為：

```csharp
        active ??= new ActiveConnectionService();

        var probe = Substitute.For<IConnectionProbeService>();
        probe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult(new ConnectionProbeResult(
                call.Arg<IReadOnlyList<ConnectionProfile>>().ToList(), [])));

        return new ConnectionSwitchDocumentViewModel(
            source, serverTxt, settings, featureReport, export, usage,
            ansible, appSettings, appDev, factory, probe, active);
    }
```

5. 在檔案最後加入兩個新測試：

```csharp
    [Fact]
    public async Task ExportUsageReport_有連線不通_只查詢可連線的()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "通", Server = "s", Database = "d", Source = "Specurai" },
            new() { Name = "不通", Server = "s", Database = "d", Source = "Specurai" },
        });
        _connectionProbe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult(new ConnectionProbeResult(
                call.Arg<IReadOnlyList<ConnectionProfile>>().Where(p => p.Name == "通").ToList(),
                ["不通"])));

        var reportData = new UsageReportData();
        reportData.FailedConnections.Add("通");
        _usageReportService.QueryAllAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>())
            .Returns(reportData);

        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);
        vm.SaveUsageReportCallback = () => Task.FromResult<string?>(System.IO.Path.GetTempFileName());

        await vm.ExportUsageReportCommand.ExecuteAsync(null);

        await _usageReportService.Received(1).QueryAllAsync(
            Arg.Is<IReadOnlyList<ConnectionProfile>>(list =>
                list.Count == 1 && list[0].Name == "通"),
            Arg.Any<IProgress<string>>());
    }

    [Fact]
    public async Task ExportUsageReport_全部連線不通_不查詢且顯示訊息()
    {
        _connectionProbe.ProbeAsync(Arg.Any<IReadOnlyList<ConnectionProfile>>(),
                Arg.Any<IProgress<string>>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(new ConnectionProbeResult([], ["dev"])));

        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);
        vm.SaveUsageReportCallback = () => Task.FromResult<string?>(System.IO.Path.GetTempFileName());

        await vm.ExportUsageReportCommand.ExecuteAsync(null);

        await _usageReportService.DidNotReceive().QueryAllAsync(
            Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>());
        Assert.Contains("無法連線", vm.StatusMessage);
    }
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionSwitchDocumentViewModelTests"`
Expected: FAIL — 編譯錯誤 `CS1729`，`ConnectionSwitchDocumentViewModel` 的建構式不接受 12 個引數。

- [ ] **Step 3: ViewModel 加入依賴**

`src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs`：

1. 欄位區，在 `private readonly ISqlConnectionFactory _connectionFactory;` 之後加入：

```csharp
    private readonly IConnectionProbeService _connectionProbe;
```

2. 建構式參數列，在 `ISqlConnectionFactory connectionFactory,` 之後加入：

```csharp
        IConnectionProbeService connectionProbe,
```

3. 建構式主體，在 `_connectionFactory = connectionFactory;` 之後加入：

```csharp
        _connectionProbe = connectionProbe;
```

- [ ] **Step 4: 兩個匯出流程插入預檢**

在 `ExportFeatureReport` 與 `ExportUsageReport` 中，把原本這一段：

```csharp
            var progress = new Progress<string>(msg => ProgressText = msg);
```

連同它前面的 `profiles.Count == 0` 檢查，改寫為（以 `ExportUsageReport` 為例，`ExportFeatureReport` 做完全相同的插入）：

```csharp
            var profiles = FilterConnectionsForReport(sourceOptions);
            if (profiles.Count == 0)
            {
                StatusMessage = "沒有符合條件的連線";
                return;
            }

            var progress = new Progress<string>(msg => ProgressText = msg);

            var probe = await ProbeOrAbortAsync(profiles, progress);
            if (probe is null) return;
```

預檢邏輯抽成私有 helper，兩個匯出各呼叫一次。加在 `FilterConnectionsForReport` 方法附近：

```csharp
    /// <summary>預檢連線。全數不通時設定狀態訊息並回傳 null，呼叫端據此中止。</summary>
    private async Task<ConnectionProbeResult?> ProbeOrAbortAsync(
        IReadOnlyList<ConnectionProfile> profiles, IProgress<string> progress)
    {
        var probe = await _connectionProbe.ProbeAsync(profiles, progress);
        if (probe.Reachable.Count == 0)
        {
            StatusMessage = $"所有連線都無法連線：{string.Join(", ", probe.Unreachable)}";
            return null;
        }
        return probe;
    }
```

接著把該方法中傳給報表服務的 `profiles` 改為 `probe.Reachable`：

- `ExportUsageReport`：`await _usageReportService.QueryAllAsync(probe.Reachable, progress);`
- `ExportFeatureReport`：`await _featureReportService.QueryAllCustomerFeaturesAsync(probe.Reachable, progress);`

最後在兩個方法組合成功訊息的地方，於既有的兩個 `if` 之後加入第三段（`ExportUsageReport` 的既有兩段是 `SkippedConnections` 與 `FailedConnections`；`ExportFeatureReport` 同理，加在最後）：

```csharp
            if (probe.Unreachable.Count > 0)
                msg += $"（{probe.Unreachable.Count} 個連線不通已跳過：{string.Join(", ", probe.Unreachable)}）";
```

- [ ] **Step 5: DI 註冊**

`src/MoldplanDbSwitcher/Program.cs` 中，在 `services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();` 之後加入兩行：

```csharp
        services.AddSingleton<IConnectionTester, SqlConnectionTester>();
        services.AddSingleton<IConnectionProbeService, ConnectionProbeService>();
```

- [ ] **Step 6: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: PASS，全部通過（新增 2 個測試）

- [ ] **Step 7: 建置確認**

Run: `dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
Expected: 建置成功

- [ ] **Step 8: Commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs src/MoldplanDbSwitcher/Program.cs tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionSwitchDocumentViewModelTests.cs
git commit -m "feat: 報表匯出前先平行預檢連線，連不通的跳過"
```

---

## 驗收

於 app 中執行「報表 → 匯出使用次數統計」，選擇包含連不通客戶的來源與環境，應看到：

- 進度依序顯示「正在檢查 N 個連線...」→「M 個可連線，跳過 K 個」→「正在查詢第 1/M 個客戶：...」
- 整個預檢階段耗時約等於一次連線嘗試的時間，不隨連不通的客戶數增長
- 匯出完成的訊息末尾包含「（K 個連線不通已跳過：...）」

驗收需人工執行：本環境可用 Windows UI Automation 驅動 Avalonia（`System.Windows.Automation` 找到控制項後 `InvokePattern.Invoke()`），但實際匯出會對正式環境資料庫下查詢，不應由自動化觸發。
