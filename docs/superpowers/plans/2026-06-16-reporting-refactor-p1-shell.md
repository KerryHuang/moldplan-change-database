# Reporting 重構 P1：Shell 遷移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 App 從單一 `TabControl` 改成 Specurai 式選單列 + MDI 文件區 shell，連線切換成為主頁文件，Reporting 查詢/部署成為可開關文件。

**Architecture:** 新增 `DocumentViewModel` 抽象基底與 `IActiveConnectionService` 連線傳播中樞。把 `MainWindowViewModel` 中的連線切換邏輯抽成 `ConnectionSwitchDocumentViewModel`（`CanClose=false` 主頁），`MainWindowViewModel` 瘦身為純 shell（`Documents` 集合 + `Open*` 命令）。既有 `ReportingQueryViewModel`/`ReportingDeployViewModel` 改繼承 `DocumentViewModel`，原樣保留行為。

**Tech Stack:** .NET 9、Avalonia 11.3、CommunityToolkit.Mvvm、Microsoft.Extensions.DependencyInjection、xUnit + NSubstitute。

> 對應 spec：`docs/superpowers/specs/2026-06-16-reporting-refactor-design.md`（區塊 A、E）。
> 本計畫只涵蓋 P1。P2（部署）、P3（監控）、P4（查詢微調）各自獨立計畫，待 P1 介面落地後再撰寫。

> **重要環境提醒：** pre-commit hook 會 build + 測試；若 App 正在執行會鎖住 `MoldplanDbSwitcher.exe` 導致 build 失敗。每次 commit 前確認 App 已關閉。
> **指令參考：** 建置與測試指令見 `/dotnet-run` skill。單一測試：`dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ClassName.MethodName"`。

---

## File Structure

新增：

- `src/MoldplanDbSwitcher/ViewModels/Documents/DocumentViewModel.cs` — 文件基底
- `src/MoldplanDbSwitcher/Models/ActiveConnection.cs` — 目前連線快照 record
- `src/MoldplanDbSwitcher/Services/IActiveConnectionService.cs` — 連線傳播介面
- `src/MoldplanDbSwitcher/Services/ActiveConnectionService.cs` — 實作
- `src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs` — 連線切換文件（自 MainWindowViewModel 抽出）
- `src/MoldplanDbSwitcher/Views/Documents/ConnectionSwitchDocumentView.axaml` (+ `.axaml.cs`) — 連線切換 UI（自舊 MainWindow TabItem 抽出）
- 對應測試於 `tests/MoldplanDbSwitcher.Tests/`

修改：

- `src/MoldplanDbSwitcher/ViewModels/ReportingQueryViewModel.cs` — 改繼承 `DocumentViewModel`
- `src/MoldplanDbSwitcher/ViewModels/ReportingDeployViewModel.cs` — 改繼承 `DocumentViewModel`
- `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` — 瘦身為 shell
- `src/MoldplanDbSwitcher/Views/MainWindow.axaml` (+ `.axaml.cs`) — Menu + MDI 重構
- `src/MoldplanDbSwitcher/Program.cs` — DI 註冊調整

---

## Task 1：DocumentViewModel 抽象基底

**Files:**
- Create: `src/MoldplanDbSwitcher/ViewModels/Documents/DocumentViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/DocumentViewModelTests.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.ViewModels.Documents;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class DocumentViewModelTests
{
    private sealed class FakeDoc : DocumentViewModel
    {
        public override string DocumentType => "Fake";
    }

    [Fact]
    public void DocumentKey_Defaults_ToDocumentType()
    {
        var doc = new FakeDoc();
        Assert.Equal("Fake", doc.DocumentKey);
    }

    [Fact]
    public void CanClose_DefaultsTrue()
    {
        Assert.True(new FakeDoc().CanClose);
    }

    [Fact]
    public void CloseCommand_RaisesCloseRequested_WithSelf()
    {
        var doc = new FakeDoc();
        DocumentViewModel? raised = null;
        doc.CloseRequested += d => raised = d;

        doc.CloseCommand.Execute(null);

        Assert.Same(doc, raised);
    }

    [Fact]
    public async Task UseConnectionAsync_DefaultNoOp_DoesNotThrow()
    {
        var doc = new FakeDoc();
        await doc.UseConnectionAsync(new ActiveConnection("cs", "db", null));
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "DocumentViewModelTests"`
Expected: 編譯失敗（`DocumentViewModel`、`ActiveConnection` 不存在）。

- [ ] **Step 3: 建立 ActiveConnection（Task 2 會補測試，這裡先給最小型別讓 Task 1 編譯）**

Create `src/MoldplanDbSwitcher/Models/ActiveConnection.cs`：

```csharp
namespace MoldplanDbSwitcher.Models;

/// <summary>目前作用中連線的快照，供已開啟文件重指向。</summary>
public record ActiveConnection(string ConnectionString, string Database, ConnectionProfile? Profile);
```

- [ ] **Step 4: 實作 DocumentViewModel**

Create `src/MoldplanDbSwitcher/ViewModels/Documents/DocumentViewModel.cs`：

```csharp
using System;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.ViewModels.Documents;

/// <summary>MDI 文件基底：每個功能頁為一個子類。</summary>
public abstract partial class DocumentViewModel : ObservableObject
{
    /// <summary>型別識別字串，用於 DataTemplate 路由與預設 singleton 鍵。</summary>
    public abstract string DocumentType { get; }

    /// <summary>singleton 鍵；同鍵同時間只開一份。預設＝DocumentType。</summary>
    public virtual string DocumentKey => DocumentType;

    [ObservableProperty]
    private string _title = string.Empty;

    /// <summary>tab 圖示（emoji 或符號）。</summary>
    public virtual string Icon => string.Empty;

    /// <summary>是否可關閉；主頁文件設 false。</summary>
    public virtual bool CanClose => true;

    /// <summary>要求關閉本文件時觸發，由 shell 訂閱移除。</summary>
    public event Action<DocumentViewModel>? CloseRequested;

    [RelayCommand]
    private void Close() => CloseRequested?.Invoke(this);

    /// <summary>連線變更時各文件覆寫重指向；預設不做事。</summary>
    public virtual Task UseConnectionAsync(ActiveConnection connection) => Task.CompletedTask;
}
```

