# 報表來源／環境雙維度篩選 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 匯出報表前，讓使用者分別勾選「連線來源」與「環境」，匯出範圍為兩者交集。

**Architecture:** `ReportSourceOptions` 從 4 個混合欄位改為來源 3 + 環境 4 共 7 個 bool。`FilterConnectionsForReport` 改為來源與環境的 AND 判斷，環境改讀 `ConnectionProfile.Environment` 而非比對連線名稱字串。對話框沿用既有 `ReportSourceDialog`，拆成兩組 checkbox。

**Tech Stack:** .NET 9、Avalonia 11.3、CommunityToolkit.Mvvm、xUnit + NSubstitute

## Global Constraints

- 所有 UI 文字、commit 訊息、文件、註解使用繁體中文；程式碼識別符維持英文
- TDD：先寫失敗測試，確認失敗，再寫最小實作
- 連線來源字串固定為三種：`"Specurai"`、`"Custom"`、`"MoldPlan Center"`
- 環境列舉 `DatabaseEnvironment` 固定四值：`Development`、`Testing`、`Staging`、`Production`
- 四個環境選項固定顯示，沒有對應連線者 disable 並取消勾選
- 測試命名：`方法名_情境_預期結果`
- 執行測試：`dotnet test tests/MoldplanDbSwitcher.Tests/`

---

## File Structure

| 檔案 | 責任 |
|---|---|
| `src/MoldplanDbSwitcher/Models/ReportSourceOptions.cs` | 勾選結果的資料載體，同時被用來表達「哪些選項可用」 |
| `src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs` | 偵測可用選項（`GetAvailableSources`）與執行篩選（`FilterConnectionsForReport`） |
| `src/MoldplanDbSwitcher/ViewModels/ReportSourceDialogViewModel.cs` | 對話框勾選狀態與可點狀態的綁定來源 |
| `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml` | 兩組 checkbox 的版面 |

`ReportSourceDialog.axaml.cs` 與 `MainWindow.axaml.cs:25` 只傳遞 `ReportSourceOptions`，不觸及個別欄位，**不需修改**。

---

### Task 1: 篩選邏輯改為來源 × 環境交集

**Files:**
- Modify: `src/MoldplanDbSwitcher/Models/ReportSourceOptions.cs`
- Modify: `src/MoldplanDbSwitcher/ViewModels/ReportSourceDialogViewModel.cs`
- Modify: `src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs:454-466`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionSwitchDocumentViewModelTests.cs:337-357`

**Interfaces:**
- Produces: `ReportSourceOptions(bool Specurai, bool Custom, bool MoldPlanCenter, bool Development, bool Testing, bool Staging, bool Production)`，靜態屬性 `ReportSourceOptions.AllSelected`
- Produces: `ConnectionSwitchDocumentViewModel.GetAvailableSources() → ReportSourceOptions`
- Produces: `ConnectionSwitchDocumentViewModel.FilterConnectionsForReport(ReportSourceOptions) → IReadOnlyList<ConnectionProfile>`

> **關於紅燈：** C# 是強型別，改動 record 簽章會讓所有引用點編譯失敗，無法先製造「乾淨的測試紅燈」。因此本任務先把型別與來源維度改好（Step 1-4，此時專案可編譯、既有測試全綠），再於 Step 5 寫環境維度的測試看它真正失敗，Step 7 才實作環境判斷。

- [ ] **Step 1: 改寫 ReportSourceOptions**

`src/MoldplanDbSwitcher/Models/ReportSourceOptions.cs` 全檔替換為：

```csharp
namespace MoldplanDbSwitcher.Models;

