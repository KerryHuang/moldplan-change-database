# 系統功能使用工時統計表 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 批次查詢所有客戶連線的使用工時，匯出單一 Excel（「使用工時統計」工作表），並在主選單新增入口。

**Architecture:** 新增 `UsageEntry` / `UsageReportData` models，再新增 `IUsageQueryService` / `UsageQueryService`（執行 SQL）與 `IUsageReportService` / `UsageReportService`（批次查詢＋匯出 Excel），結構完全平行於現有 Feature 系列。ViewModel 新增 `ExportUsageReportCommand`，View 新增選單項目。

**Tech Stack:** .NET 9、Avalonia 11.3、ClosedXML、Microsoft.Data.SqlClient、xUnit、NSubstitute

---

## 檔案清單

| 動作 | 路徑 |
|------|------|
| 新增 | `src/MoldplanDbSwitcher/Models/UsageModels.cs` |
| 新增 | `src/MoldplanDbSwitcher/Services/IUsageQueryService.cs` |
| 新增 | `src/MoldplanDbSwitcher/Services/UsageQueryService.cs` |
| 新增 | `src/MoldplanDbSwitcher/Services/IUsageReportService.cs` |
| 新增 | `src/MoldplanDbSwitcher/Services/UsageReportService.cs` |
| 修改 | `src/MoldplanDbSwitcher/Program.cs` |
| 修改 | `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` |
| 修改 | `src/MoldplanDbSwitcher/Views/MainWindow.axaml` |
| 修改 | `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs` |
| 新增 | `tests/MoldplanDbSwitcher.Tests/Services/UsageQueryServiceTests.cs` |
| 新增 | `tests/MoldplanDbSwitcher.Tests/Services/UsageReportServiceTests.cs` |

---

### Task 1: Models

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/UsageModels.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/UsageReportServiceTests.cs`（後續 task 建立）

- [ ] **Step 1: 建立 UsageModels.cs**

```csharp
// src/MoldplanDbSwitcher/Models/UsageModels.cs
namespace MoldplanDbSwitcher.Models;

public class UsageEntry
{
    public string ProgNo { get; set; } = string.Empty;
    public string ProgName { get; set; } = string.Empty;
    public decimal UsageMinutes { get; set; }
    public int Count { get; set; }
}

public class UsageReportData
{
    public List<(string CustomerName, UsageEntry Entry)> Rows { get; set; } = [];
    public List<string> FailedConnections { get; set; } = [];
    public List<string> SkippedConnections { get; set; } = [];
}
```

- [ ] **Step 2: 確認建置正常**

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```
Expected: Build succeeded，0 errors。

- [ ] **Step 3: Commit**

```bash
git add src/MoldplanDbSwitcher/Models/UsageModels.cs
git commit -m "feat: 新增 UsageEntry / UsageReportData models"
```

---

### Task 2: IUsageQueryService 與 UsageQueryService（TDD）

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IUsageQueryService.cs`
- Create: `src/MoldplanDbSwitcher/Services/UsageQueryService.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/Services/UsageQueryServiceTests.cs`

- [ ] **Step 1: 先寫介面**

```csharp
// src/MoldplanDbSwitcher/Services/IUsageQueryService.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IUsageQueryService
{
    Task<List<UsageEntry>> QueryUsageAsync(ConnectionProfile profile, DateTime startDate, DateTime endDate);
}
```

- [ ] **Step 2: 寫失敗測試**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/UsageQueryServiceTests.cs
using Microsoft.Data.SqlClient;
using NSubstitute;
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class UsageQueryServiceTests
{
    [Fact]
    public async Task QueryUsageAsync_MapsResultsCorrectly()
    {
        // UsageQueryService 需要真實 SqlConnection，此測試驗證介面存在且可注入
        var factory = Substitute.For<ISqlConnectionFactory>();
        var sut = new UsageQueryService(factory);

        // 建立一個會拋出 SqlException 的連線（表示真的嘗試連線了）
        var profile = new ConnectionProfile
        {
            Name = "Test",
            Server = "0.0.0.0",
            Database = "testdb",
            Username = "u",
            Password = "p"
        };
        factory.Create(profile).Returns(_ => throw new InvalidOperationException("Cannot open connection"));

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => sut.QueryUsageAsync(profile, DateTime.Today.AddMonths(-6), DateTime.Today));
    }

    [Fact]
    public async Task QueryUsageAsync_UsesDateParameters()
    {
        var factory = Substitute.For<ISqlConnectionFactory>();
        var sut = new UsageQueryService(factory);

        var profile = new ConnectionProfile { Name = "T", Server = "s", Database = "d", Username = "u", Password = "p" };
        var start = new DateTime(2025, 9, 1);
        var end = new DateTime(2026, 3, 27);

        factory.Create(profile).Returns(_ => throw new InvalidOperationException("expected"));

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => sut.QueryUsageAsync(profile, start, end));

        // 確認 factory.Create 被呼叫（日期由 service 傳入 SQL 參數）
        factory.Received(1).Create(profile);
    }
}
```