- [ ] **Step 5: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "DocumentViewModelTests"`
Expected: PASS（4 個測試）。

- [ ] **Step 6: 確認 App 已關閉後 commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/Documents/DocumentViewModel.cs \
        src/MoldplanDbSwitcher/Models/ActiveConnection.cs \
        tests/MoldplanDbSwitcher.Tests/ViewModels/DocumentViewModelTests.cs
git commit -m "feat: 新增 DocumentViewModel 文件基底與 ActiveConnection 快照"
```

---

## Task 2：IActiveConnectionService 連線傳播中樞

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IActiveConnectionService.cs`
- Create: `src/MoldplanDbSwitcher/Services/ActiveConnectionService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ActiveConnectionServiceTests.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class ActiveConnectionServiceTests
{
    [Fact]
    public void Current_InitiallyNull()
    {
        var svc = new ActiveConnectionService();
        Assert.Null(svc.Current);
    }

    [Fact]
    public void SetCurrent_UpdatesCurrent_AndRaisesChanged()
    {
        var svc = new ActiveConnectionService();
        ActiveConnection? raised = null;
        svc.Changed += c => raised = c;

        var conn = new ActiveConnection("cs", "db", null);
        svc.SetCurrent(conn);

        Assert.Same(conn, svc.Current);
        Assert.Same(conn, raised);
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ActiveConnectionServiceTests"`
Expected: 編譯失敗（型別不存在）。

- [ ] **Step 3: 實作介面**

Create `src/MoldplanDbSwitcher/Services/IActiveConnectionService.cs`：

```csharp
using System;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

/// <summary>持有目前作用中連線，並在變更時通知訂閱者（已開啟文件）。</summary>
public interface IActiveConnectionService
{
    ActiveConnection? Current { get; }
    event Action<ActiveConnection>? Changed;
    void SetCurrent(ActiveConnection connection);
}
```

- [ ] **Step 4: 實作 service**

Create `src/MoldplanDbSwitcher/Services/ActiveConnectionService.cs`：

```csharp
using System;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public sealed class ActiveConnectionService : IActiveConnectionService
{
    public ActiveConnection? Current { get; private set; }
    public event Action<ActiveConnection>? Changed;

    public void SetCurrent(ActiveConnection connection)
    {
        Current = connection;
        Changed?.Invoke(connection);
    }
}
```

- [ ] **Step 5: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ActiveConnectionServiceTests"`
Expected: PASS（2 個測試）。

- [ ] **Step 6: commit**

```bash
git add src/MoldplanDbSwitcher/Services/IActiveConnectionService.cs \
        src/MoldplanDbSwitcher/Services/ActiveConnectionService.cs \
        tests/MoldplanDbSwitcher.Tests/Services/ActiveConnectionServiceTests.cs
git commit -m "feat: 新增 IActiveConnectionService 連線傳播中樞"
```

---

## Task 3：ReportingQueryViewModel 改為文件

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/ReportingQueryViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingQueryViewModelTests.cs`（既有檔，新增測試）

說明：保留所有既有成員與行為，只把基底由 `ObservableObject` 換成 `DocumentViewModel`，新增文件覆寫，並把 `UseConnectionAsync(ActiveConnection)` 委派給既有的 `UseConnectionAsync(string)`。

- [ ] **Step 1: 新增失敗測試**

於既有 `ReportingQueryViewModelTests.cs` 加入：

```csharp
[Fact]
public void DocumentType_And_Title_AreSet()
{
    var vm = CreateViewModel();   // 沿用該測試類別既有工廠/建構方式
    Assert.Equal("ReportingQuery", vm.DocumentType);
    Assert.Equal("Reporting 查詢", vm.Title);
    Assert.True(vm.CanClose);
}
```

> 若測試類別沒有 `CreateViewModel()` 輔助，改用該檔現有的 ViewModel 建構方式（注入兩個 `Func<string, ...>` 與 connStr）。

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingQueryViewModelTests.DocumentType_And_Title_AreSet"`
Expected: FAIL（`DocumentType` 不存在 / 編譯失敗）。

- [ ] **Step 3: 改基底與新增覆寫**

於 `ReportingQueryViewModel.cs`：

1. 改 class 宣告：
   `public partial class ReportingQueryViewModel : ObservableObject`
   → `public partial class ReportingQueryViewModel : DocumentViewModel`
2. 加 `using MoldplanDbSwitcher.ViewModels.Documents;` 與 `using MoldplanDbSwitcher.Models;`（若未引）。
3. 移除 class 內既有的 `[ObservableProperty] ... Title`（若有同名）以免與基底衝突；在建構式結尾設定 `Title = "Reporting 查詢";`。
4. 新增覆寫成員：

```csharp
public override string DocumentType => "ReportingQuery";

public override Task UseConnectionAsync(ActiveConnection connection)
    => UseConnectionAsync(connection.ConnectionString);
```

> 既有 `public async Task UseConnectionAsync(string connectionString)` 保留不動；這裡新增的是 `ActiveConnection` 多載覆寫。

- [ ] **Step 4: 跑測試確認通過（含既有測試回歸）**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingQueryViewModelTests"`
Expected: PASS（含新測試與所有既有測試）。

- [ ] **Step 5: commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/ReportingQueryViewModel.cs \
        tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingQueryViewModelTests.cs
git commit -m "refactor: ReportingQueryViewModel 改為 DocumentViewModel"
```

---

## Task 4：ReportingDeployViewModel 改為文件

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/ReportingDeployViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingDeployViewModelTests.cs`（既有檔）

- [ ] **Step 1: 新增失敗測試**

```csharp
[Fact]
public void DocumentType_And_Title_AreSet()
{
    var vm = CreateViewModel();   // 沿用既有建構方式
    Assert.Equal("ReportingDeploy", vm.DocumentType);
    Assert.Equal("Reporting 部署", vm.Title);
    Assert.True(vm.CanClose);
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingDeployViewModelTests.DocumentType_And_Title_AreSet"`
Expected: FAIL。

- [ ] **Step 3: 改基底與新增覆寫**

於 `ReportingDeployViewModel.cs`：

1. `: ObservableObject` → `: DocumentViewModel`；補 `using`。
2. 建構式結尾設 `Title = "Reporting 部署";`（若有同名 Title ObservableProperty 先移除）。
3. 新增：

```csharp
public override string DocumentType => "ReportingDeploy";

public override Task UseConnectionAsync(ActiveConnection connection)
    => UseConnectionAsync(connection.ConnectionString, connection.Database);
```

> 既有 `UseConnectionAsync(string connectionString, string databaseName)` 保留不動。

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingDeployViewModelTests"`
Expected: PASS。

- [ ] **Step 5: commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/ReportingDeployViewModel.cs \
        tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingDeployViewModelTests.cs
git commit -m "refactor: ReportingDeployViewModel 改為 DocumentViewModel"
```

---

## Task 5：ConnectionSwitchDocumentViewModel（自 MainWindowViewModel 抽出）

**Files:**
- Create: `src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionSwitchDocumentViewModelTests.cs`

說明：把 `MainWindowViewModel` 中**連線切換相關**的成員整段搬到新文件類別。搬移清單（逐一從 `MainWindowViewModel.cs` 剪下）：

- 欄位：`_connectionSource`、`_serverTxtService`、`_settingsService`、`_featureReportService`、`_connectionExportService`、`_usageReportService`、`_ansibleSyncService`、`_appSettingsService`、`_appSettingsDevService`、`_connectionFactory`、`_ansibleConnections`
- 屬性：`Connections`、`SelectedConnection`、`ServerTxtFiles`、`PreviewBefore`、`PreviewAfter`、`StatusMessage`、`ShowSpecurai`、`ShowCustom`、`ShowAnsible`、`IsSyncingAnsible`、`CanSyncAnsible`、`HasDevDirectory`、`IsExporting`、`ProgressText`
- 回呼：`ApplyDevDialogCallback`、`ConfirmCallback`、`SaveFileCallback`、`SaveUsageReportCallback`、`ReportSourceCallback`
- 公開存取器：`ConnectionExportService`、`SettingsServicePublic`、`GetConnectionsForExport`、`GetCustomConnections`、`GetAvailableSources`、`FilterConnectionsForReport`、`AddCustomConnection`、`DeleteCustomConnection`、`NotifyCanSyncAnsibleChanged`、`NotifyHasDevDirectoryChanged`
- 命令/方法：`ApplyDevAsync`、`LoadConnections`、`SyncAnsible`、`DiscoverServerTxtFiles`、`UpdatePreview`、`ApplyChanges`、`ExportFeatureReport`、`ExportUsageReport`、`RefreshAll`、`OnShowSpecuraiChanged`/`OnShowCustomChanged`/`OnShowAnsibleChanged`、`OnIsSyncingAnsibleChanged`
- partial 方法 `OnSelectedConnectionChanged`：**修改**為改呼叫 `IActiveConnectionService.SetCurrent(...)` 取代直接戳 Reporting VM（見 Step 3）。

> `ServerTxtFileItem` class（MainWindowViewModel.cs 第 490–497 行）一併搬到本檔尾或獨立檔。
> 更新/版本檢查（`UpdateAvailable`/`CheckForUpdatesAsync`/`DismissUpdate`）**留在 shell**（Task 6），不要搬。

- [ ] **Step 1: 寫失敗測試**

```csharp
using System.Collections.Generic;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Services.AnsibleSync;
using MoldplanDbSwitcher.ViewModels.Documents;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ConnectionSwitchDocumentViewModelTests
{
    private static ConnectionSwitchDocumentViewModel Create(
        IConnectionSourceService? source = null,
        IActiveConnectionService? active = null)
    {
        source ??= Substitute.For<IConnectionSourceService>();
        source.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>());
        source.LoadCustomConnections().Returns(new List<ConnectionProfile>());

        var serverTxt = Substitute.For<IServerTxtService>();
        serverTxt.DiscoverPaths().Returns(new List<string>());

        var settings = Substitute.For<ISettingsService>();
        var featureReport = Substitute.For<IFeatureReportService>();
        var export = Substitute.For<IConnectionExportService>();
        var usage = Substitute.For<IUsageReportService>();
        var ansible = Substitute.For<IAnsibleSyncService>();
        var appSettings = Substitute.For<IAppSettingsService>();
        appSettings.Load().Returns(new AppSettings());
        var appDev = Substitute.For<IAppSettingsDevService>();
        var factory = Substitute.For<ISqlConnectionFactory>();
        active ??= new ActiveConnectionService();

        return new ConnectionSwitchDocumentViewModel(
            source, serverTxt, settings, featureReport, export, usage,
            ansible, appSettings, appDev, factory, active);
    }

    [Fact]
    public void DocumentType_IsConnectionSwitch_AndCannotClose()
    {
        var vm = Create();
        Assert.Equal("ConnectionSwitch", vm.DocumentType);
        Assert.False(vm.CanClose);
        Assert.Equal("連線切換", vm.Title);
    }

    [Fact]
    public void SelectingConnection_PushesToActiveConnectionService()
    {
        var source = Substitute.For<IConnectionSourceService>();
        source.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "A", Server = "S", Database = "DB1" }
        });
        source.LoadCustomConnections().Returns(new List<ConnectionProfile>());
        var active = new ActiveConnectionService();
        ActiveConnection? pushed = null;
        active.Changed += c => pushed = c;

        var vm = Create(source, active);   // 建構時 LoadConnections 會選第一筆

        Assert.NotNull(pushed);
        Assert.Equal("DB1", pushed!.Database);
    }
}
```

> 若 `AppSettings` 預設建構式不存在或 `ISqlConnectionFactory.Create` 需特定回傳，依既有測試（如 `MainWindowViewModelTests`，若存在）中的 mock 設定方式對齊。

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionSwitchDocumentViewModelTests"`
Expected: 編譯失敗（型別不存在）。

