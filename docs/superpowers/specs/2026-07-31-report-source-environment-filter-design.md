# 報表來源／環境雙維度篩選 Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 匯出客戶功能報表與使用次數統計前，讓使用者分別勾選「連線來源」與「環境」兩個獨立維度，匯出範圍為兩者交集。

**Architecture:** 沿用現有的 `ReportSourceDialog`，把原本混合來源與環境的四個 checkbox 拆成兩組。環境判斷從字串比對 `Name.EndsWith("- 正式")` 改為讀取 `ConnectionProfile.Environment` 欄位。

**Tech Stack:** .NET 9、Avalonia 11.3、CommunityToolkit.Mvvm、xUnit + NSubstitute

---

## 修改檔案

- `src/MoldplanDbSwitcher/Models/ReportSourceOptions.cs` — record 改為來源 3 + 環境 4 共 7 個 bool
- `src/MoldplanDbSwitcher/ViewModels/ReportSourceDialogViewModel.cs` — 對應的 Has* 與 ObservableProperty 改版
- `src/MoldplanDbSwitcher/Views/ReportSourceDialog.axaml` — 拆成兩組 checkbox，視窗加高
- `src/MoldplanDbSwitcher/ViewModels/Documents/ConnectionSwitchDocumentViewModel.cs` — `GetAvailableSources()` 與 `FilterConnectionsForReport()` 改版
- `tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionSwitchDocumentViewModelTests.cs` — 篩選測試改版

## 新增檔案

- `tests/MoldplanDbSwitcher.Tests/ViewModels/ReportSourceDialogViewModelTests.cs` — 對話框 ViewModel 目前無測試，本次補上

無新增產品程式碼檔案。

---

## ReportSourceOptions

```csharp
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

七個 bool 而非集合型別：Avalonia 的 CheckBox 需綁定 bool 屬性，包成 `HashSet` 反而要在 ViewModel 多一層展開與收合。維持與現有 record + bool 的風格一致。

## 篩選邏輯

```csharp
public IReadOnlyList<ConnectionProfile> FilterConnectionsForReport(ReportSourceOptions o)
    => Connections.Where(c => MatchesSource(c, o) && MatchesEnvironment(c, o)).ToList();

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

兩個維度是 AND 關係：來源與環境都命中才納入報表。

未知的 `Source` 字串回傳 `false`（不納入），與現行行為一致——目前 `FilterConnectionsForReport` 也只認得三種來源。

## 可用性偵測

```csharp
public ReportSourceOptions GetAvailableSources() => new(
    Specurai: Connections.Any(c => c.Source == "Specurai"),
    Custom: Connections.Any(c => c.Source == "Custom"),
    MoldPlanCenter: Connections.Any(c => c.Source == "MoldPlan Center"),
    Development: Connections.Any(c => c.Environment == DatabaseEnvironment.Development),
    Testing: Connections.Any(c => c.Environment == DatabaseEnvironment.Testing),
    Staging: Connections.Any(c => c.Environment == DatabaseEnvironment.Staging),
    Production: Connections.Any(c => c.Environment == DatabaseEnvironment.Production));
```

回傳值同時擔任兩個角色（沿用現行做法）：控制 checkbox 的 `IsEnabled`，以及決定預設勾選狀態。**四個環境固定顯示**，沒有對應連線的項目 disable 並取消勾選，位置不隨資料變動。

## 對話框

```
請選擇要包含的連線來源：
  [✓] Specurai   [✓] 自訂   [✓] MoldPlan Center

環境：
  [ ] 開發   [✓] 測試   [ ] 預備   [✓] 正式

                              [確認] [取消]
```

兩組各自垂直排列，中間以標題文字分隔。視窗高度從 270 調整為足以容納兩組的高度。

## 行為變更

**Specurai 與自訂連線從此受環境篩選影響。** 現行行為是勾了「Specurai」就納入全部 Specurai 連線，不分環境。改版後若使用者取消勾選某個環境，該環境的 Specurai／自訂連線也會被排除。

以目前的實際資料為例，Specurai 來源共 13 筆，環境分佈為：開發 2 筆、測試 1 筆、預備 10 筆。因此「預備」若未勾選，會排除掉 10 筆 Specurai 連線。

由於預設勾選所有「實際存在」的環境，開啟對話框直接按確認的結果與現行行為相同——差異只在使用者主動取消勾選時才顯現。

## 測試

`ConnectionSwitchDocumentViewModelTests`：

- `FilterConnectionsForReport_來源與環境皆命中_納入`
- `FilterConnectionsForReport_來源命中但環境未勾_排除`
- `FilterConnectionsForReport_環境命中但來源未勾_排除`
- `FilterConnectionsForReport_依Environment欄位而非名稱判斷_正確分類`（名稱不含「正式」但 `Environment` 為 Production 的連線應被「正式」勾選命中）
- `GetAvailableSources_無開發環境連線_Development為false`

`ReportSourceDialogViewModel`：

- `建構_可用環境為false_對應屬性不勾選且不可點`
- `ToOptions_回傳目前勾選狀態`
