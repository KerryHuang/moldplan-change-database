# Reporting 整體重構設計

> 日期：2026-06-16
> 狀態：設計已確認，待寫實作計畫
> 範圍：MoldplanDbSwitcher 的 Reporting 功能整體重構 + App shell 改為 Specurai 式選單列 + MDI 文件區

## 1. 背景與動機

現況：

- App 為單一 `TabControl` 架構，三個頂層分頁：連線切換、Reporting 查詢、Reporting 部署。
- Reporting 功能已有相當實作：
  - `ReportingQueryViewModel` / `ReportingQueryPage`：Top N、欄位篩選列（AND/OR）、多重排序、預覽／欄位／RefreshLog 分頁。
  - `ReportingDeployViewModel` / `ReportingDeployPage`：編號腳本部署，**單一** `<<CHANGE_ME>>` 占位符，部署 01→04 + Daily/Hourly Job + Drop。
  - 腳本來自**外部資料夾** `IAppSettingsService.GetMoldPlanScriptsPath()`。

問題：底層 SQL 腳本集（`D:\Repos\MoldPlan-Workspace\docs\scripts\Reporting`）已演進，現有部署層與之脫節：

- 改為**雙占位符**模型：`<<Database>>`（目標報表庫）+ `<<MAINDB>>`（來源主庫，透過 View 三段式跨庫命名）。
- 擴增為 9 檔（01–07、98、99），其中新增 99 為 Job/RefreshLog 監控查詢。
- 跨庫前提：報表庫須與客戶主庫**同一個 SQL Server instance**。

目標（使用者需求）：

1. 對齊完整新 SQL 腳本集。
2. **一鍵部署**，比照 DatabaseDescriptionApp（Specurai）健康監控的方式與維度；可自定義**目標資料庫名稱**與**來源資料庫名稱**。
3. **Job 監控**（全部 Agent Job，如截圖）+ `99_Reporting_Monitor.sql` 的 RefreshLog 監控。
4. 每個 Table/View 的查詢，**保留目前 Reporting 查詢方式**：Top 100、可自定篩選欄位與條件、可自定排序。
5. 導覽改為**功能列（選單列）方式**，比照 Specurai。

## 2. 已確認決策

| 主題 | 決策 |
|---|---|
| 腳本來源 | **內嵌 EmbeddedResource 為預設，可選外部資料夾覆寫** |
| Job 監控範圍 | **全部 Agent Job**（如截圖，查 msdb 全部 sysjobs） |
| 監控頁形式 | **儀表板式 + 狀態彙總 + 自動刷新** |
| 導覽結構 | **全面改 Specurai shell**（選單列 + MDI 文件區），連線切換也成為文件/主頁 |

設計者先行判斷（已獲確認，可後續推翻）：

- 查詢/物件服務（`ReportingQueryService` / `ReportingObjectService`）原樣重用。
- 監控第一版唯讀為主，僅提供「手動觸發 Reporting Daily/Hourly Job」兩個動作；不做啟用/停用/刪除 Job。
- 自動刷新預設間隔 30 秒。

## 3. Specurai shell pattern（參照來源）

DatabaseDescriptionApp 的 shell（要鏡像的模式）：

- 頂部 Avalonia `Menu`（非 NativeMenu）：檔案 / 檢視 / 工具 / 說明。
- 中央 MDI 區為 `TabControl`，`ItemsSource` 綁 `ObservableCollection<DocumentViewModel> Documents`，`SelectedItem` 綁 `SelectedDocument`；每頁 tab 顯示 icon + 標題 + 關閉鈕。
- 內容用 `DataTemplate`（`DataType="{x:Type vm:XxxDocumentViewModel}"`）依型別路由到對應 View。
- 每個功能 = 一個 `DocumentViewModel` 子類，含 `DocumentType`、`DocumentKey`（singleton 用）、`Title`、`Icon`、`CanClose`。
- 開啟流程：選單命令 → `OpenXxxCommand` → 檢查 `Documents.OfType<T>()` 是否已開 → 否則由 DI 建立 → `Documents.Add` + 設為 `SelectedDocument`。
- 無第三方 docking 套件，純 Avalonia `Menu` / `TabControl` / `DockPanel` / `GridSplitter`。

