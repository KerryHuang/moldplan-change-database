# Reporting 重構 P4：查詢投影欄位 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 讓 Reporting 查詢能自訂投影欄位——以 `SELECT [c1],[c2] …` 取代固定的 `SELECT *`，使用者可勾選要顯示的欄位（不勾＝全部）。其餘 Top N / 篩選 / 排序行為完全保留。

**Architecture:** `ReportingQueryService` 的主要查詢多載新增可選 `columns` 投影參數（驗證識別符後組 `SELECT` 欄位清單，空＝`*`）。`ReportingQueryViewModel` 新增可勾選的 `ProjectionColumns`（`ColumnSelectionItem` 包裝），查詢時把勾選欄位帶入。`ReportingQueryPage` 加欄位勾選面板（全選/全不選）。

**Tech Stack:** .NET 9、Avalonia 11.3、CommunityToolkit.Mvvm、Microsoft.Data.SqlClient、xUnit + NSubstitute。

> 對應 spec：`docs/superpowers/specs/2026-06-16-reporting-refactor-design.md`（區塊 D）。前置：P1–P3 已完成。
> **環境提醒：** pre-commit hook 會 build + 測試；App 執行中會鎖 `MoldplanDbSwitcher.exe`（`MSB3027/MSB3021`）→ commit 前先關 App。

---

## 現況（已讀）

- `ReportingQueryService` 3 個 `QueryTopNAsync` 多載，皆組 `SELECT TOP ({top}) * FROM [Reporting].[{objectName}]`。已有 `EnsureValidIdentifier`（僅允許英數+底線）。VM 用的是第 3 個多載 `(objectName, top, filters, sorts, ct=default)`。
- `ReportingQueryViewModel.SelectedColumns`（`ReportingColumn`）其實是「該物件全部欄位」，供篩選/排序下拉用；`AvailableColumnNames` 為其名稱。查詢 `QueryAsync` 呼叫 `_query.QueryTopNAsync(SelectedObject.Name, TopN, Filters, Sorts)`。
- 需求「可自訂塞選欄位」＝投影欄位（SELECT 哪些欄），與篩選/排序的欄位下拉是不同概念。新增獨立的「可勾選投影欄位」集合，不動 `SelectedColumns`。

---

## File Structure

新增：
- `src/MoldplanDbSwitcher/ViewModels/ColumnSelectionItem.cs`
- 對應測試

修改：
- `src/MoldplanDbSwitcher/Services/IReportingQueryService.cs`（第 3 多載加 `columns` 參數）
- `src/MoldplanDbSwitcher/Services/ReportingQueryService.cs`（投影組裝）
- `src/MoldplanDbSwitcher/ViewModels/ReportingQueryViewModel.cs`（`ProjectionColumns` + 查詢帶入）
- `src/MoldplanDbSwitcher/Views/ReportingQueryPage.axaml`（欄位勾選面板）

---

## Task 1：ReportingQueryService 投影欄位

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/IReportingQueryService.cs`
- Modify: `src/MoldplanDbSwitcher/Services/ReportingQueryService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ReportingQueryServiceTests.cs`（既有檔，新增測試）

說明：在 VM 用的第 3 多載 `QueryTopNAsync(objectName, top, filters, sorts, ct)` 新增「投影欄位」。為避免破壞既有呼叫端的位置參數順序（`ct` 為 optional），把新參數設為 optional 並置於 `ct` 之前；既有不帶 `ct` 的呼叫仍可編譯。若有呼叫端以位置傳 `ct`，改為具名 `ct:`（建置會指出）。

- [ ] **Step 0: 讀現況**

讀 `ReportingQueryService.cs`（投影目前為 `SELECT TOP ({top}) *`）與 `IReportingQueryService.cs`，與既有 `ReportingQueryServiceTests.cs` 了解測試如何建立 service（LocalDB fixture 或對 SQL 字串斷言）。確認既有測試對 `QueryTopNAsync(...filters, sorts)` 的呼叫方式（是否帶 `ct`）。

- [ ] **Step 1: 失敗測試**

於 `ReportingQueryServiceTests.cs` 新增（若測試以 LocalDB 跑真實查詢，沿用既有 fixture；投影正確性可由 `QueryResult.ExecutedSql` 斷言，因 service 會把組好的 SQL 放進 `ExecutedSql`）：
```csharp
[Fact]
public async Task QueryTopN_WithColumns_ProjectsSelectedColumns()
{
    // 沿用既有測試建立 service 與一個已知 Reporting 物件的方式；
    // 若既有測試用 LocalDB + 已部署測試表，沿用之並選兩個已知欄位。
    var svc = CreateService();   // 沿用既有 helper
    var result = await svc.QueryTopNAsync(
        KnownObjectName, 100,
        System.Array.Empty<QueryFilterRow>(),
        System.Array.Empty<QuerySortRow>(),
        columns: new[] { KnownColA, KnownColB });
    Assert.Contains($"[{KnownColA}]", result.ExecutedSql);
    Assert.Contains($"[{KnownColB}]", result.ExecutedSql);
    Assert.DoesNotContain("TOP (100) *", result.ExecutedSql);
}