- [ ] **Step 3: 建立文件類別（搬移 + 接 ActiveConnection）**

Create `src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs`，將上方清單成員自 `MainWindowViewModel.cs` 整段搬入，類別宣告為：

```csharp
public partial class ConnectionSwitchDocumentViewModel : DocumentViewModel
{
    public override string DocumentType => "ConnectionSwitch";
    public override bool CanClose => false;

    // ... 搬入的欄位 / 屬性 / 命令 ...

    private readonly IActiveConnectionService _activeConnection;

    public ConnectionSwitchDocumentViewModel(
        IConnectionSourceService connectionSource,
        IServerTxtService serverTxtService,
        ISettingsService settingsService,
        IFeatureReportService featureReportService,
        IConnectionExportService connectionExportService,
        IUsageReportService usageReportService,
        IAnsibleSyncService ansibleSyncService,
        IAppSettingsService appSettingsService,
        IAppSettingsDevService appSettingsDevService,
        ISqlConnectionFactory connectionFactory,
        IActiveConnectionService activeConnection)
    {
        // ... 指派搬入欄位（同舊建構式） ...
        _activeConnection = activeConnection;
        Title = "連線切換";

        LoadConnections();
        DiscoverServerTxtFiles();
    }

    partial void OnSelectedConnectionChanged(ConnectionProfile? value)
    {
        UpdatePreview();
        if (value == null) return;
        var connStr = _connectionFactory.Create(value).ConnectionString;
        _activeConnection.SetCurrent(new ActiveConnection(connStr, value.Database, value));
    }
}
```

