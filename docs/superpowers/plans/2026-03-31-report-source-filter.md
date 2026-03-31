# 報表來源篩選 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 匯出功能差異表與使用工時統計前，彈出對話框讓使用者選擇要查詢的連線來源（Specurai / 自訂 / Ansible 正式 / Ansible 測試）。

**Architecture:** 新增 `ReportSourceDialog` 對話框供使用者勾選來源；ViewModel 根據勾選過濾 `Connections` 清單，傳入報表服務；服務介面改為接受外部傳入的 `IReadOnlyList<ConnectionProfile>`，不再自行呼叫 `LoadAllConnections()`。

**Tech Stack:** .NET 9、Avalonia 11.3、CommunityToolkit.Mvvm、xUnit + NSubstitute

---

## 檔案結構

| 動作 | 路徑 |
|------|------|
| 新增 | `src/MoldplanDbSwitcher/Models/ReportSourceOptions.cs` |
| 新增 | `src/MoldplanDbSwitcher/ViewModels/ReportSourceDialogViewModel.cs` |
| 新增 | `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml` |
| 新增 | `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml.cs` |
| 修改 | `src/MoldplanDbSwitcher/Services/IFeatureReportService.cs` |
| 修改 | `src/MoldplanDbSwitcher/Services/FeatureReportService.cs` |
| 修改 | `src/MoldplanDbSwitcher/Services/IUsageReportService.cs` |
| 修改 | `src/MoldplanDbSwitcher/Services/UsageReportService.cs` |
| 修改 | `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` |
| 修改 | `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs` |
| 修改 | `src/MoldplanDbSwitcher/Program.cs` |
| 修改 | `tests/MoldplanDbSwitcher.Tests/Services/FeatureReportServiceTests.cs` |
| 修改 | `tests/MoldplanDbSwitcher.Tests/Services/UsageReportServiceTests.cs` |
| 修改 | `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs` |

---

### Task 1: 新增 ReportSourceOptions 模型

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/ReportSourceOptions.cs`

- [ ] **Step 1: 建立檔案**

```csharp
namespace MoldplanDbSwitcher.Models;

public record ReportSourceOptions(
    bool Specurai,
    bool Custom,
    bool AnsibleProduction,
    bool AnsibleStaging)
{
    public static ReportSourceOptions AllSelected =>
        new(Specurai: true, Custom: true, AnsibleProduction: true, AnsibleStaging: true);
}
```

- [ ] **Step 2: 建置確認**

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj -q
```

Expected: `建置成功。`

- [ ] **Step 3: Commit**

```bash
git add src/MoldplanDbSwitcher/Models/ReportSourceOptions.cs
git commit -m "feat: 新增 ReportSourceOptions 模型"
```

---