- [ ] **Step 3: 執行測試確認失敗**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UsageQueryServiceTests"
```
Expected: FAIL，因為 `UsageQueryService` 尚未存在。

- [ ] **Step 4: 實作 UsageQueryService**

```csharp
// src/MoldplanDbSwitcher/Services/UsageQueryService.cs
using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class UsageQueryService : IUsageQueryService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public UsageQueryService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<List<UsageEntry>> QueryUsageAsync(
        ConnectionProfile profile, DateTime startDate, DateTime endDate)
    {
        const string sql = """
            SELECT
                RTRIM(A.PROG_NO),
                RTRIM(D.ITEM_DESC),
                ROUND(SUM(
                    DATEDIFF(SECOND,
                        CAST(RTRIM(A.TIME1)    AS TIME),
                        CAST(RTRIM(A.TIME_OUT) AS TIME)
                    ) / 60.0
                ), 2),
                COUNT(*)
            FROM SYS030 A
            INNER JOIN SYS013 D
                ON RTRIM(A.PROG_NO) = RTRIM(D.ITEM_ID)
               AND D.DEL_MARK = 'N'
            WHERE A.DEL_MARK  = 'N'
              AND A.ON_LINE   = 'X'
              AND A.TIME_OUT  > A.TIME1
              AND A.TIME_OUT  <> ' '
              AND A.LOG_DATE1 >= @StartDate
              AND A.LOG_DATE1 <  DATEADD(DAY, 1, @EndDate)
            GROUP BY
                RTRIM(A.PROG_NO),
                RTRIM(D.ITEM_DESC)
            HAVING ROUND(SUM(DATEDIFF(SECOND,
                CAST(RTRIM(A.TIME1) AS TIME),
                CAST(RTRIM(A.TIME_OUT) AS TIME)
            ) / 60.0), 2) > 0
            ORDER BY 3 DESC
            """;

        var results = new List<UsageEntry>();

        using var connection = _connectionFactory.Create(profile);
        await connection.OpenAsync();

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@StartDate", startDate.Date);
        command.Parameters.AddWithValue("@EndDate", endDate.Date);

        using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new UsageEntry
            {
                ProgNo = reader.GetString(0),
                ProgName = reader.GetString(1),
                UsageMinutes = reader.GetDecimal(2),
                Count = reader.GetInt32(3)
            });
        }

        return results;
    }
}
```

- [ ] **Step 5: 執行測試確認通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UsageQueryServiceTests"
```
Expected: PASS（2 tests）。

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/IUsageQueryService.cs \
        src/MoldplanDbSwitcher/Services/UsageQueryService.cs \
        tests/MoldplanDbSwitcher.Tests/Services/UsageQueryServiceTests.cs
git commit -m "feat: 新增 IUsageQueryService / UsageQueryService（TDD）"
```

---

### Task 3: IUsageReportService 與 UsageReportService（TDD）

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IUsageReportService.cs`
- Create: `src/MoldplanDbSwitcher/Services/UsageReportService.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/Services/UsageReportServiceTests.cs`