## 4. 架構設計

### 區塊 A — Shell 遷移（基礎，階段 P1）

**新增 `DocumentViewModel` 抽象基底**（`ViewModels/Documents/DocumentViewModel.cs`）：

```csharp
public abstract partial class DocumentViewModel : ObservableObject
{
    public abstract string DocumentType { get; }
    public virtual string DocumentKey => DocumentType;   // singleton 鍵；同鍵只開一份
    [ObservableProperty] private string _title = "";
    public virtual string Icon => "";
    public virtual bool CanClose => true;
    public event Action<DocumentViewModel>? CloseRequested;
    [RelayCommand] private void Close() => CloseRequested?.Invoke(this);
    // 連線變更時各文件覆寫此法重指向
    public virtual Task UseConnectionAsync(ActiveConnection conn) => Task.CompletedTask;
}
```

**`MainWindowViewModel` 調整：**

- 新增 `ObservableCollection<DocumentViewModel> Documents`、`[ObservableProperty] DocumentViewModel? SelectedDocument`。
- 輔助 `OpenOrActivate<T>(Func<T> factory) where T : DocumentViewModel`：依 `DocumentKey` 找既有，有則 activate，無則由 DI 建立、訂閱 `CloseRequested`、加入並選取。
- 各 `Open*Command`：`OpenConnectionSwitch`、`OpenReportingQuery`、`OpenReportingDeploy`、`OpenReportingMonitor`，以及既有匯出命令。
- `OnDocumentCloseRequested`：自 `Documents` 移除（`CanClose=false` 者忽略）。
- 開機自動開啟 `ConnectionSwitchDocumentViewModel` 作為主頁。

**`MainWindow.axaml` 重構：**

- 頂部 `Menu`：**檔案**（匯入/匯出連線設定、設定、結束）、**檢視**（關閉目前/全部分頁）、**報表**（查詢、部署、監控、匯出功能差異表、匯出使用次數統計）、**說明**（關於）。
- 保留現有「目前連線」ComboBox 列（DockPanel.Dock=Top）。
- 中央 MDI `TabControl` 綁 `Documents` / `SelectedDocument`；`ItemTemplate` 顯示標題 + 關閉鈕；`ContentTemplate` 用 per-VM `DataTemplate` 路由。
- 底部狀態列（`StatusMessage` + 進度）。

**連線切換文件化：**

- `ConnectionSwitchDocumentViewModel`（`DocumentType="ConnectionSwitch"`、`CanClose=false`）封裝現有 `MainWindowViewModel` 中連線切換相關狀態與命令（連線清單、來源篩選、SERVER.txt 選擇、套用變更/開發、新增/刪除自訂連線、Ansible 同步、預覽對比）。
- `ConnectionSwitchDocumentView` + code-behind：自現有 `MainWindow.axaml` 第 42–152 行的 TabItem 內容抽出。

**連線變更傳播（區塊 E）：**

- 新增 `IActiveConnectionService`：持有目前 `ActiveConnection`（連線字串 + 來源主庫名 + ConnectionProfile），暴露 `Current` 與 `Changed` 事件。
- 頂部 ComboBox / 連線切換文件更新它；`MainWindowViewModel` 訂閱 `Changed`，對所有已開 `Documents` 呼叫 `UseConnectionAsync`。
- 取代目前 ViewModel 間以建構式連線字串硬接的方式。

### 區塊 B — 部署重構（階段 P2）

**腳本內嵌：**