[Fact]
public async Task QueryTopN_EmptyColumns_SelectsStar()
{
    var svc = CreateService();
    var result = await svc.QueryTopNAsync(
        KnownObjectName, 100,
        System.Array.Empty<QueryFilterRow>(),
        System.Array.Empty<QuerySortRow>(),
        columns: System.Array.Empty<string>());
    Assert.Contains("*", result.ExecutedSql);
}

[Fact]
public async Task QueryTopN_InvalidColumnName_Throws()
{
    var svc = CreateService();
    await Assert.ThrowsAsync<System.ArgumentException>(() =>
        svc.QueryTopNAsync(KnownObjectName, 100,
            System.Array.Empty<QueryFilterRow>(),
            System.Array.Empty<QuerySortRow>(),
            columns: new[] { "x; DROP TABLE y" }));
}
```
> 依既有測試風格調整：`CreateService()`/`KnownObjectName`/`KnownColA`/`KnownColB` 用該測試類別現有的 LocalDB 物件與欄位（讀檔得知）。若既有測試是純 SQL 字串斷言（不連 DB），則直接斷言 `ExecutedSql`。重點：投影把 `*` 換成 `[colA],[colB]`、空清單回 `*`、非法欄位名拋 `ArgumentException`。

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingQueryServiceTests"`
Expected: 新測試 FAIL（`columns` 參數不存在）。

- [ ] **Step 3: 介面加參數**

於 `IReportingQueryService.cs` 第 3 多載改為：
```csharp
Task<QueryResult> QueryTopNAsync(string objectName, int top,
    IEnumerable<QueryFilterRow> filters, IEnumerable<QuerySortRow> sorts,
    IEnumerable<string>? columns = null, CancellationToken ct = default);
```
（其餘兩個多載不動。）

- [ ] **Step 4: 實作投影**

於 `ReportingQueryService.cs`：
1. 新增私有工具：
```csharp
private static string BuildSelectList(IEnumerable<string>? columns)
{
    if (columns == null) return "*";
    var cols = columns.Where(c => !string.IsNullOrWhiteSpace(c)).ToList();
    if (cols.Count == 0) return "*";
    foreach (var c in cols) EnsureValidIdentifier(c);
    return string.Join(", ", cols.Select(c => $"[{c}]"));
}
```
2. 第 3 多載簽章對齊介面（加 `IEnumerable<string>? columns = null` 於 `ct` 前），並把組 SQL 改為：
```csharp
var selectList = BuildSelectList(columns);
var sql = $"SELECT TOP ({top}) {selectList} FROM [Reporting].[{objectName}]";
```
（`where`/`orderBy` 組裝邏輯不變。）

- [ ] **Step 5: 跑測試確認通過（含既有回歸）**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingQueryServiceTests"`
Expected: 全綠（新 3 筆 + 既有）。若有既有呼叫端因新參數而位置不符，改具名 `ct:` 修正。

- [ ] **Step 6: commit**

```bash
git add src/MoldplanDbSwitcher/Services/IReportingQueryService.cs src/MoldplanDbSwitcher/Services/ReportingQueryService.cs tests/MoldplanDbSwitcher.Tests/Services/ReportingQueryServiceTests.cs
git commit -m "feat: 查詢支援自訂投影欄位（SELECT 指定欄位，空＝*）"
```

---

## Task 2：ColumnSelectionItem 與 ViewModel 投影集合

