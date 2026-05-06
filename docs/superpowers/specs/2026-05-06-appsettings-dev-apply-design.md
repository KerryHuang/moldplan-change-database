# 設計文件：appsettings.Development.json 套用功能

**日期：** 2026-05-06  
**狀態：** 已核准

## 需求摘要

切換資料庫連線時，除了更新 `SERVER.txt`，還需要能更新 .NET 專案的 `appsettings.Development.json`。使用者在設定視窗指定一個「開發目錄」，系統遞迴掃描該目錄下所有 `appsettings.Development.json`，並透過獨立的「套用開發」按鈕，讓使用者勾選要更新的檔案後套用。

## 資料模型

### AppSettings（修改）

在現有 `AppSettings` 模型新增一個屬性：

```csharp
public string DevDirectory { get; set; } = string.Empty;
```

儲存位置：`%AppData%/MoldplanDbSwitcher/settings.json`（現有檔案）。

`ConnectionProfile` 不需要變更。Host/Port 拆分邏輯：
- `Server` 含逗號（如 `"192.168.21.1,1430"`）→ Host=`192.168.21.1`，Port=`1430`
- `Server` 不含逗號（如 `"192.168.21.1"`）→ Host=`192.168.21.1`，Port=`"1433"`（預設）

## 新增 Service

### IAppSettingsDevService

```csharp
public interface IAppSettingsDevService
{
    IReadOnlyList<string> FindFiles(string directory);
    bool Apply(string filePath, ConnectionProfile profile);
}
```

**FindFiles：** 遞迴搜尋指定目錄下所有 `appsettings.Development.json`，回傳完整路徑清單。目錄不存在時回傳空清單。

**Apply：** 
- 使用 `System.Text.Json.Nodes.JsonNode` 做部分更新（保留未知欄位）
- 只更新 `MSSQL` 區塊的以下五個欄位：
  - `Host`
  - `Port`
  - `UserId`
  - `Password`
  - `ApplicationDatabase`
- `LocalizationDatabase`、`QuartzJobDatabase` 等其他欄位保留不動
- 若 `MSSQL` 區塊不存在則略過，回傳 `false`
- 成功寫回後回傳 `true`

**可測試性：** 建構式接受路徑參數，測試時注入臨時目錄。

## UI 變更

### 設定視窗（修改）

在現有設定視窗新增：
- 標籤：「開發目錄」
- 文字欄位：綁定 `DevDirectory`
- 瀏覽按鈕：開啟 `FolderPickerDialog`，選取後填入欄位

### 主視窗（修改）

新增「套用開發」按鈕：
- `IsVisible` 綁定 `HasDevDirectory`（`DevDirectory` 非空時為 `true`）
- 位置：與「套用連線」按鈕同區

### ApplyDevDialog（新增）

點擊「套用開發」後彈出對話框：

- `ListView` 列出所有找到的 `appsettings.Development.json` 完整路徑
- 每列有 `CheckBox`，預設全勾
- 底部操作列：
  - 「全選」／「取消全選」按鈕
  - 「確認」按鈕：套用所有勾選檔案
  - 「取消」按鈕：關閉不套用
- 若目錄下找不到任何檔案，顯示提示訊息「找不到 appsettings.Development.json」

## 資料流

```
使用者點擊「套用開發」
  → MainViewModel 呼叫 AppSettingsDevService.FindFiles(DevDirectory)
  → 開啟 ApplyDevDialog，傳入檔案清單
  → 使用者勾選後點擊確認
  → 對每個勾選的檔案呼叫 AppSettingsDevService.Apply(filePath, currentProfile)
  → 顯示結果（成功/失敗數量）
```

## 測試範圍

- `AppSettingsDevServiceTests`：
  - `FindFiles_EmptyDirectory_ReturnsEmptyList`
  - `FindFiles_WithNestedFiles_ReturnsAllPaths`
  - `Apply_UpdatesMssqlFields_LeavesOtherFieldsIntact`
  - `Apply_ServerWithPort_SplitsCorrectly`
  - `Apply_ServerWithoutPort_DefaultsTo1433`
  - `Apply_MissingMssqlSection_ReturnsFalse`

## DI 註冊

在 `Program.cs` 新增：
```csharp
services.AddSingleton<IAppSettingsDevService, AppSettingsDevService>();
```