- [ ] **Step 1: 先寫介面**

```csharp
// src/MoldplanDbSwitcher/Services/IUsageReportService.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IUsageReportService
{
    Task<UsageReportData> QueryAllAsync(IProgress<string>? progress = null);
    Task ExportToExcelAsync(string path, UsageReportData data);
}
```

- [ ] **Step 2: 寫失敗測試**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/UsageReportServiceTests.cs
using NSubstitute;
using NSubstitute.ExceptionExtensions;
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class UsageReportServiceTests
{
    private readonly IConnectionSourceService _connectionSource;
    private readonly IUsageQueryService _usageQuery;
    private readonly UsageReportService _sut;

    public UsageReportServiceTests()
    {
        _connectionSource = Substitute.For<IConnectionSourceService>();
        _usageQuery = Substitute.For<IUsageQueryService>();
        _sut = new UsageReportService(_connectionSource, _usageQuery);
    }

    [Fact]
    public async Task QueryAllAsync_ReturnsRowsForAllCustomers()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" },
            new() { Name = "WayDoSoft01-Test", Server = "2.2.2.2", Database = "wd01", Username = "u", Password = "p" }
        };
        _connectionSource.LoadAllConnections().Returns(profiles);

        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>
            {
                new() { ProgNo = "TOL010", ProgName = "刀具基本資料", UsageMinutes = 120.5m, Count = 30 }
            });
        _usageQuery.QueryUsageAsync(profiles[1], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>
            {
                new() { ProgNo = "PUR050", ProgName = "外包出廠", UsageMinutes = 60.0m, Count = 15 },
                new() { ProgNo = "TOL010", ProgName = "刀具基本資料", UsageMinutes = 45.0m, Count = 10 }
            });

        var result = await _sut.QueryAllAsync();

        Assert.Equal(3, result.Rows.Count);
        Assert.Empty(result.FailedConnections);
        Assert.Empty(result.SkippedConnections);
        // 第一個客戶的 CustomerName 去除後綴
        Assert.Equal("Gma-Staging", result.Rows[0].CustomerName);
    }

    [Fact]
    public async Task QueryAllAsync_FailedConnection_RecordsFailure()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" },
            new() { Name = "Bad-Staging", Server = "0.0.0.0", Database = "bad", Username = "u", Password = "p" }
        };
        _connectionSource.LoadAllConnections().Returns(profiles);

        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>
            {
                new() { ProgNo = "TOL010", ProgName = "刀具", UsageMinutes = 10m, Count = 5 }
            });
        _usageQuery.QueryUsageAsync(profiles[1], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .ThrowsAsync(new Exception("Connection failed"));

        var result = await _sut.QueryAllAsync();

        Assert.Single(result.Rows);
        Assert.Single(result.FailedConnections);
        Assert.Equal("Bad-Staging", result.FailedConnections[0]);
    }

    [Fact]
    public async Task QueryAllAsync_EmptyResult_RecordsSkipped()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Empty-Staging", Server = "1.1.1.1", Database = "empty", Username = "u", Password = "p" }
        };
        _connectionSource.LoadAllConnections().Returns(profiles);
        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>());

        var result = await _sut.QueryAllAsync();

        Assert.Empty(result.Rows);
        Assert.Single(result.SkippedConnections);
        Assert.Equal("Empty-Staging", result.SkippedConnections[0]);
    }

    [Fact]
    public async Task QueryAllAsync_ReportsProgress()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" }
        };
        _connectionSource.LoadAllConnections().Returns(profiles);
        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>());

        var messages = new List<string>();
        var progress = new Progress<string>(msg => messages.Add(msg));

        await _sut.QueryAllAsync(progress);
        await Task.Delay(100);

        Assert.NotEmpty(messages);
    }

    [Fact]
    public async Task QueryAllAsync_UsesDateRangeOfSixMonths()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" }
        };
        _connectionSource.LoadAllConnections().Returns(profiles);
        _usageQuery.QueryUsageAsync(Arg.Any<ConnectionProfile>(), Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>());

        await _sut.QueryAllAsync();

        await _usageQuery.Received(1).QueryUsageAsync(
            profiles[0],
            Arg.Is<DateTime>(d => d <= DateTime.Today.AddMonths(-6).AddDays(1)),
            Arg.Is<DateTime>(d => d.Date == DateTime.Today));
    }
}
```

- [ ] **Step 3: 執行測試確認失敗**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UsageReportServiceTests"
```
Expected: FAIL，因為 `UsageReportService` 尚未存在。