### Task 2: 更新 FeatureReportService 介面與實作（TDD）

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/IFeatureReportService.cs`
- Modify: `src/MoldplanDbSwitcher/Services/FeatureReportService.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/Services/FeatureReportServiceTests.cs`

背景：目前 `FeatureReportService` 建構式接受 `IConnectionSourceService`，在 `QueryAllCustomerFeaturesAsync()` 內部呼叫 `LoadAllConnections()`。改為由呼叫方傳入 `IReadOnlyList<ConnectionProfile>`。

- [ ] **Step 1: 更新測試（先讓測試失敗）**

將 `tests/MoldplanDbSwitcher.Tests/Services/FeatureReportServiceTests.cs` 整個替換為：

```csharp
using NSubstitute;
using NSubstitute.ExceptionExtensions;
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class FeatureReportServiceTests
{
    private readonly IFeatureQueryService _featureQuery;
    private readonly FeatureReportService _sut;

    public FeatureReportServiceTests()
    {
        _featureQuery = Substitute.For<IFeatureQueryService>();
        _sut = new FeatureReportService(_featureQuery);
    }

    [Fact]
    public async Task QueryAllCustomerFeaturesAsync_ReturnsAllCustomerData()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma-staging", Username = "u", Password = "p" },
            new() { Name = "WayDoSoft01-Test", Server = "2.2.2.2", Database = "wd01-test", Username = "u", Password = "p" }
        };

        var gmaFeatures = new List<FeatureEntry>
        {
            new() { SysType = "刀具", ItemId = "TOL010", ItemDesc = "刀具基本資料作業", AppFile = "TOL010", OpenYn = "Y" }
        };
        var wd01Features = new List<FeatureEntry>
        {
            new() { SysType = "刀具", ItemId = "TOL010", ItemDesc = "刀具基本資料作業", AppFile = "TOL010", OpenYn = "Y" },
            new() { SysType = "外包", ItemId = "PUR050", ItemDesc = "外包出廠作業", AppFile = "PUR050", OpenYn = "N" }
        };
        _featureQuery.QueryFeaturesAsync(profiles[0]).Returns(gmaFeatures);
        _featureQuery.QueryFeaturesAsync(profiles[1]).Returns(wd01Features);

        var result = await _sut.QueryAllCustomerFeaturesAsync(profiles);

        Assert.Equal(2, result.Customers.Count);
        Assert.Equal("Gma", result.Customers[0].Code);
        Assert.Equal("WayDoSoft01", result.Customers[1].Code);
        Assert.Single(result.Customers[0].Features);
        Assert.Equal(2, result.Customers[1].Features.Count);
        Assert.Empty(result.FailedConnections);
    }

    [Fact]
    public async Task QueryAllCustomerFeaturesAsync_PartialFailure_ReturnsSuccessAndFailures()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma-staging", Username = "u", Password = "p" },
            new() { Name = "Bad-Staging", Server = "0.0.0.0", Database = "bad", Username = "u", Password = "p" }
        };

        _featureQuery.QueryFeaturesAsync(profiles[0]).Returns(new List<FeatureEntry>
        {
            new() { SysType = "刀具", ItemId = "TOL010", ItemDesc = "刀具", AppFile = "TOL010", OpenYn = "Y" }
        });
        _featureQuery.QueryFeaturesAsync(profiles[1]).ThrowsAsync(new Exception("Connection failed"));

        var result = await _sut.QueryAllCustomerFeaturesAsync(profiles);

        Assert.Single(result.Customers);
        Assert.Single(result.FailedConnections);
        Assert.Equal("Bad-Staging", result.FailedConnections[0]);
    }

    [Fact]
    public async Task QueryAllCustomerFeaturesAsync_AllFailure_ReturnsEmpty()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Bad-Staging", Server = "0.0.0.0", Database = "bad", Username = "u", Password = "p" }
        };
        _featureQuery.QueryFeaturesAsync(profiles[0]).ThrowsAsync(new Exception("fail"));

        var result = await _sut.QueryAllCustomerFeaturesAsync(profiles);

        Assert.Empty(result.Customers);
        Assert.Single(result.FailedConnections);
    }

    [Fact]
    public async Task QueryAllCustomerFeaturesAsync_EmptyFeatures_ExcludedFromCustomers()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "WDMIS", Server = "1.1.1.1", Database = "MoldPlanDataModel", Username = "u", Password = "p" },
            new() { Name = "Gma-Staging", Server = "2.2.2.2", Database = "gma-staging", Username = "u", Password = "p" }
        };

        _featureQuery.QueryFeaturesAsync(profiles[0]).Returns(new List<FeatureEntry>());
        _featureQuery.QueryFeaturesAsync(profiles[1]).Returns(new List<FeatureEntry>
        {
            new() { SysType = "刀具", ItemId = "TOL010", ItemDesc = "刀具", AppFile = "TOL010", OpenYn = "Y" }
        });

        var result = await _sut.QueryAllCustomerFeaturesAsync(profiles);

        Assert.Single(result.Customers);
        Assert.Equal("Gma", result.Customers[0].Code);
        Assert.Single(result.SkippedConnections);
        Assert.Equal("WDMIS", result.SkippedConnections[0]);
    }

    [Fact]
    public async Task QueryAllCustomerFeaturesAsync_ReportsProgress()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" }
        };
        _featureQuery.QueryFeaturesAsync(profiles[0]).Returns(new List<FeatureEntry>());

        var messages = new List<string>();
        var progress = new Progress<string>(msg => messages.Add(msg));

        await _sut.QueryAllCustomerFeaturesAsync(profiles, progress);

        await Task.Delay(100);
        Assert.NotEmpty(messages);
    }
}
```

- [ ] **Step 2: 確認測試失敗**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "FeatureReportServiceTests" -q
```