關鍵差異（相對舊 `MainWindowViewModel`）：

- 舊 `OnSelectedConnectionChanged` 直接 `ReportingQuery.UseConnectionAsync` / `ReportingDeploy.UseConnectionAsync` → 改為 `_activeConnection.SetCurrent(...)`，由 shell 統一傳播。
- 建構式移除 `ReportingQueryViewModel`/`ReportingDeployViewModel`/`IUpdateCheckService` 參數（這些留 shell）。
- `_ = CheckForUpdatesAsync();` 不搬。

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionSwitchDocumentViewModelTests"`
Expected: PASS（2 個測試）。

> 此時專案整體尚無法編譯（`MainWindowViewModel` 仍引用已搬走成員）——Task 6 修正。可先只跑本 filter；若 test 專案因 `MainWindowViewModel` 編譯失敗而連帶失敗，將 Task 5、6 視為同一 commit 邊界，先完成 Task 6 Step 3 再一起驗證。

- [ ] **Step 5: commit（與 Task 6 可合併；若分開則此處先不跑全測）**

```bash
git add src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs \
        tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionSwitchDocumentViewModelTests.cs
git commit -m "feat: 新增 ConnectionSwitchDocumentViewModel（自 MainWindowViewModel 抽出連線切換）"
```

---

## Task 6：MainWindowViewModel 瘦身為 shell

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs`（既有或新建）

說明：移除所有已搬至 Task 5 的成員，保留更新橫幅（`UpdateAvailable`/`UpdateBannerText`/`UpdateReleaseUrl`/`CheckForUpdatesAsync`/`DismissUpdate`）。新增文件管理。

- [ ] **Step 1: 寫失敗測試**

```csharp
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;
using MoldplanDbSwitcher.ViewModels.Documents;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class MainWindowViewModelTests
{
    private static MainWindowViewModel Create()
    {
        var connSwitch = /* 用 Task 5 測試的 Create() 同法建一個 ConnectionSwitchDocumentViewModel */;
        var query = Substitute.For<ReportingQueryViewModel>();   // 若無無參數建構式，改用真實工廠（見備註）
        var deploy = Substitute.For<ReportingDeployViewModel>();
        var update = Substitute.For<IUpdateCheckService>();
        var active = new ActiveConnectionService();
        var appSettings = Substitute.For<IAppSettingsService>();
        appSettings.Load().Returns(new Models.AppSettings());

        return new MainWindowViewModel(
            connSwitch,
            () => query,
            () => deploy,
            active, update, appSettings);
    }

    [Fact]
    public void Startup_OpensConnectionSwitch_AsActiveDocument()
    {
        var vm = Create();
        Assert.Single(vm.Documents);
        Assert.Equal("ConnectionSwitch", vm.Documents[0].DocumentType);
        Assert.Same(vm.Documents[0], vm.SelectedDocument);
    }

    [Fact]
    public void OpenReportingQuery_AddsDocument_AndActivates()
    {
        var vm = Create();
        vm.OpenReportingQueryCommand.Execute(null);
        Assert.Contains(vm.Documents, d => d.DocumentType == "ReportingQuery");
        Assert.Equal("ReportingQuery", vm.SelectedDocument!.DocumentType);
    }

    [Fact]
    public void OpenReportingQuery_Twice_DoesNotDuplicate()
    {
        var vm = Create();
        vm.OpenReportingQueryCommand.Execute(null);
        vm.OpenReportingQueryCommand.Execute(null);
        Assert.Equal(1, vm.Documents.Count(d => d.DocumentType == "ReportingQuery"));
    }

    [Fact]
    public void CloseDocument_RemovesIt_ButKeepsPinnedHome()
    {
        var vm = Create();
        vm.OpenReportingQueryCommand.Execute(null);
        var query = vm.Documents.First(d => d.DocumentType == "ReportingQuery");

        query.CloseCommand.Execute(null);
        Assert.DoesNotContain(query, vm.Documents);

        // 主頁 CanClose=false，Close 不應移除
        var home = vm.Documents.First(d => d.DocumentType == "ConnectionSwitch");
        home.CloseCommand.Execute(null);
        Assert.Contains(home, vm.Documents);
    }
}
```

> 備註：若 `ReportingQueryViewModel`/`ReportingDeployViewModel` 無法用 `Substitute.For`（無虛擬建構式），改用 Task 5 測試的真實工廠建構，或新增測試輔助 `ReportingTestFactory`。重點是驗證 shell 的文件開關邏輯，不依賴 Reporting 內部行為。

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MainWindowViewModelTests"`
Expected: FAIL（新建構式簽章不符 / `Documents` 不存在）。