- [ ] **Step 4: 實作 UsageReportService**

```csharp
// src/MoldplanDbSwitcher/Services/UsageReportService.cs
using ClosedXML.Excel;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class UsageReportService : IUsageReportService
{
    private readonly IConnectionSourceService _connectionSource;
    private readonly IUsageQueryService _usageQuery;

    private static readonly XLColor HeaderBg = XLColor.FromHtml("#4472C4");
    private static readonly XLColor HeaderFg = XLColor.White;

    public UsageReportService(IConnectionSourceService connectionSource, IUsageQueryService usageQuery)
    {
        _connectionSource = connectionSource;
        _usageQuery = usageQuery;
    }

    public async Task<UsageReportData> QueryAllAsync(IProgress<string>? progress = null)
    {
        var profiles = _connectionSource.LoadAllConnections();
        var result = new UsageReportData();

        var endDate = DateTime.Today;
        var startDate = endDate.AddMonths(-6);

        for (int i = 0; i < profiles.Count; i++)
        {
            var profile = profiles[i];
            progress?.Report($"正在查詢第 {i + 1}/{profiles.Count} 個客戶：{profile.Name}...");

            try
            {
                var entries = await _usageQuery.QueryUsageAsync(profile, startDate, endDate);
                if (entries.Count == 0)
                {
                    result.SkippedConnections.Add(profile.Name);
                    continue;
                }
                foreach (var entry in entries)
                    result.Rows.Add((profile.Name, entry));
            }
            catch
            {
                result.FailedConnections.Add(profile.Name);
            }
        }

        return result;
    }

    public Task ExportToExcelAsync(string path, UsageReportData data)
    {
        using var wb = new XLWorkbook();
        var ws = wb.Worksheets.Add("使用工時統計");

        var headers = new[] { "客戶", "程式編號", "程式名稱", "使用時間（分）", "次數" };
        for (int i = 0; i < headers.Length; i++)
            ws.Cell(1, i + 1).Value = headers[i];

        // 標題列樣式
        var headerRange = ws.Range(1, 1, 1, headers.Length);
        headerRange.Style.Fill.BackgroundColor = HeaderBg;
        headerRange.Style.Font.FontColor = HeaderFg;
        headerRange.Style.Font.Bold = true;
        headerRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
        headerRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;

        int row = 2;
        foreach (var (customerName, entry) in data.Rows)
        {
            ws.Cell(row, 1).Value = customerName;
            ws.Cell(row, 2).Value = entry.ProgNo;
            ws.Cell(row, 3).Value = entry.ProgName;
            ws.Cell(row, 4).Value = entry.UsageMinutes;
            ws.Cell(row, 4).Style.NumberFormat.Format = "0.00";
            ws.Cell(row, 5).Value = entry.Count;
            row++;
        }

        if (row > 2)
        {
            var dataRange = ws.Range(1, 1, row - 1, headers.Length);
            dataRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
            dataRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
            dataRange.SetAutoFilter();
        }

        ws.Columns().AdjustToContents(5.0, 40.0);
        wb.SaveAs(path);
        return Task.CompletedTask;
    }
}
```

- [ ] **Step 5: 執行測試確認通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UsageReportServiceTests"
```
Expected: PASS（5 tests）。

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/IUsageReportService.cs \
        src/MoldplanDbSwitcher/Services/UsageReportService.cs \
        tests/MoldplanDbSwitcher.Tests/Services/UsageReportServiceTests.cs
git commit -m "feat: 新增 IUsageReportService / UsageReportService（TDD）"
```