- 將 9 個腳本複製進 `src/MoldplanDbSwitcher/Scripts/Reporting/`：`01_Reporting_Create_Database.sql` … `07_…`、`98_…`、`99_…`。
- `.csproj` 加 `<EmbeddedResource Include="Scripts\Reporting\*.sql" />`。
- 維護備註：這些是外部 SSDT/workspace 的派生檔，改 SQL 時兩邊需同步（README 已載明 BOM / 重複 extended property 雷）。

**`IReportingScriptProvider` 重寫：**

```csharp
public interface IReportingScriptProvider
{
    ReportingScript GetScript(int fileNumber);
    IReadOnlyList<ReportingScript> ListAvailable();
    // 渲染雙占位符；Job 檔（06/07）維持 USE msdb、替換 @DatabaseName
    string Render(int fileNumber, ReportingDeployParameters p);
}

public record ReportingDeployParameters(
    string TargetDatabase,   // <<Database>>，預設 "MoldPlan-Reporting"
    string SourceDatabase,   // <<MAINDB>>，預設＝目前連線 DB
    string JobOwner = "sa");
```

- 載入策略：預設讀內嵌資源（`Assembly.GetManifestResourceStream`）；若 `IAppSettingsService` 設有外部覆寫路徑且檔案存在，改讀外部。
- 渲染：全文替換 `<<Database>>` → `TargetDatabase`、`<<MAINDB>>` → `SourceDatabase`；Job 檔的 `@DatabaseName` 一併替換為 `TargetDatabase`。

**`ReportingDeployService` 對齊新序列：**

| 步驟 | 檔 | context | 內容 |
|---|---|---|---|
| 1 | 01 | master | 建報表庫 + 開 RCSI |
| 2 | 02 | 目標庫 | 建 Reporting schema |
| 3 | 03 | 目標庫 | 建 14 Table |
| 4 | 04 | 目標庫 | 建 13 View（雙占位符跨庫） |
| 5 | 05 | 目標庫 | 建 13 Refresh SP |
| 6 | 06 | msdb | Daily 06:00 Job |
| 7 | 07 | msdb | Hourly WorkRecord Job |
| Drop | 98 | 目標庫 | ⚠ 移除 Reporting 全部物件 |

- 安裝狀態掃描 `ScanInstallStatus`：DB 是否存在、schema 是否存在、Table/View/SP 計數（期望 14/13/13）。
- `GenerateExportSqlAsync(ReportingDeployParameters)`：合併 01→07（或含 98）為一份已替換占位符的 .sql，供 SSMS 手動執行（比照健康監控匯出），透過 `SaveFileCallback` 存檔。
- 沿用既有 `ISqlBatchExecutor`（依 `GO` 分批、逐批執行、首錯即停、`IProgress<DeployStep>` 回報）。

**部署文件 UI（`ReportingDeployDocumentView`）：**

- 兩個輸入框：**目標報表庫名**（預設 `MoldPlan-Reporting`）、**來源主庫名**（預設＝目前連線 DB）。
- 掃描/狀態面板（DB/schema/計數 + 重新掃描）。
- 按鈕：部署全部（01→07）、部署 Daily Job、部署 Hourly Job、匯出 SQL、⚠ 移除全部（98，需打字確認庫名）。
- 步驟 log DataGrid（檔名/說明/狀態/錯誤）+ 進度。
- 明示**跨庫前提**提示：報表庫須與主庫同一 instance。

### 區塊 C — 監控儀表板（階段 P3）

**`IJobMonitorService`：**

```csharp
public interface IJobMonitorService
{
    Task<IReadOnlyList<AgentJobStatus>> ListJobsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<RefreshLogEntry>> GetRefreshLogAsync(string targetDatabase, int top = 50, CancellationToken ct = default);
    Task TriggerJobAsync(string jobName, CancellationToken ct = default);   // 僅供 Reporting 兩個 Job
}

public record AgentJobStatus(
    string JobName, bool Enabled, DateTime? LastRunTime,
    string LastRunOutcome, DateTime? NextRunTime, int? LastDurationSeconds);
```