- [ ] **Step 3: 重寫 MainWindowViewModel 為 shell**

Replace `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` 內容為：

```csharp
using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels.Documents;

namespace MoldplanDbSwitcher.ViewModels;

public partial class MainWindowViewModel : ObservableObject
{
    private readonly Func<ReportingQueryViewModel> _queryFactory;
    private readonly Func<ReportingDeployViewModel> _deployFactory;
    private readonly IActiveConnectionService _activeConnection;
    private readonly IUpdateCheckService _updateCheckService;
    private readonly IAppSettingsService _appSettingsService;

    public ConnectionSwitchDocumentViewModel ConnectionSwitch { get; }

    [ObservableProperty] private ObservableCollection<DocumentViewModel> _documents = [];
    [ObservableProperty] private DocumentViewModel? _selectedDocument;

    [ObservableProperty] private bool _updateAvailable;
    [ObservableProperty] private string _updateBannerText = "";
    [ObservableProperty] private string? _updateReleaseUrl;

    public MainWindowViewModel(
        ConnectionSwitchDocumentViewModel connectionSwitch,
        Func<ReportingQueryViewModel> queryFactory,
        Func<ReportingDeployViewModel> deployFactory,
        IActiveConnectionService activeConnection,
        IUpdateCheckService updateCheckService,
        IAppSettingsService appSettingsService)
    {
        ConnectionSwitch = connectionSwitch;
        _queryFactory = queryFactory;
        _deployFactory = deployFactory;
        _activeConnection = activeConnection;
        _updateCheckService = updateCheckService;
        _appSettingsService = appSettingsService;

        _activeConnection.Changed += OnActiveConnectionChanged;

        OpenDocument(connectionSwitch);   // 主頁
        _ = CheckForUpdatesAsync();
    }

    private void OnActiveConnectionChanged(ActiveConnection conn)
    {
        foreach (var doc in Documents)
            _ = doc.UseConnectionAsync(conn);
    }

    private T OpenOrActivate<T>(Func<T> factory) where T : DocumentViewModel
    {
        var key = factory is null ? typeof(T).Name : null;
        var existing = Documents.OfType<T>().FirstOrDefault();
        if (existing != null) { SelectedDocument = existing; return existing; }

        var doc = factory!();
        OpenDocument(doc);
        // 新開文件立即套用目前連線
        if (_activeConnection.Current is { } cur)
            _ = doc.UseConnectionAsync(cur);
        return doc;
    }

    private void OpenDocument(DocumentViewModel doc)
    {
        doc.CloseRequested += OnDocumentCloseRequested;
        Documents.Add(doc);
        SelectedDocument = doc;
    }

    private void OnDocumentCloseRequested(DocumentViewModel doc)
    {
        if (!doc.CanClose) return;
        doc.CloseRequested -= OnDocumentCloseRequested;
        Documents.Remove(doc);
        if (SelectedDocument == doc)
            SelectedDocument = Documents.LastOrDefault();
    }

    [RelayCommand] private void OpenReportingQuery() => OpenOrActivate(_queryFactory);
    [RelayCommand] private void OpenReportingDeploy() => OpenOrActivate(_deployFactory);

    private async Task CheckForUpdatesAsync()
    {
        try
        {
            var token = _appSettingsService.Load().GitHubToken;
            var info = await _updateCheckService.CheckAsync(token);
            if (info == null) return;
            UpdateReleaseUrl = info.ReleaseUrl;
            var current = Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "?";
            UpdateBannerText = $"🎉 有新版 v{info.LatestVersion} 可用（目前 v{current}）";
            UpdateAvailable = true;
        }
        catch { /* 靜音 */ }
    }

    [RelayCommand] private void DismissUpdate() => UpdateAvailable = false;
}
```

> `OpenOrActivate` 內 `key` 變數其實未用到（singleton 以型別判斷即可）——可刪。若日後同型別多實例需求，再改用 `DocumentKey`。
> 此版 shell 不再持有 `ReportingQuery`/`ReportingDeploy` 單例屬性；改由工廠按需建立。

- [ ] **Step 4: 跑全測試確認通過（含 Task 5）**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: 全綠（含 DocumentViewModel、ActiveConnectionService、ConnectionSwitch、MainWindow、既有 Reporting 測試）。

- [ ] **Step 5: commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs \
        tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs
git commit -m "refactor: MainWindowViewModel 瘦身為 MDI shell（文件管理 + 連線傳播）"
```

---

## Task 7：Program.cs DI 註冊調整

**Files:**
- Modify: `src/MoldplanDbSwitcher/Program.cs`

說明：註冊 `IActiveConnectionService`（singleton）、`ConnectionSwitchDocumentViewModel`（singleton）、Reporting 文件工廠（`Func<...>`），調整 `MainWindowViewModel` 建構依賴。Reporting 文件改 transient（按需建立）。

- [ ] **Step 1: 改寫 ConfigureServices 相關段落**

於 `Program.cs` `ConfigureServices`：

1. 在既有 service 註冊後加：
```csharp
services.AddSingleton<IActiveConnectionService, ActiveConnectionService>();
```

2. 移除舊的 `ReportingQueryViewModel`/`ReportingDeployViewModel` singleton 註冊（第 49–72 行），改為 transient：
```csharp
services.AddTransient<ReportingQueryViewModel>(sp =>
{
    var factory = sp.GetRequiredService<ISqlConnectionFactory>();
    var settings = sp.GetRequiredService<ISettingsService>();
    var profile = settings.LoadProfiles().FirstOrDefault();
    var connStr = profile != null ? factory.Create(profile).ConnectionString : "";
    return new ReportingQueryViewModel(
        sp.GetRequiredService<Func<string, IReportingObjectService>>(),
        sp.GetRequiredService<Func<string, IReportingQueryService>>(),
        connStr);
});