---

### Task 4: 注冊 DI 與 ViewModel 命令

**Files:**
- Modify: `src/MoldplanDbSwitcher/Program.cs`
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`

- [ ] **Step 1: 在 Program.cs 註冊服務**

在 `ConfigureServices` 中，`AddSingleton<IFeatureReportService...>` 下方加入：

```csharp
services.AddSingleton<IUsageQueryService, UsageQueryService>();
services.AddSingleton<IUsageReportService, UsageReportService>();
```

完整的 `ConfigureServices` 方法如下：

```csharp
private static void ConfigureServices(IServiceCollection services)
{
    services.AddSingleton<ISettingsService, SettingsService>();
    services.AddSingleton<IConnectionSourceService, ConnectionSourceService>();
    services.AddSingleton<IServerTxtService, ServerTxtService>();
    services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();
    services.AddSingleton<IFeatureQueryService, FeatureQueryService>();
    services.AddSingleton<IFeatureReportService, FeatureReportService>();
    services.AddSingleton<IUsageQueryService, UsageQueryService>();
    services.AddSingleton<IUsageReportService, UsageReportService>();
    services.AddSingleton<IConnectionExportService, ConnectionExportService>();
    services.AddTransient<MainWindowViewModel>();
}
```

- [ ] **Step 2: 在 MainWindowViewModel 加入欄位、建構式參數與命令**

在 `MainWindowViewModel.cs`：

1. 加入欄位（在 `_connectionExportService` 後）：
```csharp
private readonly IUsageReportService _usageReportService;
```

2. 加入 callback 屬性（在 `SaveFileCallback` 後）：
```csharp
public Func<Task<string?>>? SaveUsageReportCallback { get; set; }
```

3. 建構式參數加入 `IUsageReportService usageReportService`，並在建構式內賦值：
```csharp
public MainWindowViewModel(
    IConnectionSourceService connectionSource,
    IServerTxtService serverTxtService,
    ISettingsService settingsService,
    IFeatureReportService featureReportService,
    IConnectionExportService connectionExportService,
    IUsageReportService usageReportService)
{
    _connectionSource = connectionSource;
    _serverTxtService = serverTxtService;
    _settingsService = settingsService;
    _featureReportService = featureReportService;
    _connectionExportService = connectionExportService;
    _usageReportService = usageReportService;

    LoadConnections();
    DiscoverServerTxtFiles();
}
```

4. 加入命令（在 `ExportFeatureReport` 方法後）：
```csharp
[RelayCommand]
private async Task ExportUsageReport()
{
    IsExporting = true;
    ProgressText = "正在查詢使用工時...";

    try
    {
        var progress = new Progress<string>(msg => ProgressText = msg);
        var data = await _usageReportService.QueryAllAsync(progress);

        if (data.Rows.Count == 0)
        {
            StatusMessage = $"所有連線查詢失敗或無資料：{string.Join(", ", data.FailedConnections)}";
            return;
        }

        var path = SaveUsageReportCallback != null ? await SaveUsageReportCallback() : null;
        if (path is null)
        {
            StatusMessage = "已取消匯出";
            return;
        }

        ProgressText = "正在產出 Excel...";
        await _usageReportService.ExportToExcelAsync(path, data);

        var msg = $"已成功匯出至 {path}";
        if (data.SkippedConnections.Count > 0)
            msg += $"（{data.SkippedConnections.Count} 個連線無資料已跳過：{string.Join(", ", data.SkippedConnections)}）";
        if (data.FailedConnections.Count > 0)
            msg += $"（{data.FailedConnections.Count} 個連線失敗：{string.Join(", ", data.FailedConnections)}）";
        StatusMessage = msg;
    }
    catch (Exception ex)
    {
        StatusMessage = $"匯出失敗：{ex.Message}";
    }
    finally
    {
        IsExporting = false;
        ProgressText = string.Empty;
    }
}
```

- [ ] **Step 3: 確認建置正常**

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```
Expected: Build succeeded，0 errors。