/// <summary>報表匯出的篩選條件。來源與環境為兩個獨立維度，實際範圍取交集。</summary>
public record ReportSourceOptions(
    // 來源
    bool Specurai,
    bool Custom,
    bool MoldPlanCenter,
    // 環境
    bool Development,
    bool Testing,
    bool Staging,
    bool Production)
{
    public static ReportSourceOptions AllSelected =>
        new(true, true, true, true, true, true, true);
}
```

- [ ] **Step 2: 對齊 ReportSourceDialogViewModel**

`src/MoldplanDbSwitcher/ViewModels/ReportSourceDialogViewModel.cs` 全檔替換為：

```csharp
using CommunityToolkit.Mvvm.ComponentModel;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportSourceDialogViewModel : ObservableObject
{
    // 是否有該來源／環境的連線（控制 checkbox 是否可點）
    public bool HasSpecurai { get; }
    public bool HasCustom { get; }
    public bool HasMoldPlanCenter { get; }
    public bool HasDevelopment { get; }
    public bool HasTesting { get; }
    public bool HasStaging { get; }
    public bool HasProduction { get; }

    [ObservableProperty] private bool _specurai;
    [ObservableProperty] private bool _custom;
    [ObservableProperty] private bool _moldPlanCenter;
    [ObservableProperty] private bool _development;
    [ObservableProperty] private bool _testing;
    [ObservableProperty] private bool _staging;
    [ObservableProperty] private bool _production;

    public ReportSourceDialogViewModel(ReportSourceOptions available)
    {
        HasSpecurai = available.Specurai;
        HasCustom = available.Custom;
        HasMoldPlanCenter = available.MoldPlanCenter;
        HasDevelopment = available.Development;
        HasTesting = available.Testing;
        HasStaging = available.Staging;
        HasProduction = available.Production;

        // 預設只勾選實際存在的來源與環境
        _specurai = available.Specurai;
        _custom = available.Custom;
        _moldPlanCenter = available.MoldPlanCenter;
        _development = available.Development;
        _testing = available.Testing;
        _staging = available.Staging;
        _production = available.Production;
    }

    public ReportSourceOptions ToOptions() =>
        new(Specurai, Custom, MoldPlanCenter, Development, Testing, Staging, Production);
}
```

- [ ] **Step 3: 更新 GetAvailableSources 與來源維度篩選**

`src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs` 中，將 `GetAvailableSources()` 與 `FilterConnectionsForReport()` 兩個方法（檔案結尾處）替換為：

```csharp
    public ReportSourceOptions GetAvailableSources() => new(
        Specurai: Connections.Any(c => c.Source == "Specurai"),
        Custom: Connections.Any(c => c.Source == "Custom"),
        MoldPlanCenter: Connections.Any(c => c.Source == "MoldPlan Center"),
        Development: Connections.Any(c => c.Environment == DatabaseEnvironment.Development),
        Testing: Connections.Any(c => c.Environment == DatabaseEnvironment.Testing),
        Staging: Connections.Any(c => c.Environment == DatabaseEnvironment.Staging),
        Production: Connections.Any(c => c.Environment == DatabaseEnvironment.Production));

    public IReadOnlyList<ConnectionProfile> FilterConnectionsForReport(ReportSourceOptions options)
        => Connections.Where(c => MatchesSource(c, options)).ToList();

    private static bool MatchesSource(ConnectionProfile c, ReportSourceOptions o) => c.Source switch
    {
        "Specurai" => o.Specurai,
        "Custom" => o.Custom,
        "MoldPlan Center" => o.MoldPlanCenter,
        _ => false
    };
```

- [ ] **Step 4: 修正既有測試的建構參數，跑測試確認全綠**

`tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionSwitchDocumentViewModelTests.cs` 中兩處 `new ReportSourceOptions(...)` 改為：

```csharp
    [Fact]
    public void FilterConnectionsForReport_SpecuraiOnly_ReturnsOnlySpecurai()
    {
        var vm = CreateVm();
        var options = new ReportSourceOptions(
            Specurai: true, Custom: false, MoldPlanCenter: false,
            Development: true, Testing: true, Staging: true, Production: true);

        var result = vm.FilterConnectionsForReport(options);

        Assert.All(result, c => Assert.Equal("Specurai", c.Source));
    }

    [Fact]
    public void FilterConnectionsForReport_NoneSelected_ReturnsEmpty()
    {
        var vm = CreateVm();
        var options = new ReportSourceOptions(
            Specurai: false, Custom: false, MoldPlanCenter: false,
            Development: false, Testing: false, Staging: false, Production: false);

        var result = vm.FilterConnectionsForReport(options);

        Assert.Empty(result);
    }