services.AddTransient<ReportingDeployViewModel>(sp =>
{
    var factory = sp.GetRequiredService<ISqlConnectionFactory>();
    var settings = sp.GetRequiredService<ISettingsService>();
    var profile = settings.LoadProfiles().FirstOrDefault();
    var connStr = profile != null ? factory.Create(profile).ConnectionString : "";
    return new ReportingDeployViewModel(
        sp.GetRequiredService<Func<string, IReportingObjectService>>(),
        sp.GetRequiredService<Func<string, IReportingDeployService>>(),
        connStr,
        profile?.Database ?? "");
});
```

3. 註冊連線切換文件（singleton，主頁唯一）：
```csharp
services.AddSingleton<ConnectionSwitchDocumentViewModel>();
```

4. `MainWindowViewModel` 改為由 DI 解析建構式（仍 `AddTransient`），確保其六個依賴皆已註冊：`ConnectionSwitchDocumentViewModel`、`Func<ReportingQueryViewModel>`、`Func<ReportingDeployViewModel>`、`IActiveConnectionService`、`IUpdateCheckService`、`IAppSettingsService`。
   - `Func<T>` 工廠：Microsoft.Extensions.DependencyInjection 不自動提供 `Func<T>`，需顯式註冊：
```csharp
services.AddTransient<Func<ReportingQueryViewModel>>(sp => () => sp.GetRequiredService<ReportingQueryViewModel>());
services.AddTransient<Func<ReportingDeployViewModel>>(sp => () => sp.GetRequiredService<ReportingDeployViewModel>());
```

5. 確認 `using System;` 已存在（`Func<>`）。

- [ ] **Step 2: build 確認可編譯**

Run: `dotnet build src/MoldplanDbSwitcher/`
Expected: build 成功（0 error）。

- [ ] **Step 3: commit**

```bash
git add src/MoldplanDbSwitcher/Program.cs
git commit -m "chore: DI 註冊 ActiveConnectionService 與 Reporting 文件工廠"
```

---

## Task 8：MainWindow.axaml 改為 Menu + MDI

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`

說明：頂部 `Menu`、保留更新橫幅與「目前連線」列（綁 `ConnectionSwitch`）、中央 MDI `TabControl`（綁 `Documents`）+ per-VM `DataTemplate`。連線切換 UI 移到 `ConnectionSwitchDocumentView`（Task 9）。

- [ ] **Step 1: 改寫 MainWindow.axaml**

Replace 內容為：

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:MoldplanDbSwitcher.ViewModels"
        xmlns:docs="using:MoldplanDbSwitcher.ViewModels.Documents"
        xmlns:views="using:MoldplanDbSwitcher.Views"
        xmlns:dviews="using:MoldplanDbSwitcher.Views.Documents"
        xmlns:models="using:MoldplanDbSwitcher.Models"
        x:Class="MoldplanDbSwitcher.Views.MainWindow"
        x:DataType="vm:MainWindowViewModel"
        Title="資料庫連線切換工具"
        Icon="/Assets/app-icon.ico"
        Width="980" Height="700"
        WindowStartupLocation="CenterScreen">

  <DockPanel>
    <!-- 選單列 -->
    <Menu DockPanel.Dock="Top">
      <MenuItem Header="檔案(_F)">
        <MenuItem Header="匯出連線設定(_X)" Click="OnExportConnectionsClick" />
        <MenuItem Header="匯入連線設定(_I)" Click="OnImportConnectionsClick" />
        <Separator />
        <MenuItem Header="設定(_S)" Click="OnSettingsClick" />
        <Separator />
        <MenuItem Header="結束(_Q)" Click="OnExitClick" />
      </MenuItem>
      <MenuItem Header="檢視(_V)">
        <MenuItem Header="關閉目前分頁(_W)" Command="{Binding SelectedDocument.CloseCommand}" />
      </MenuItem>
      <MenuItem Header="報表(_R)">
        <MenuItem Header="Reporting 查詢(_Q)" Command="{Binding OpenReportingQueryCommand}" />
        <MenuItem Header="Reporting 部署(_D)" Command="{Binding OpenReportingDeployCommand}" />
        <Separator />
        <MenuItem Header="匯出功能差異表(_F)" Click="OnExportFeatureReportClick"
                  IsEnabled="{Binding !ConnectionSwitch.IsExporting}" />
        <MenuItem Header="匯出使用次數統計(_U)" Click="OnExportUsageReportClick"
                  IsEnabled="{Binding !ConnectionSwitch.IsExporting}" />
      </MenuItem>
    </Menu>

    <!-- 更新橫幅 -->
    <Border DockPanel.Dock="Top" Padding="8" Margin="8,8,8,0"
            Background="#1F5A2D" CornerRadius="4"
            IsVisible="{Binding UpdateAvailable}">
      <StackPanel Orientation="Horizontal" Spacing="12">
        <TextBlock Text="{Binding UpdateBannerText}" Foreground="White" VerticalAlignment="Center" />
        <Button Content="下載新版" Click="OnDownloadUpdateClick" />
        <Button Content="稍後" Command="{Binding DismissUpdateCommand}" />
      </StackPanel>
    </Border>

    <!-- 目前連線列（綁主頁文件） -->
    <Border DockPanel.Dock="Top" Padding="8" Margin="8"
            BorderBrush="#444" BorderThickness="1" CornerRadius="4">
      <StackPanel Orientation="Horizontal" Spacing="8">
        <TextBlock Text="目前連線：" VerticalAlignment="Center" FontWeight="Bold" />
        <ComboBox ItemsSource="{Binding ConnectionSwitch.Connections}"
                  SelectedItem="{Binding ConnectionSwitch.SelectedConnection, Mode=TwoWay}"
                  Width="440">
          <ComboBox.ItemTemplate>
            <DataTemplate DataType="models:ConnectionProfile">
              <TextBlock Text="{Binding Converter={StaticResource ConnectionProfileDisplayConverter}}" />
            </DataTemplate>
          </ComboBox.ItemTemplate>
        </ComboBox>
      </StackPanel>
    </Border>

    <!-- MDI 文件區 -->
    <TabControl Margin="8,0,8,8"
                ItemsSource="{Binding Documents}"
                SelectedItem="{Binding SelectedDocument, Mode=TwoWay}">
      <TabControl.ItemTemplate>
        <DataTemplate DataType="docs:DocumentViewModel">
          <StackPanel Orientation="Horizontal" Spacing="6">
            <TextBlock Text="{Binding Title}" VerticalAlignment="Center" />
            <Button Content="✕" Padding="4,0" FontSize="10"
                    Command="{Binding CloseCommand}"
                    IsVisible="{Binding CanClose}" />
          </StackPanel>
        </DataTemplate>
      </TabControl.ItemTemplate>
      <TabControl.ContentTemplate>
        <DataTemplate DataType="docs:DocumentViewModel">
          <ContentControl Content="{Binding}">
            <ContentControl.DataTemplates>
              <DataTemplate DataType="docs:ConnectionSwitchDocumentViewModel">
                <dviews:ConnectionSwitchDocumentView />
              </DataTemplate>
              <DataTemplate DataType="vm:ReportingQueryViewModel">
                <views:ReportingQueryPage />
              </DataTemplate>
              <DataTemplate DataType="vm:ReportingDeployViewModel">
                <views:ReportingDeployPage />
              </DataTemplate>
            </ContentControl.DataTemplates>
          </ContentControl>
        </DataTemplate>
      </TabControl.ContentTemplate>
    </TabControl>
  </DockPanel>
