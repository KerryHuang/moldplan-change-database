# 報表來源篩選 Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 匯出功能差異表與使用工時統計前，讓使用者選擇要查詢的連線來源（Specurai / 自訂 / Ansible 正式 / Ansible 測試）。

**Architecture:** 點選匯出時彈出來源選擇對話框，使用者勾選後 ViewModel 過濾連線清單，再傳給報表服務查詢。服務介面改為接受外部傳入的連線清單，不再自行呼叫 `LoadAllConnections()`。

**Tech Stack:** .NET 9、Avalonia 11.3、CommunityToolkit.Mvvm、xUnit + NSubstitute

---

## 新增檔案

- `src/MoldplanDbSwitcher/Models/ReportSourceOptions.cs` — 來源選擇結果 record
- `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml` — 來源選擇對話框 View
- `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml.cs` — code-behind
- `src/MoldplanDbSwitcher/ViewModels/ReportSourceDialogViewModel.cs` — 對話框 ViewModel

## 修改檔案

- `src/MoldplanDbSwitcher/Services/IFeatureReportService.cs` — QueryAllCustomerFeaturesAsync 加 profiles 參數
- `src/MoldplanDbSwitcher/Services/FeatureReportService.cs` — 實作改為接受 profiles
- `src/MoldplanDbSwitcher/Services/IUsageReportService.cs` — QueryAllAsync 加 profiles 參數
- `src/MoldplanDbSwitcher/Services/UsageReportService.cs` — 實作改為接受 profiles
- `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` — 加 FilterConnectionsForReport()，ExportFeatureReport / ExportUsageReport 改為先開對話框
- `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs` — OnExportFeatureReportClick / OnExportUsageReportClick 傳入 ReportSourceCallback
- `tests/MoldplanDbSwitcher.Tests/Services/FeatureReportServiceTests.cs` — 測試改為傳入 profiles
- `tests/MoldplanDbSwitcher.Tests/Services/UsageReportServiceTests.cs` — 測試改為傳入 profiles

---

## ReportSourceOptions

```csharp
public record ReportSourceOptions(
    bool Specurai,
    bool Custom,
    bool AnsibleProduction,
    bool AnsibleStaging);
```

## 服務介面變更

```csharp
// IFeatureReportService
Task<FeatureReportData> QueryAllCustomerFeaturesAsync(
    IReadOnlyList<ConnectionProfile> profiles,
    IProgress<string>? progress = null);

// IUsageReportService
Task<UsageReportData> QueryAllAsync(
    IReadOnlyList<ConnectionProfile> profiles,
    IProgress<string>? progress = null);
```

兩個服務的實作移除 `_connectionSource` 依賴，直接使用傳入的 `profiles`。

## 過濾邏輯（MainWindowViewModel）

```csharp
private IReadOnlyList<ConnectionProfile> FilterConnectionsForReport(ReportSourceOptions options)
    => Connections.Where(c =>
        (options.Specurai && c.Source == "Specurai") ||
        (options.Custom && c.Source == "Custom") ||
        (options.AnsibleProduction && c.Source == "Ansible" && c.Name.EndsWith("- 正式")) ||
        (options.AnsibleStaging && c.Source == "Ansible" && c.Name.EndsWith("- 測試"))
    ).ToList();
```

Ansible 正式 / 測試 的判斷依據：`Source == "Ansible"` 且 Name 結尾為 `"- 正式"` 或 `"- 測試"`，與 `AnsibleSyncService` 命名規則一致。

## ReportSourceDialog

- 四個 CheckBox：Specurai、自訂、Ansible 正式、Ansible 測試
- 預設全勾
- 「確認」回傳 `ReportSourceOptions`，「取消」回傳 `null`（中止匯出）
- 不需要新增 DI 註冊（由 code-behind 直接 new）

## ExportFeatureReport / ExportUsageReport 流程變更

1. 呼叫 `ReportSourceCallback`（由 MainWindow.axaml.cs 設定）顯示對話框
2. 使用者取消 → `StatusMessage = "已取消匯出"` 並 return
3. 呼叫 `FilterConnectionsForReport(options)` 取得過濾後清單
4. 清單為空 → `StatusMessage = "未選擇任何來源"` 並 return
5. 傳入過濾清單繼續原有查詢 / 匯出流程

`ReportSourceCallback` 型別：`Func<Task<ReportSourceOptions?>>?`，在 ViewModel 上宣告，由 View 設定。

## 測試重點

- `FilterConnectionsForReport`：各來源組合過濾正確（單元測試於 ViewModel tests）
- `FeatureReportService` / `UsageReportService`：測試改為直接傳入 profiles，不再需要 mock `IConnectionSourceService`
- `ExportFeatureReport` / `ExportUsageReport`：ReportSourceCallback 回傳 null 時不執行匯出

---

## 不在本次範圍

- 來源選擇狀態的持久化（不儲存上次選擇）
- 兩個報表共用同一個 callback（各自獨立）