```

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: PASS，271 通過 1 略過（環境維度尚未實作，但此時無測試涵蓋它）

- [ ] **Step 5: 寫環境維度的失敗測試**

在 `ConnectionSwitchDocumentViewModelTests.cs` 的 `FilterConnectionsForReport_NoneSelected_ReturnsEmpty` 之後插入：

```csharp
    [Fact]
    public void FilterConnectionsForReport_來源命中但環境未勾_排除()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "預備連線", Server = "s", Database = "d",
                    Environment = DatabaseEnvironment.Staging, Source = "Specurai" }
        });
        var vm = CreateVm();
        var options = new ReportSourceOptions(
            Specurai: true, Custom: false, MoldPlanCenter: false,
            Development: false, Testing: true, Staging: false, Production: true);

        var result = vm.FilterConnectionsForReport(options);

        Assert.Empty(result);
    }

    [Fact]
    public void FilterConnectionsForReport_環境命中但來源未勾_排除()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "正式連線", Server = "s", Database = "d",
                    Environment = DatabaseEnvironment.Production, Source = "Specurai" }
        });
        var vm = CreateVm();
        var options = new ReportSourceOptions(
            Specurai: false, Custom: true, MoldPlanCenter: true,
            Development: true, Testing: true, Staging: true, Production: true);

        var result = vm.FilterConnectionsForReport(options);

        Assert.Empty(result);
    }

    [Fact]
    public void FilterConnectionsForReport_依Environment欄位判斷而非連線名稱()
    {
        // 名稱不含「正式」，但 Environment 是 Production，應被「正式」勾選命中
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "GMA-Prod", Server = "s", Database = "d",
                    Environment = DatabaseEnvironment.Production, Source = "Specurai" }
        });
        var vm = CreateVm();
        var options = new ReportSourceOptions(
            Specurai: true, Custom: false, MoldPlanCenter: false,
            Development: false, Testing: false, Staging: false, Production: true);

        var result = vm.FilterConnectionsForReport(options);

        Assert.Single(result);
        Assert.Equal("GMA-Prod", result[0].Name);
    }

    [Fact]
    public void GetAvailableSources_無開發環境連線_Development為false()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "測試連線", Server = "s", Database = "d",
                    Environment = DatabaseEnvironment.Testing, Source = "Specurai" }
        });
        var vm = CreateVm();

        var available = vm.GetAvailableSources();

        Assert.False(available.Development);
        Assert.True(available.Testing);
        Assert.False(available.Staging);
        Assert.False(available.Production);
    }
```

- [ ] **Step 6: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "FilterConnectionsForReport"`
Expected: FAIL — `FilterConnectionsForReport_來源命中但環境未勾_排除` 與 `FilterConnectionsForReport_環境命中但來源未勾_排除` 失敗。

前者失敗訊息為 `Assert.Empty() Failure: Collection was not empty`（環境條件尚未生效，該連線仍被納入）。

`GetAvailableSources_無開發環境連線_Development為false` 不在此 filter 範圍內，會在 Step 8 全量執行時一併驗證；它針對 Step 3 已完成的環境偵測，屬於回歸防護，一寫即綠是預期的。

- [ ] **Step 7: 實作環境維度判斷**

在 `ConnectionSwitchDocumentViewModel.cs` 中，將 `FilterConnectionsForReport` 改為同時判斷兩個維度，並在 `MatchesSource` 之後加入 `MatchesEnvironment`：

```csharp
    public IReadOnlyList<ConnectionProfile> FilterConnectionsForReport(ReportSourceOptions options)
        => Connections.Where(c => MatchesSource(c, options) && MatchesEnvironment(c, options)).ToList();

    private static bool MatchesSource(ConnectionProfile c, ReportSourceOptions o) => c.Source switch
    {
        "Specurai" => o.Specurai,
        "Custom" => o.Custom,
        "MoldPlan Center" => o.MoldPlanCenter,
        _ => false
    };

    private static bool MatchesEnvironment(ConnectionProfile c, ReportSourceOptions o) => c.Environment switch
    {
        DatabaseEnvironment.Development => o.Development,
        DatabaseEnvironment.Testing => o.Testing,
        DatabaseEnvironment.Staging => o.Staging,
        DatabaseEnvironment.Production => o.Production,
        _ => false
    };
```

- [ ] **Step 8: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: PASS，全部通過（新增 4 個測試）

- [ ] **Step 9: Commit**

```bash
git add src/MoldplanDbSwitcher/Models/ReportSourceOptions.cs src/MoldplanDbSwitcher/ViewModels/ReportSourceDialogViewModel.cs src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionSwitchDocumentViewModelTests.cs
git commit -m "feat: 報表篩選改為來源與環境雙維度交集"
```

---

### Task 2: 補上對話框 ViewModel 的測試

**Files:**
- Create: `tests/MoldplanDbSwitcher.Tests/ViewModels/ReportSourceDialogViewModelTests.cs`

**Interfaces:**
- Consumes: Task 1 產出的 `ReportSourceOptions` 與 `ReportSourceDialogViewModel`

`ReportSourceDialogViewModel` 目前完全沒有測試覆蓋。它負責「不存在的選項要 disable 且不勾選」這條規則，值得鎖住。

- [ ] **Step 1: 寫測試**

建立 `tests/MoldplanDbSwitcher.Tests/ViewModels/ReportSourceDialogViewModelTests.cs`：