**Files:**
- Create: `src/MoldplanDbSwitcher/ViewModels/ColumnSelectionItem.cs`
- Modify: `src/MoldplanDbSwitcher/ViewModels/ReportingQueryViewModel.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingQueryViewModelTests.cs`（既有檔）

- [ ] **Step 1: 失敗測試**

於 `ReportingQueryViewModelTests.cs` 新增（沿用該檔建立 VM 的既有方式；`_objects` mock 的 `GetColumnsAsync` 回兩欄；`_query` mock 攔截投影參數）：
```csharp
[Fact]
public async Task Query_PassesCheckedProjectionColumns()
{
    // 安排：objects.GetColumnsAsync 回 c1,c2,c3；query 回任意 QueryResult。
    // 用該測試類別既有的 mock helper 建 VM 並設定。
    var vm = CreateViewModel(/* 注入可攔截的 query/objects mock */);
    // 選定物件 → 觸發 LoadObjectDetail（填 ProjectionColumns，全勾）
    // 取消勾選 c2，僅留 c1,c3
    // 執行 QueryCommand
    // 斷言 query.QueryTopNAsync 收到 columns == [c1,c3]
}
```
> 具體 mock 設定依該測試檔現有風格撰寫：用 `Func<string,IReportingObjectService>`/`Func<string,IReportingQueryService>` 回傳 NSubstitute mock；`objects.GetColumnsAsync(Arg.Any<string>())` 回 `new[]{ new ReportingColumn("c1","int",false,null), new ReportingColumn("c2","int",false,null), new ReportingColumn("c3","int",false,null) }`；用 `query.QueryTopNAsync(...)` 的 `Arg.Do<IEnumerable<string>?>` 或 `Received()` 斷言收到的欄位集合。觸發物件選取用設定 `vm.SelectedObject = <一個 ReportingObject>`（會跑 `OnSelectedObjectChanged` → `LoadObjectDetailAsync` 與 `QueryAsync`）。
> 若直接設 `SelectedObject` 會自動查詢造成時序複雜，改為直接呼叫 `vm` 公開的載入/查詢路徑；可在實作時為測試暴露 `await vm.LoadObjectDetailForTestAsync(obj)` 之類最小縫，或讓測試等待。保持斷言「勾選欄位正確傳入」為核心。

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingQueryViewModelTests.Query_PassesCheckedProjectionColumns"`
Expected: FAIL（`ProjectionColumns` 不存在 / 查詢未帶 columns）。

- [ ] **Step 3: 建立 ColumnSelectionItem**

`src/MoldplanDbSwitcher/ViewModels/ColumnSelectionItem.cs`：
```csharp
using CommunityToolkit.Mvvm.ComponentModel;

namespace MoldplanDbSwitcher.ViewModels;

/// <summary>查詢投影欄位的可勾選項目。</summary>
public partial class ColumnSelectionItem : ObservableObject
{
    public string Name { get; }
    public string DataType { get; }
    [ObservableProperty] private bool _isSelected = true;

    public ColumnSelectionItem(string name, string dataType)
    {
        Name = name;
        DataType = dataType;
    }
}
```

- [ ] **Step 4: ViewModel 加投影集合與查詢帶入**

於 `ReportingQueryViewModel.cs`：
1. 加集合與全選/全不選命令：
```csharp
public ObservableCollection<ColumnSelectionItem> ProjectionColumns { get; } = new();

[RelayCommand]
private void SelectAllColumns() { foreach (var c in ProjectionColumns) c.IsSelected = true; }

[RelayCommand]
private void ClearAllColumns() { foreach (var c in ProjectionColumns) c.IsSelected = false; }
```
2. `LoadObjectDetailAsync` 內，填 `SelectedColumns`/`AvailableColumnNames` 後，一併填 `ProjectionColumns`（預設全勾）：
```csharp
ProjectionColumns.Clear();
foreach (var c in SelectedColumns) ProjectionColumns.Add(new ColumnSelectionItem(c.Name, c.DataType));
```
   並在 `UseConnectionAsync`（重置區）與 `LoadObjectDetailAsync` 開頭一併 `ProjectionColumns.Clear();`。
3. `QueryAsync` 帶入勾選欄位：
```csharp
var projected = ProjectionColumns.Where(c => c.IsSelected).Select(c => c.Name).ToList();
var result = await _query.QueryTopNAsync(SelectedObject.Name, TopN, Filters, Sorts, projected);
```
   （`projected` 為空＝全不勾 → service 端回 `*`，等同顯示全部。）