Expected: 編譯錯誤或測試失敗（`FeatureReportService` 建構式不符）。

- [ ] **Step 3: 更新 IFeatureReportService 介面**

將 `src/MoldplanDbSwitcher/Services/IFeatureReportService.cs` 改為：

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IFeatureReportService
{
    Task<FeatureReportData> QueryAllCustomerFeaturesAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null);
    Task ExportToExcelAsync(string path, FeatureReportData data);
}
```

- [ ] **Step 4: 更新 FeatureReportService 實作**

在 `src/MoldplanDbSwitcher/Services/FeatureReportService.cs` 中：

1. 移除 `IConnectionSourceService` 欄位與建構式參數：
```csharp
// 從：
public FeatureReportService(IConnectionSourceService connectionSource, IFeatureQueryService featureQuery)
{
    _connectionSource = connectionSource;
    _featureQuery = featureQuery;
}

// 改為：
public FeatureReportService(IFeatureQueryService featureQuery)
{
    _featureQuery = featureQuery;
}
```

2. 同時刪除 `private readonly IConnectionSourceService _connectionSource;` 欄位宣告。

3. 更新 `QueryAllCustomerFeaturesAsync` 方法簽名與實作：
```csharp
public async Task<FeatureReportData> QueryAllCustomerFeaturesAsync(
    IReadOnlyList<ConnectionProfile> profiles,
    IProgress<string>? progress = null)
{
    var result = new FeatureReportData();

    for (int i = 0; i < profiles.Count; i++)
    {
        var profile = profiles[i];
        progress?.Report($"正在查詢第 {i + 1}/{profiles.Count} 個客戶：{profile.Name}...");

        try
        {
            var features = await _featureQuery.QueryFeaturesAsync(profile);
            if (features.Count == 0)
            {
                result.SkippedConnections.Add(profile.Name);
                continue;
            }
            var customer = CustomerFeatureData.FromConnectionName(profile.Name, profile.Database);
            customer.Features = features;
            result.Customers.Add(customer);
        }
        catch
        {
            result.FailedConnections.Add(profile.Name);
        }
    }

    return result;
}
```

- [ ] **Step 5: 更新 Program.cs DI 註冊**

在 `src/MoldplanDbSwitcher/Program.cs` 找到：
```csharp
services.AddSingleton<IFeatureReportService, FeatureReportService>();
```
確認這行仍正確（`FeatureReportService` 建構式現只需 `IFeatureQueryService`，DI 容器會自動注入）。若原本有額外傳入 `IConnectionSourceService`，將其移除。

- [ ] **Step 6: 確認測試通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "FeatureReportServiceTests" -q
```

Expected: `通過: 5`

- [ ] **Step 7: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/IFeatureReportService.cs \
        src/MoldplanDbSwitcher/Services/FeatureReportService.cs \
        src/MoldplanDbSwitcher/Program.cs \
        tests/MoldplanDbSwitcher.Tests/Services/FeatureReportServiceTests.cs
git commit -m "refactor: FeatureReportService 改為接受外部傳入 profiles"
```

---

### Task 3: 更新 UsageReportService 介面與實作（TDD）

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/IUsageReportService.cs`
- Modify: `src/MoldplanDbSwitcher/Services/UsageReportService.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/Services/UsageReportServiceTests.cs`

- [ ] **Step 1: 更新測試（先讓測試失敗）**

將 `tests/MoldplanDbSwitcher.Tests/Services/UsageReportServiceTests.cs` 整個替換為：