```csharp
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.ViewModels;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ReportSourceDialogViewModelTests
{
    [Fact]
    public void 建構_可用選項為false_對應屬性不勾選且不可點()
    {
        var available = new ReportSourceOptions(
            Specurai: true, Custom: false, MoldPlanCenter: true,
            Development: false, Testing: true, Staging: false, Production: true);

        var vm = new ReportSourceDialogViewModel(available);

        Assert.False(vm.HasCustom);
        Assert.False(vm.Custom);
        Assert.False(vm.HasDevelopment);
        Assert.False(vm.Development);
        Assert.False(vm.HasStaging);
        Assert.False(vm.Staging);
    }

    [Fact]
    public void 建構_可用選項為true_預設勾選且可點()
    {
        var available = new ReportSourceOptions(
            Specurai: true, Custom: false, MoldPlanCenter: true,
            Development: false, Testing: true, Staging: false, Production: true);

        var vm = new ReportSourceDialogViewModel(available);

        Assert.True(vm.HasSpecurai);
        Assert.True(vm.Specurai);
        Assert.True(vm.HasMoldPlanCenter);
        Assert.True(vm.MoldPlanCenter);
        Assert.True(vm.HasTesting);
        Assert.True(vm.Testing);
        Assert.True(vm.HasProduction);
        Assert.True(vm.Production);
    }

    [Fact]
    public void ToOptions_回傳目前勾選狀態()
    {
        var vm = new ReportSourceDialogViewModel(ReportSourceOptions.AllSelected);
        vm.Custom = false;
        vm.Staging = false;

        var result = vm.ToOptions();

        Assert.True(result.Specurai);
        Assert.False(result.Custom);
        Assert.True(result.MoldPlanCenter);
        Assert.True(result.Development);
        Assert.True(result.Testing);
        Assert.False(result.Staging);
        Assert.True(result.Production);
    }
}
```

- [ ] **Step 2: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportSourceDialogViewModelTests"`
Expected: PASS，3 個測試通過

這三個測試針對的是 Task 1 已完成的行為，屬於補齊覆蓋率而非驅動新實作，一寫即綠是預期的。

- [ ] **Step 3: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/ViewModels/ReportSourceDialogViewModelTests.cs
git commit -m "test: 補上報表來源對話框 ViewModel 測試"
```

---

### Task 3: 對話框版面拆成兩組

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml`

**Interfaces:**
- Consumes: Task 1 產出的 `ReportSourceDialogViewModel` 屬性（`Specurai`／`HasSpecurai` 等 14 個）

- [ ] **Step 1: 改寫 AXAML**

`src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml` 全檔替換為：

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:MoldplanDbSwitcher.ViewModels"
        x:Class="MoldplanDbSwitcher.Views.ReportSourceDialog"
        x:DataType="vm:ReportSourceDialogViewModel"
        Title="選擇報表來源"
        Width="280" Height="400"
        WindowStartupLocation="CenterOwner"
        CanResize="False">

  <StackPanel Margin="20" Spacing="10">
    <TextBlock Text="連線來源：" FontWeight="Bold" />
    <CheckBox Content="Specurai" IsChecked="{Binding Specurai}" IsEnabled="{Binding HasSpecurai}" />
    <CheckBox Content="自訂" IsChecked="{Binding Custom}" IsEnabled="{Binding HasCustom}" />
    <CheckBox Content="MoldPlan Center" IsChecked="{Binding MoldPlanCenter}" IsEnabled="{Binding HasMoldPlanCenter}" />

    <TextBlock Text="環境：" FontWeight="Bold" Margin="0,8,0,0" />
    <CheckBox Content="開發" IsChecked="{Binding Development}" IsEnabled="{Binding HasDevelopment}" />
    <CheckBox Content="測試" IsChecked="{Binding Testing}" IsEnabled="{Binding HasTesting}" />
    <CheckBox Content="預備" IsChecked="{Binding Staging}" IsEnabled="{Binding HasStaging}" />
    <CheckBox Content="正式" IsChecked="{Binding Production}" IsEnabled="{Binding HasProduction}" />

    <StackPanel Orientation="Horizontal" Spacing="8" HorizontalAlignment="Right" Margin="0,8,0,0">
      <Button Content="確認" Classes="accent" Click="OnConfirmClick" />
      <Button Content="取消" Click="OnCancelClick" />
    </StackPanel>
  </StackPanel>
</Window>
```

- [ ] **Step 2: 建置確認 compiled binding 無誤**

Run: `dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
Expected: Build succeeded。若有屬性名打錯，Avalonia 的 compiled binding 會在此報 `AVLN` 錯誤。

- [ ] **Step 3: 跑全部測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml
git commit -m "feat: 報表來源對話框拆成來源與環境兩組勾選"
```

---

## 驗收

實作完成後，於 app 中開啟「報表 → 匯出使用次數統計」，應看到：

- 上組三個來源勾選，下組四個環境勾選
- 目前資料下「開發／測試／預備／正式」皆可勾（Specurai 連線涵蓋開發 2 筆、測試 1 筆、預備 10 筆，MoldPlan Center 同步後涵蓋測試與正式）
- 取消勾選「預備」後確認，匯出範圍應少掉 10 筆 Specurai 連線
