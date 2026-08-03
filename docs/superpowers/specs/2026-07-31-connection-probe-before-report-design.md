# 報表匯出前的連線預檢 Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 匯出報表前先平行探測所有連線，連不通的直接跳過，不再為每個不通的連線各付一次連線 timeout。

**Architecture:** 新增 `IConnectionProbeService`，在 ViewModel 的兩個匯出流程中、連線篩選之後查詢之前插入預檢。探測本身只做 `OpenAsync`，不下任何查詢。

**Tech Stack:** .NET 9、Avalonia 11.3、Microsoft.Data.SqlClient、CommunityToolkit.Mvvm、xUnit + NSubstitute

---

## 問題

`UsageReportService.QueryAllAsync` 與 `FeatureReportService.QueryAllCustomerFeaturesAsync` 都是序列迴圈，每個連線失敗時由 `catch` 收進 `FailedConnections`。連不通的連線**已經**會被跳過，但每一個都要等滿 `SqlConnectionFactory` 的 `ConnectTimeout = 10` 秒。

14 個連不上的客戶＝140 秒乾等，且時間隨客戶數線性增長。

## 新增檔案

- `src/MoldplanDbSwitcher/Services/IConnectionProbeService.cs` — 介面與 `ConnectionProbeResult`
- `src/MoldplanDbSwitcher/Services/ConnectionProbeService.cs` — 平行探測實作
- `src/MoldplanDbSwitcher/Services/IConnectionTester.cs` — 單一連線可達性測試的抽象
- `src/MoldplanDbSwitcher/Services/SqlConnectionTester.cs` — 實際開 SQL 連線的實作
- `tests/MoldplanDbSwitcher.Tests/Services/ConnectionProbeServiceTests.cs`

## 修改檔案

- `src/MoldplanDbSwitcher/Services/ISqlConnectionFactory.cs` — `Create` 加可選的 connect timeout 參數
- `src/MoldplanDbSwitcher/Services/SqlConnectionFactory.cs` — 對應實作
- `src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs` — 兩個匯出流程插入預檢
- `src/MoldplanDbSwitcher/Program.cs` — DI 註冊兩個新服務
- `tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionSwitchDocumentViewModelTests.cs` — 建構式多一個依賴，補預檢相關測試

---

## 介面

```csharp
namespace MoldplanDbSwitcher.Services;

/// <summary>單一連線的可達性測試。抽出成介面是為了讓 ConnectionProbeService 可被單元測試
/// （SqlConnection.OpenAsync 無法 mock）。</summary>
public interface IConnectionTester
{
    Task<bool> CanConnectAsync(ConnectionProfile profile, CancellationToken ct = default);
}

/// <summary>探測結果。Unreachable 存連線名稱，與報表既有的 FailedConnections 風格一致。</summary>
public record ConnectionProbeResult(
    List<ConnectionProfile> Reachable,
    List<string> Unreachable);

public interface IConnectionProbeService
{
    Task<ConnectionProbeResult> ProbeAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null,
        CancellationToken ct = default);
}
```

## 探測實作

`ConnectionProbeService` 對每個 profile 呼叫 `IConnectionTester.CanConnectAsync`，以 `Task.WhenAll` 平行執行，依結果分成兩堆。不設並行上限——探測只是 `OpenAsync` 後立即關閉，成本低，且連線分散在不同伺服器。

`Reachable` 的順序必須與傳入的 `profiles` 一致，後續查詢的進度顯示才不會跳動。

`SqlConnectionTester` 用 `ISqlConnectionFactory.Create(profile, connectTimeoutSeconds: 5)` 建立連線，`OpenAsync` 成功回 true，任何例外回 false。

## 連線工廠

```csharp
SqlConnection Create(ConnectionProfile profile, int? connectTimeoutSeconds = null);
```

`null` 時維持現有的 `ConnectTimeout = 10`，既有呼叫端全部不受影響。預檢傳 5。

## ViewModel 流程

`ExportUsageReport` 與 `ExportFeatureReport` 在 `FilterConnectionsForReport` 之後插入：

```csharp
ProgressText = $"正在檢查 {profiles.Count} 個連線...";
var probe = await _connectionProbe.ProbeAsync(profiles, progress);

if (probe.Reachable.Count == 0)
{
    StatusMessage = $"所有連線都無法連線：{string.Join(", ", probe.Unreachable)}";
    return;
}
```

之後傳給報表服務的是 `probe.Reachable` 而非 `profiles`。

現行程式的 `var progress = new Progress<string>(...)` 宣告在查詢那一行的正上方，需提前到預檢之前，讓預檢與查詢共用同一個回報管道。

結尾訊息在既有的兩段之外多一段：

```csharp
if (probe.Unreachable.Count > 0)
    msg += $"（{probe.Unreachable.Count} 個連線無法連線，未查詢：{string.Join(", ", probe.Unreachable)}）";
```

`UsageReportData` 與 `FeatureReportData` 的結構不動——連不通屬於查詢前的階段，與「查詢失敗」（`FailedConnections`）、「查到但無資料」（`SkippedConnections`）語意不同，混進去反而模糊。

## 進度顯示

```
正在檢查 31 個連線...
22 個可連線，跳過 9 個
正在查詢第 1/22 個客戶：Gma - 正式...
```

第二行由 `ProbeAsync` 透過 `progress` 回報。

## 測試

`ConnectionProbeServiceTests`（注入假的 `IConnectionTester`）：

- `ProbeAsync_全部可連線_Unreachable為空`
- `ProbeAsync_部分不可連線_正確分成兩堆`
- `ProbeAsync_Reachable順序與輸入一致`
- `ProbeAsync_回報可連線與跳過的數量`

`ConnectionSwitchDocumentViewModelTests`：

- `ExportUsageReport_有連線不通_只查詢可連線的`（驗證傳給 `QueryAllAsync` 的清單不含不通的連線）
- `ExportUsageReport_全部連線不通_不查詢且顯示訊息`

`SqlConnectionTester` 不寫測試：它只是 `Create` → `OpenAsync` → try/catch，沒有可測的邏輯，測它等同測 SqlClient。

## 已知限制

**這不會讓連得上的連線變快。** 預檢解決的是「為不通的連線付 timeout」，如果某個客戶連得上但查詢本身慢，序列迴圈仍會等它。要解那個得平行化主查詢，代價是同時對多台正式庫下重查詢，本設計不納入。

## 提出但未納入

現行流程是**查完所有客戶才詢問存檔路徑**（`ExportUsageReport` 的 `SaveUsageReportCallback` 在 `QueryAllAsync` 之後）。使用者可能等待數分鐘後才被問路徑，此時按取消則全部白費。此問題已向使用者提出，未獲納入本次範圍的指示，故不處理。