```csharp
using NSubstitute;
using NSubstitute.ExceptionExtensions;
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class UsageReportServiceTests
{
    private readonly IUsageQueryService _usageQuery;
    private readonly UsageReportService _sut;

    public UsageReportServiceTests()
    {
        _usageQuery = Substitute.For<IUsageQueryService>();
        _sut = new UsageReportService(_usageQuery);
    }

    [Fact]
    public async Task QueryAllAsync_ReturnsRowsForAllCustomers()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "Gma-Staging", Server = "1.1.1.1", Database = "gma", Username = "u", Password = "p" },
            new() { Name = "WayDoSoft01-Test", Server = "2.2.2.2", Database = "wd01", Username = "u", Password = "p" }
        };

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

        var result = await _sut.QueryAllAsync(profiles);

        Assert.Equal(3, result.Rows.Count);
        Assert.Empty(result.FailedConnections);
        Assert.Empty(result.SkippedConnections);
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

        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>
            {
                new() { ProgNo = "TOL010", ProgName = "刀具", UsageMinutes = 10m, Count = 5 }
            });
        _usageQuery.QueryUsageAsync(profiles[1], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .ThrowsAsync(new Exception("Connection failed"));

        var result = await _sut.QueryAllAsync(profiles);

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
        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>());

        var result = await _sut.QueryAllAsync(profiles);

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
        _usageQuery.QueryUsageAsync(profiles[0], Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>());

        var messages = new List<string>();
        var progress = new Progress<string>(msg => messages.Add(msg));

        await _sut.QueryAllAsync(profiles, progress);
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
        _usageQuery.QueryUsageAsync(Arg.Any<ConnectionProfile>(), Arg.Any<DateTime>(), Arg.Any<DateTime>())
            .Returns(new List<UsageEntry>());

        await _sut.QueryAllAsync(profiles);

        await _usageQuery.Received(1).QueryUsageAsync(
            profiles[0],
            Arg.Is<DateTime>(d => d <= DateTime.Today.AddMonths(-6).AddDays(1)),
            Arg.Is<DateTime>(d => d.Date == DateTime.Today));
    }
}
```

- [ ] **Step 2: 確認測試失敗**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UsageReportServiceTests" -q
```

Expected: 編譯錯誤或測試失敗。

- [ ] **Step 3: 更新 IUsageReportService 介面**

將 `src/MoldplanDbSwitcher/Services/IUsageReportService.cs` 改為：

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IUsageReportService
{
    Task<UsageReportData> QueryAllAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null);
    Task ExportToExcelAsync(string path, UsageReportData data);
}
```

- [ ] **Step 4: 更新 UsageReportService 實作**

在 `src/MoldplanDbSwitcher/Services/UsageReportService.cs` 中：

1. 移除 `IConnectionSourceService` 欄位與建構式參數：
```csharp
// 從：
public UsageReportService(IConnectionSourceService connectionSource, IUsageQueryService usageQuery)
{
    _connectionSource = connectionSource;
    _usageQuery = usageQuery;
}

// 改為：
public UsageReportService(IUsageQueryService usageQuery)
{
    _usageQuery = usageQuery;
}
```

2. 刪除 `private readonly IConnectionSourceService _connectionSource;` 欄位宣告。

3. 更新 `QueryAllAsync` 方法簽名：
```csharp
public async Task<UsageReportData> QueryAllAsync(
    IReadOnlyList<ConnectionProfile> profiles,
    IProgress<string>? progress = null)
{
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
```

- [ ] **Step 5: 確認測試通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UsageReportServiceTests" -q
```

Expected: `通過: 5`

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/IUsageReportService.cs \
        src/MoldplanDbSwitcher/Services/UsageReportService.cs \
        tests/MoldplanDbSwitcher.Tests/Services/UsageReportServiceTests.cs
git commit -m "refactor: UsageReportService 改為接受外部傳入 profiles"
```

---