- [ ] **Step 4: 更新 MainWindowViewModelTests 的 CreateVm（加入 mock）**

在 `MainWindowViewModelTests.cs` 的建構式加入：
```csharp
private readonly IUsageReportService _usageReportService;

public MainWindowViewModelTests()
{
    _connectionSource = Substitute.For<IConnectionSourceService>();
    _serverTxtService = Substitute.For<IServerTxtService>();
    _settingsService = Substitute.For<ISettingsService>();
    _featureReportService = Substitute.For<IFeatureReportService>();
    _connectionExportService = Substitute.For<IConnectionExportService>();
    _usageReportService = Substitute.For<IUsageReportService>();

    _connectionSource.LoadTableSpecConnections().Returns(new List<ConnectionProfile>
    {
        new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Source = "TableSpec" }
    });
    _connectionSource.LoadCustomConnections().Returns(new List<ConnectionProfile>());
    _serverTxtService.DiscoverPaths().Returns(new List<string>());
}

private MainWindowViewModel CreateVm() => new(
    _connectionSource, _serverTxtService, _settingsService,
    _featureReportService, _connectionExportService, _usageReportService);
```

- [ ] **Step 5: 執行所有測試確認通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/
```
Expected: All tests PASS。

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/Program.cs \
        src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs \
        tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs
git commit -m "feat: 註冊 UsageReportService DI，ViewModel 加入 ExportUsageReportCommand"
```

---

### Task 5: View — 選單項目與 code-behind

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`

- [ ] **Step 1: 在 MainWindow.axaml 加入選單項目**

在「匯出功能差異表(_R)」的 `<MenuItem>` 後加入：

```xml
<MenuItem Header="匯出使用工時統計(_U)" Click="OnExportUsageReportClick"
          IsEnabled="{Binding !IsExporting}" />
```

- [ ] **Step 2: 在 MainWindow.axaml.cs 加入 event handler**

```csharp
private async void OnExportUsageReportClick(object? sender, RoutedEventArgs e)
{
    if (DataContext is MainWindowViewModel vm)
    {
        vm.SaveUsageReportCallback = async () =>
        {
            var file = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "儲存使用工時統計",
                DefaultExtension = "xlsx",
                FileTypeChoices = new[]
                {
                    new FilePickerFileType("Excel 檔案") { Patterns = new[] { "*.xlsx" } }
                },
                SuggestedFileName = "系統功能使用工時統計表"
            });
            return file?.Path.LocalPath;
        };
        await vm.ExportUsageReportCommand.ExecuteAsync(null);
    }
}
```

- [ ] **Step 3: 確認建置正常**

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```
Expected: Build succeeded，0 errors。

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Views/MainWindow.axaml \
        src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs
git commit -m "feat: 主選單新增「匯出使用工時統計」入口"
```

---

### Task 6: 實際 SQL 驗證

**Files:** （無程式碼修改，純驗證）

- [ ] **Step 1: 執行應用程式**

```bash
dotnet run --project src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

- [ ] **Step 2: 點選「檔案 → 匯出使用工時統計」**

觀察進度文字逐一顯示每個客戶查詢狀態。

- [ ] **Step 3: 儲存 Excel，確認輸出正確**

開啟產出的 Excel，確認：
- 工作表名稱為「使用工時統計」
- 欄位標題正確（客戶、程式編號、程式名稱、使用時間（分）、次數）
- 資料筆數合理（非零）
- 使用時間（分）欄位為數值，顯示 2 位小數
- StatusMessage 顯示成功訊息（包含失敗/跳過數量）

- [ ] **Step 4: 確認無連線失敗**

若 StatusMessage 顯示有失敗連線，排查原因（網路、帳密、資料表是否存在 SYS030/SYS013）。

- [ ] **Step 5: Commit（若有修正）**

若 Step 4 發現問題並修正，commit 修正內容後執行：
```bash
dotnet test tests/MoldplanDbSwitcher.Tests/
```
確認所有測試仍 PASS。