</Window>
```

> 註：`ReportingQueryPage`/`ReportingDeployPage` 原本由 `DataContext="{Binding ReportingQuery}"` 注入；改為 MDI 後 `ContentControl.Content` 即文件 VM 本身，頁面 `x:DataType` 已是對應 VM，故移除頁面標籤上的 `DataContext` 綁定（直接 `<views:ReportingQueryPage />`）。

- [ ] **Step 2: 調整 MainWindow.axaml.cs**

於 `MainWindow.axaml.cs`：

1. 移除 `OnTopConnectionChanged`（不再用 SelectionChanged 事件；改雙向綁定）。
2. 所有對話框/匯出回呼方法（`OnExportFeatureReportClick`、`OnExportUsageReportClick`、`OnAddConnectionClick`、`OnDeleteConnectionClick`、`OnExportConnectionsClick`、`OnImportConnectionsClick`、`CreateReportSourceCallback`、`SetupApplyDevCallback`、`OnDataContextChanged`）改為對 `vm.ConnectionSwitch` 操作（而非 `vm`）。例如：

```csharp
private async void OnAddConnectionClick(object? sender, RoutedEventArgs e)
{
    var dialog = new ConnectionDialog();
    var result = await dialog.ShowDialog<ConnectionDialogViewModel?>(this);
    if (result is not null && DataContext is MainWindowViewModel vm)
        vm.ConnectionSwitch.AddCustomConnection(result.Name, result.Server, result.Database, result.Environment);
}
```

   - `CreateReportSourceCallback`、`SaveFileCallback`、`SaveUsageReportCallback`、`ReportSourceCallback`、`ExportFeatureReportCommand`、`ExportUsageReportCommand`、`ApplyDevDialogCallback`、`ConfirmCallback`、`GetAvailableSources`、`GetConnectionsForExport`、`GetCustomConnections`、`ConnectionExportService`、`SettingsServicePublic`、`LoadConnectionsCommand`、`StatusMessage` 全部改成 `vm.ConnectionSwitch.<member>`。
   - `OnDataContextChanged` 內 `SetupApplyDevCallback(vm)` 改為 `SetupApplyDevCallback(vm.ConnectionSwitch)`，方法簽章改收 `ConnectionSwitchDocumentViewModel`。
3. 新增結束處理：

```csharp
private void OnExitClick(object? sender, RoutedEventArgs e) => Close();
```

- [ ] **Step 3: build 確認可編譯（UI 無單元測試）**

Run: `dotnet build src/MoldplanDbSwitcher/`
Expected: build 成功（容許既有 AVLN3001 警告：ApplyDevDialog/ReportSourceDialog/SettingsDialog，與本任務無關）。

- [ ] **Step 4: commit**

```bash
git add src/MoldplanDbSwitcher/Views/MainWindow.axaml \
        src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs
git commit -m "feat: MainWindow 改為選單列 + MDI 文件區 shell"
```

---

## Task 9：ConnectionSwitchDocumentView（抽出連線切換 UI）

**Files:**
- Create: `src/MoldplanDbSwitcher/Views/Documents/ConnectionSwitchDocumentView.axaml`
- Create: `src/MoldplanDbSwitcher/Views/Documents/ConnectionSwitchDocumentView.axaml.cs`

說明：把舊 `MainWindow.axaml` 第 42–152 行 TabItem「連線切換」內的內容（去掉內層 `<Menu>`，因選單已上移 shell）搬成獨立 `UserControl`，`x:DataType` 設為 `ConnectionSwitchDocumentViewModel`。原 TabItem 內的 code-behind 事件（`OnExportFeatureReportClick` 等）已於 Task 8 移到 MainWindow.axaml.cs 並指向 `ConnectionSwitch`；本 View 的按鈕改綁命令或由 shell 處理。

- [ ] **Step 1: 建立 UserControl XAML**

Create `ConnectionSwitchDocumentView.axaml`，將舊 TabItem 內容（第 43–151 行的 `<DockPanel>`，**移除** 第 45–59 行的 `<Menu>` 區塊）貼入，外層改 `UserControl`：

```xml
<UserControl xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:vm="using:MoldplanDbSwitcher.ViewModels.Documents"
             x:Class="MoldplanDbSwitcher.Views.Documents.ConnectionSwitchDocumentView"
             x:DataType="vm:ConnectionSwitchDocumentViewModel">
  <DockPanel Margin="8">
    <!-- 頂部：連線來源篩選（原 62–72 行） -->
    <!-- 底部：狀態列與操作按鈕（原 75–113 行） -->
    <!-- 中間：連線清單 + SERVER.txt 選擇（原 116–149 行） -->
  </DockPanel>
</UserControl>
```

> 把原始第 62–149 行 XAML 原樣貼入對應註解位置；綁定路徑不變（`ShowSpecurai`、`Connections`、`SelectedConnection`、`PreviewBefore`、`ApplyChangesCommand`、`ApplyDevCommand`、`HasDevDirectory`、`StatusMessage`、`ServerTxtFiles`、`RefreshAllCommand`、`SyncAnsibleCommand`、`CanSyncAnsible`、`ProgressText`、`IsExporting` 等——這些現都在 `ConnectionSwitchDocumentViewModel`）。
> 第 122 行 `x:DataType="vm:ServerTxtFileItem"`：`ServerTxtFileItem` 命名空間若隨 Task 5 搬移而改變，更新 `xmlns` 或型別前綴。

- [ ] **Step 2: 建立 code-behind**

Create `ConnectionSwitchDocumentView.axaml.cs`：

```csharp
using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.Views;   // 若需開對話框，沿用 Task 8 在 MainWindow 的處理；此處保留按鈕事件對應

namespace MoldplanDbSwitcher.Views.Documents;

public partial class ConnectionSwitchDocumentView : UserControl
{
    public ConnectionSwitchDocumentView()
    {
        InitializeComponent();
    }

    // 「新增/刪除自訂連線」按鈕：原本在 MainWindow.axaml.cs。
    // 因對話框需要 owner Window，於此用 TopLevel.GetTopLevel(this) 取得，或改由 shell 處理。
    private async void OnAddConnectionClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not ConnectionSwitchDocumentViewModel vm) return;
        var owner = TopLevel.GetTopLevel(this) as Window;
        if (owner is null) return;
        var dialog = new ConnectionDialog();
        var result = await dialog.ShowDialog<ConnectionDialogViewModel?>(owner);
        if (result is not null)
            vm.AddCustomConnection(result.Name, result.Server, result.Database, result.Environment);
    }

    private async void OnDeleteConnectionClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not ConnectionSwitchDocumentViewModel vm) return;
        if (vm.SelectedConnection is not { Source: "Custom" } profile) return;
        await vm.DeleteCustomConnection(profile);
    }
}
```

> 決策：連線切換 View 內的「新增/刪除自訂連線」按鈕事件移到本 code-behind（用 `TopLevel.GetTopLevel(this)` 取 owner），讓本 View 自包含。對應地，從 Task 8 的 MainWindow.axaml.cs 移除 `OnAddConnectionClick`/`OnDeleteConnectionClick`（避免重複）。
> 其餘需要 owner Window 的回呼（ApplyDev、Confirm、匯出 Excel、匯入/匯出連線）較複雜，維持由 Task 8 的 MainWindow 設定到 `vm.ConnectionSwitch`；這些由 shell 選單觸發，不在本 View 內。
> 確認本 View XAML 內「新增/刪除自訂連線」按鈕（原 100–103 行）使用 `Click="OnAddConnectionClick"`/`Click="OnDeleteConnectionClick"`，指向本 code-behind。

- [ ] **Step 3: build + 跑全測試**

Run: `dotnet build src/MoldplanDbSwitcher/` 然後 `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: build 成功、測試全綠。

- [ ] **Step 4: 手動驗證（/run 或 /verify）**

啟動 App，確認：① 開機顯示「連線切換」主頁且不可關閉；② 報表選單可開啟「Reporting 查詢」「Reporting 部署」分頁、重複開不重複、可關閉；③ 頂部連線下拉切換後，已開的 Reporting 分頁有重指向（查詢標的庫變更）；④ 匯出功能差異表/使用次數統計、新增/刪除自訂連線、設定、匯入/匯出連線、Ansible 同步皆正常。

- [ ] **Step 5: commit**

```bash
git add src/MoldplanDbSwitcher/Views/Documents/ConnectionSwitchDocumentView.axaml \
        src/MoldplanDbSwitcher/Views/Documents/ConnectionSwitchDocumentView.axaml.cs \
        src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs
git commit -m "feat: 抽出 ConnectionSwitchDocumentView 連線切換 UI"
```

---

## 完成準則（P1）

- [ ] App 以 Specurai 式選單列 + MDI 文件區啟動。
- [ ] 連線切換為 `CanClose=false` 主頁；Reporting 查詢/部署可由報表選單開關、singleton 不重複。
- [ ] 頂部連線下拉變更會經 `IActiveConnectionService` 傳播到所有已開文件。
- [ ] 既有測試全數通過；新增 DocumentViewModel / ActiveConnectionService / ConnectionSwitch / MainWindow shell 測試通過。
- [ ] 所有 UI 文字維持繁體中文（Law 1）。

> 下一步：P1 介面（`DocumentViewModel`、`IActiveConnectionService`、`ActiveConnection`）落地後，撰寫 P2（部署重構：內嵌腳本、雙占位符、匯出 SQL）實作計畫。