### Task 4: 更新 MainWindowViewModel（TDD）

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs`

此任務加入：
- `ReportSourceCallback` 屬性（`Func<Task<ReportSourceOptions?>>?`）
- `FilterConnectionsForReport(ReportSourceOptions)` 方法
- 更新 `ExportFeatureReport` 與 `ExportUsageReport` 命令，在查詢前先呼叫 `ReportSourceCallback`

- [ ] **Step 1: 更新 MainWindowViewModelTests — 新增篩選與 callback 測試**

在 `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs` 的最後（`}` 前）加入以下測試：

```csharp
    [Fact]
    public void FilterConnectionsForReport_SpecuraiOnly_ReturnsOnlySpecurai()
    {
        var vm = CreateVm();
        var options = new ReportSourceOptions(Specurai: true, Custom: false, AnsibleProduction: false, AnsibleStaging: false);

        var result = vm.FilterConnectionsForReport(options);

        Assert.All(result, c => Assert.Equal("Specurai", c.Source));
    }

    [Fact]
    public void FilterConnectionsForReport_NoneSelected_ReturnsEmpty()
    {
        var vm = CreateVm();
        var options = new ReportSourceOptions(Specurai: false, Custom: false, AnsibleProduction: false, AnsibleStaging: false);

        var result = vm.FilterConnectionsForReport(options);

        Assert.Empty(result);
    }

    [Fact]
    public async Task ExportFeatureReport_SourceCallbackReturnsNull_DoesNotQuery()
    {
        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(null);
        vm.SaveFileCallback = () => Task.FromResult<string?>(Path.GetTempFileName());

        await vm.ExportFeatureReportCommand.ExecuteAsync(null);

        await _featureReportService.DidNotReceive().QueryAllCustomerFeaturesAsync(
            Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>());
    }

    [Fact]
    public async Task ExportUsageReport_SourceCallbackReturnsNull_DoesNotQuery()
    {
        var vm = CreateVm();
        vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(null);
        vm.SaveUsageReportCallback = () => Task.FromResult<string?>(Path.GetTempFileName());

        await vm.ExportUsageReportCommand.ExecuteAsync(null);

        await _usageReportService.DidNotReceive().QueryAllAsync(
            Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>());
    }
```

同時在檔案頂部的 `using` 中加入：
```csharp
using MoldplanDbSwitcher.Models;
```
（若已有則跳過）

同時更新 `ExportFeatureReport_SetsIsExporting` 和 `ExportFeatureReport_AllFailed_ShowsError` 測試，加入 `ReportSourceCallback` 設定：

```csharp
// ExportFeatureReport_SetsIsExporting 在 ExecuteAsync 前加一行：
vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);

// ExportFeatureReport_AllFailed_ShowsError 在 ExecuteAsync 前加一行：
vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);

// ExportFeatureReport_NoSavePath_DoesNotExport 在 ExecuteAsync 前加一行：
vm.ReportSourceCallback = () => Task.FromResult<ReportSourceOptions?>(ReportSourceOptions.AllSelected);
```

更新 `_featureReportService` mock setup（因為介面簽名已改）：
```csharp
// 將：
_featureReportService.QueryAllCustomerFeaturesAsync(Arg.Any<IProgress<string>>())
    .Returns(new FeatureReportData());

// 改為：
_featureReportService.QueryAllCustomerFeaturesAsync(
    Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<IProgress<string>>())
    .Returns(new FeatureReportData());
```

- [ ] **Step 2: 確認測試失敗**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MainWindowViewModelTests" -q
```

Expected: 編譯錯誤（`FilterConnectionsForReport` 不存在、介面不符）。

- [ ] **Step 3: 更新 MainWindowViewModel**

在 `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` 中：

**3a. 新增 using（若未有）：**
```csharp
using MoldplanDbSwitcher.Models;
```

**3b. 在 `SaveUsageReportCallback` 後新增屬性：**
```csharp
public Func<Task<ReportSourceOptions?>>? ReportSourceCallback { get; set; }
```

**3c. 新增 `FilterConnectionsForReport` public 方法（放在 `GetCustomConnections` 後）：**
```csharp
public IReadOnlyList<ConnectionProfile> FilterConnectionsForReport(ReportSourceOptions options)
    => Connections.Where(c =>
        (options.Specurai && c.Source == "Specurai") ||
        (options.Custom && c.Source == "Custom") ||
        (options.AnsibleProduction && c.Source == "Ansible" && c.Name.EndsWith("- 正式")) ||
        (options.AnsibleStaging && c.Source == "Ansible" && c.Name.EndsWith("- 測試"))
    ).ToList();
```