- `ListJobsAsync`：查 msdb `sysjobs` / `sysjobactivity` / `sysjobhistory`，取全部 Agent Job，對齊截圖欄位（Job 名稱、狀態、上次執行時間、上次結果、下次排程時間、上次耗時）。
- `GetRefreshLogAsync`：查目標庫 `Reporting.RefreshLog`（各寬表最新 狀態/耗時/筆數/錯誤），對齊 99 腳本第 2 段。
- `TriggerJobAsync`：`msdb.dbo.sp_start_job`，僅允許 `Reporting_DailyRefresh_MoldPlan` / `Reporting_HourlyRefresh_MoldPlan`。

**`MonitoringDocumentViewModel`：**

- 頂部**狀態彙總卡**：成功 / 失敗 / 停用 / 刷新過期（RefreshLog 最新非成功或逾時）計數。
- Job 清單 DataGrid（全部 Agent Job）+ RefreshLog DataGrid（各寬表）。
- **自動刷新**：`DispatcherTimer`，預設 30 秒（可調）；文件非作用中或關閉時暫停。
- 手動刷新 + 「手動觸發 Reporting Daily/Hourly Job」兩顆按鈕。

### 區塊 D — 查詢文件（重用既有 + 微調，階段 P4）

- 將 `ReportingQueryViewModel` 包成 `DocumentViewModel`（`DocumentType="ReportingQuery"`），完整保留 Top N（預設 100）、欄位篩選列（AND/OR）、多重排序、預覽／欄位／RefreshLog 分頁。
- `ReportingQueryService` / `ReportingObjectService` 不動。
- 唯一補強：目前查詢為 `SELECT *`；需求「可自定塞選欄位」→ 將 `SelectedColumns` 投影進 SQL（`SELECT [c1],[c2] …`，未選時 fallback `*`）。小改 + 補測試。

## 5. 測試策略（Law 2 TDD）

先寫失敗測試，確認失敗，再寫最小實作，確認通過。框架 xUnit + NSubstitute，沿用 LocalDB fixture。

- **ScriptProvider**：雙占位符渲染（`<<Database>>` / `<<MAINDB>>` / Job `@DatabaseName`）、內嵌 vs 外部覆寫載入。
- **DeployService**：新 01→07 序列、98 drop、`ScanInstallStatus` 計數、`GenerateExportSqlAsync` 占位符全替換。
- **QueryService**：欄位投影（選欄/未選欄 fallback）、既有 Top N / 篩選 / 排序回歸。
- **JobMonitorService**：以介面隔離；SQL 映射用薄接縫測，VM 測試用 mock（LocalDB 無 SQL Agent，msdb Job 難整合測試 — 此限制明列）。
- **ViewModel**：文件 open/activate/singleton（`DocumentKey`）、`IActiveConnectionService` 變更傳播、監控狀態彙總、部署輸入驗證。

## 6. 階段交付

| 階段 | 區塊 | 產出 | 可獨立 commit |
|---|---|---|---|
| P1 | A、E | shell 遷移 + 連線切換文件化 + 連線傳播 | ✓ |
| P2 | B | 內嵌腳本 + 雙占位符 + 匯出 SQL + 新序列 | ✓ |
| P3 | C | 監控儀表板 | ✓ |
| P4 | D | 查詢欄位投影微調 | ✓ |

## 7. 風險與注意

- **Shell 遷移動到現有連線切換主畫面**：抽出 TabItem 內容為獨立 View 時須保留所有既有命令與 code-behind 互動（對話框開啟、SelectionChanged 等）。
- **內嵌腳本同步**：SQL 改動需手動同步進 repo；BOM 與重複 extended property 雷已載於來源 README。
- **跨 instance 限制**：報表庫與主庫須同 instance，UI 須明示。
- **msdb Job 操作風險**：監控第一版僅唯讀 + 手動觸發 Reporting 兩個 Job，不開放對任意 Job 啟用/停用/刪除。
- **Law 1 繁體中文**：所有 UI 文字、commit、文件用繁體中文；識別符維持英文。