- [ ] **Step 5: 跑測試確認通過（含既有回歸）**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ReportingQueryViewModelTests"`
Expected: 全綠。

- [ ] **Step 6: commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/ColumnSelectionItem.cs src/MoldplanDbSwitcher/ViewModels/ReportingQueryViewModel.cs tests/MoldplanDbSwitcher.Tests/ViewModels/ReportingQueryViewModelTests.cs
git commit -m "feat: 查詢 ViewModel 加入可勾選投影欄位並帶入查詢"
```

---

## Task 3：ReportingQueryPage 欄位勾選面板

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/ReportingQueryPage.axaml`

- [ ] **Step 1: 讀現況**

讀 `ReportingQueryPage.axaml`，了解既有版面（Top N 輸入、`+ 條件`、`查詢` 按鈕、篩選/排序區、預覽/欄位/RefreshLog 分頁），決定欄位勾選面板放哪（建議放在查詢按鈕列下方，或「欄位」分頁上方）。`x:DataType` 應為 `vm:ReportingQueryViewModel`。

- [ ] **Step 2: 加入欄位勾選面板**

在查詢條件區附近加入（用 `ItemsControl` + `WrapPanel` 呈現勾選框）：
```xml
<StackPanel Margin="0,8,0,0" Spacing="4">
  <StackPanel Orientation="Horizontal" Spacing="8">
    <TextBlock Text="顯示欄位：" FontWeight="Bold" VerticalAlignment="Center" />
    <Button Content="全選" Command="{Binding SelectAllColumnsCommand}" />
    <Button Content="全不選" Command="{Binding ClearAllColumnsCommand}" />
    <TextBlock Text="（全不選＝顯示全部）" Foreground="Gray" VerticalAlignment="Center" />
  </StackPanel>
  <ItemsControl ItemsSource="{Binding ProjectionColumns}">
    <ItemsControl.ItemsPanel>
      <ItemsPanelTemplate><WrapPanel /></ItemsPanelTemplate>
    </ItemsControl.ItemsPanel>
    <ItemsControl.ItemTemplate>
      <DataTemplate x:DataType="vm:ColumnSelectionItem">
        <CheckBox Content="{Binding Name}" IsChecked="{Binding IsSelected}" Margin="0,0,12,0" />
      </DataTemplate>
    </ItemsControl.ItemTemplate>
  </ItemsControl>
</StackPanel>
```
> 確認 `xmlns:vm` 指向 `MoldplanDbSwitcher.ViewModels`（`ColumnSelectionItem` 與 `ReportingQueryViewModel` 同命名空間）。勾選改變不自動重查；使用者按既有「查詢」按鈕套用（與篩選/排序一致）。

- [ ] **Step 3: build + 全測試**

Run: `dotnet build src/MoldplanDbSwitcher/`（0 error；3 個既有 AVLN3001 OK）然後 `dotnet test tests/MoldplanDbSwitcher.Tests/`（全綠）。

- [ ] **Step 4: 手動驗證（/run 或 /verify，可選）**

開 App → Reporting 查詢 → 選一個已部署物件 → 取消勾選部分欄位 → 按「查詢」→ 確認預覽只顯示勾選欄位、狀態列 SQL 顯示 `SELECT TOP (100) [..],[..]`；全不選 → 顯示全部欄位。測畢關 App。

- [ ] **Step 5: commit**

```bash
git add src/MoldplanDbSwitcher/Views/ReportingQueryPage.axaml
git commit -m "feat: 查詢頁加入欄位勾選面板（自訂投影）"
```

---

## 完成準則（P4）

- [ ] 查詢可指定投影欄位，SQL 變為 `SELECT TOP (n) [c1],[c2] …`；不勾＝`*`（全部）。
- [ ] 非法欄位名被 `EnsureValidIdentifier` 擋下。
- [ ] Top N / 篩選（AND/OR）/ 多重排序行為完全保留（既有測試綠）。
- [ ] 查詢頁有欄位勾選面板 + 全選/全不選。
- [ ] 全測試綠；UI 文字繁體中文（Law 1）。

> P4 完成即四階段（P1 shell、P2 部署、P3 監控、P4 查詢）全部結束，可進行分支收尾（合併或 PR）。