**3d. 更新 `ExportFeatureReport` 命令**（在 `IsExporting = true;` 後、`QueryAllCustomerFeaturesAsync` 前，加入來源選擇邏輯）：

```csharp
[RelayCommand]
private async Task ExportFeatureReport()
{
    IsExporting = true;
    ProgressText = "正在查詢客戶功能...";

    try
    {
        var sourceOptions = ReportSourceCallback != null
            ? await ReportSourceCallback()
            : ReportSourceOptions.AllSelected;

        if (sourceOptions is null)
        {
            StatusMessage = "已取消匯出";
            return;
        }

        var profiles = FilterConnectionsForReport(sourceOptions);
        if (profiles.Count == 0)
        {
            StatusMessage = "未選擇任何連線來源";
            return;
        }

        var progress = new Progress<string>(msg => ProgressText = msg);
        var data = await _featureReportService.QueryAllCustomerFeaturesAsync(profiles, progress);

        if (data.Customers.Count == 0)
        {
            StatusMessage = $"所有連線查詢失敗：{string.Join(", ", data.FailedConnections)}";
            return;
        }

        var path = SaveFileCallback != null ? await SaveFileCallback() : null;
        if (path is null)
        {
            StatusMessage = "已取消匯出";
            return;
        }

        ProgressText = "正在產出 Excel...";
        await _featureReportService.ExportToExcelAsync(path, data);

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

**3e. 更新 `ExportUsageReport` 命令**（同樣模式）：

```csharp
[RelayCommand]
private async Task ExportUsageReport()
{
    IsExporting = true;
    ProgressText = "正在查詢使用工時...";

    try
    {
        var sourceOptions = ReportSourceCallback != null
            ? await ReportSourceCallback()
            : ReportSourceOptions.AllSelected;

        if (sourceOptions is null)
        {
            StatusMessage = "已取消匯出";
            return;
        }

        var profiles = FilterConnectionsForReport(sourceOptions);
        if (profiles.Count == 0)
        {
            StatusMessage = "未選擇任何連線來源";
            return;
        }

        var progress = new Progress<string>(msg => ProgressText = msg);
        var data = await _usageReportService.QueryAllAsync(profiles, progress);

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

- [ ] **Step 4: 確認測試通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MainWindowViewModelTests" -q
```

Expected: 全部通過。

- [ ] **Step 5: 全部測試通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ -q
```

Expected: `通過: 119` 或以上（原 115 + 新增 4）

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs \
        tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs
git commit -m "feat: MainWindowViewModel 加入報表來源篩選邏輯"
```

---

### Task 5: 新增 ReportSourceDialog（View + ViewModel）

**Files:**
- Create: `src/MoldplanDbSwitcher/ViewModels/ReportSourceDialogViewModel.cs`
- Create: `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml`
- Create: `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml.cs`

注意：對話框使用 Avalonia `Window`，透過 `ShowDialog<ReportSourceOptions?>` 回傳結果（與現有 `ConnectionDialog`、`SettingsDialog` 模式一致）。

- [ ] **Step 1: 建立 ReportSourceDialogViewModel**

建立 `src/MoldplanDbSwitcher/ViewModels/ReportSourceDialogViewModel.cs`：

```csharp
using CommunityToolkit.Mvvm.ComponentModel;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportSourceDialogViewModel : ObservableObject
{
    [ObservableProperty] private bool _specurai = true;
    [ObservableProperty] private bool _custom = true;
    [ObservableProperty] private bool _ansibleProduction = true;
    [ObservableProperty] private bool _ansibleStaging = true;

    public ReportSourceOptions ToOptions() =>
        new(Specurai, Custom, AnsibleProduction, AnsibleStaging);
}
```

- [ ] **Step 2: 建立 ReportSourceDialog.axaml**

建立 `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml`：

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:MoldplanDbSwitcher.ViewModels"
        x:Class="MoldplanDbSwitcher.Views.ReportSourceDialog"
        x:DataType="vm:ReportSourceDialogViewModel"
        Title="選擇報表來源"
        Width="280" Height="220"
        WindowStartupLocation="CenterOwner"
        CanResize="False">

  <StackPanel Margin="20" Spacing="12">
    <TextBlock Text="請選擇要包含的連線來源：" FontWeight="Bold" />

    <CheckBox Content="Specurai" IsChecked="{Binding Specurai}" />
    <CheckBox Content="自訂" IsChecked="{Binding Custom}" />
    <CheckBox Content="Ansible 正式" IsChecked="{Binding AnsibleProduction}" />
    <CheckBox Content="Ansible 測試" IsChecked="{Binding AnsibleStaging}" />

    <StackPanel Orientation="Horizontal" Spacing="8" HorizontalAlignment="Right" Margin="0,8,0,0">
      <Button Content="確認" Classes="accent" Click="OnConfirmClick" />
      <Button Content="取消" Click="OnCancelClick" />
    </StackPanel>
  </StackPanel>
</Window>
```

- [ ] **Step 3: 建立 ReportSourceDialog.axaml.cs**

建立 `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml.cs`：

```csharp
using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ReportSourceDialog : Window
{
    public ReportSourceDialog()
    {
        InitializeComponent();
        DataContext = new ReportSourceDialogViewModel();
    }

    private void OnConfirmClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is ReportSourceDialogViewModel vm)
            Close(vm.ToOptions());
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e)
    {
        Close(null);
    }
}
```

- [ ] **Step 4: 建置確認**

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj -q
```

Expected: `建置成功。`

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/ReportSourceDialogViewModel.cs \
        src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml \
        src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml.cs
git commit -m "feat: 新增 ReportSourceDialog 來源選擇對話框"
```

---

### Task 6: 連接 MainWindow.axaml.cs（設定 ReportSourceCallback）

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`

- [ ] **Step 1: 更新兩個匯出 click handler，在設定 SaveFileCallback 前先設定 ReportSourceCallback**

在 `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs` 中，找到 `OnExportFeatureReportClick` 方法，改為：

```csharp
private async void OnExportFeatureReportClick(object? sender, RoutedEventArgs e)
{
    if (DataContext is MainWindowViewModel vm)
    {
        vm.ReportSourceCallback = async () =>
        {
            var dialog = new ReportSourceDialog();
            return await dialog.ShowDialog<ReportSourceOptions?>(this);
        };
        vm.SaveFileCallback = async () =>
        {
            var file = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "儲存功能差異表",
                DefaultExtension = "xlsx",
                FileTypeChoices = new[]
                {
                    new FilePickerFileType("Excel 檔案") { Patterns = new[] { "*.xlsx" } }
                },
                SuggestedFileName = "客戶功能差異表"
            });
            return file?.Path.LocalPath;
        };
        await vm.ExportFeatureReportCommand.ExecuteAsync(null);
    }
}
```

找到 `OnExportUsageReportClick` 方法，改為：

```csharp
private async void OnExportUsageReportClick(object? sender, RoutedEventArgs e)
{
    if (DataContext is MainWindowViewModel vm)
    {
        vm.ReportSourceCallback = async () =>
        {
            var dialog = new ReportSourceDialog();
            return await dialog.ShowDialog<ReportSourceOptions?>(this);
        };
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

確認 `using MoldplanDbSwitcher.Models;` 已在 using 清單中。

- [ ] **Step 2: 建置確認**

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj -q
```

Expected: `建置成功。`

- [ ] **Step 3: 全部測試通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ -q
```

Expected: 全部通過，無失敗。

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs
git commit -m "feat: 匯出報表前彈出來源選擇對話框"
```

---

## 完成後驗收

手動測試：
1. `dotnet run --project src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
2. 點選「報表 → 匯出功能差異表」
3. 確認彈出四個 CheckBox 對話框
4. 取消 → StatusMessage 顯示「已取消匯出」
5. 確認（全勾）→ 繼續原有查詢流程
