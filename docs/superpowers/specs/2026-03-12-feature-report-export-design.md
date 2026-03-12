# 客戶功能差異表匯出功能設計

## 概述

在 MoldplanDbSwitcher 主畫面加一個「匯出功能差異表」按鈕，點擊後自動連線所有客戶資料庫查詢 SYS013，整理後產出 8 個 Sheet 的 Excel 檔案。

## 資料流

1. 讀取 TableSpec + 自訂 `connections.json`（含帳密）
2. 逐一用 `SqlConnection` 連線，執行 SQL 查詢 SYS013
3. 匯整所有客戶資料
4. 用 ClosedXML 產出 Excel
5. 跳出儲存對話框讓使用者選位置

## SQL 查詢

```sql
SELECT SYS_TYPE, ITEM_ID, ITEM_DESC, APP_FILE, OPEN_YN
FROM SYS013
WHERE APP_FILE != 'XXX' AND ITEM_DESC != '-'
ORDER BY SYS_TYPE, ITEM_ID
```

## Model 變更

`ConnectionProfile` 加入 `Username`、`Password` 屬性（PascalCase JSON key），對應 TableSpec connections.json 中的明文欄位。自訂 connections.json 同樣支援。所有連線皆使用 SQL Server Authentication（AuthType = 1）。

### 新增 Model

- `CustomerFeatureData` — 單一客戶的功能資料（代碼、名稱、資料庫、功能清單）
- `FeatureEntry` — 單一功能項目（SYS_TYPE, ITEM_ID, ITEM_DESC, APP_FILE, OPEN_YN）
- `FeatureReportData` — 所有客戶資料的容器，含成功/失敗清單

## 新增 Service

### ISqlConnectionFactory / SqlConnectionFactory

- `SqlConnection Create(ConnectionProfile profile)` — 根據 ConnectionProfile 建立 SqlConnection
- 建構式無特殊參數，測試時用 NSubstitute mock

### IFeatureQueryService / FeatureQueryService

- `Task<List<FeatureEntry>> QueryFeaturesAsync(ConnectionProfile profile)` — 對單一連線查詢 SYS013
- 建構式注入 `ISqlConnectionFactory`

### IFeatureReportService / FeatureReportService

- `Task<FeatureReportData> QueryAllCustomerFeaturesAsync(IProgress<string>?)` — 逐一連線查詢，回傳各客戶的 SYS013 資料
- `Task ExportToExcelAsync(string path, FeatureReportData data)` — 產出 8 個 Sheet 的 Excel
- 建構式注入 `IConnectionSourceService`、`IFeatureQueryService`

## 8 個 Sheet 規格

### 1. 客戶總覽

| 欄位 | 說明 |
|------|------|
| 代碼 | 連線名稱去掉 -Staging/-Test 後綴 |
| 客戶名稱 | 同代碼 |
| 資料庫 | ConnectionProfile.Database |
| 功能總數 | 該客戶 SYS013 查詢結果的總筆數 |
| 已開啟(Y) | OPEN_YN = 'Y' 的數量 |
| 未開啟(N) | OPEN_YN = 'N' 的數量 |
| 開啟率 | 已開啟 / 功能總數 |

### 2. 已開啟功能（交叉表）

- 列：以 SYS_TYPE + ITEM_ID 為 key，顯示模組、ITEM_ID、功能名稱
- 欄：各客戶代碼
- 格子：Y（已開啟）、空白（未開啟或無此功能）
- 篩選條件：僅顯示至少一個客戶 OPEN_YN = 'Y' 的功能
- 排序：SYS_TYPE, ITEM_ID

### 3. 全客戶共有

- 列出所有客戶都為 OPEN_YN = 'Y' 的功能
- 欄位：模組、ITEM_ID、功能名稱

### 4. 各客戶已開啟

- 按客戶分段，每段標題為「代碼（客戶名稱）」
- 列出該客戶 OPEN_YN = 'Y' 的功能
- 欄位：模組、ITEM_ID、功能名稱

### 5. 差異功能（交叉表）

- 與完整明細結構相同，但僅顯示客戶間不一致的功能
- 不一致定義：同一 ITEM_ID 在不同客戶間有不同值（Y/N/-混合）
- 顏色標記說明行在最上方

### 6. 完整明細（交叉表）

- 列：所有功能（聯集所有客戶的 SYS_TYPE + ITEM_ID）
- 欄：各客戶代碼
- 格子：Y（已開啟）、N（未開啟）、-（該客戶無此功能）
- 排序：SYS_TYPE, ITEM_ID
- 顏色標記說明行在最上方

### 7. 獨有功能

- 只有單一客戶擁有的功能（該 ITEM_ID 只出現在一個客戶的 SYS013 中）
- 欄位：客戶、模組、ITEM_ID、功能名稱

### 8. 樞紐分析用資料

- 扁平格式，每一行代表一個客戶的一個功能
- 欄位：客戶代碼、客戶名稱、模組、ITEM_ID、功能名稱、OPEN_YN
- 說明行在最上方

## NuGet 套件

- `ClosedXML` — 產出 Excel
- `Microsoft.Data.SqlClient` — 連線 SQL Server

## ViewModel 設計

在 `MainWindowViewModel` 新增：

- `[RelayCommand] ExportFeatureReportAsync()` — 匯出命令
- `[ObservableProperty] bool isExporting` — 控制按鈕停用和進度顯示
- `[ObservableProperty] string progressText` — 進度文字（「正在查詢第 2/9 個客戶...」）

儲存對話框透過 code-behind 事件處理開啟（遵循 avalonia-mvvm 慣例），ViewModel 透過回呼取得儲存路徑。

## UI 變更

- MainWindow 加一個「匯出功能差異表」按鈕，綁定 `ExportFeatureReportCommand`
- `IsExporting` 為 true 時按鈕停用、顯示進度文字
- 儲存對話框由 code-behind 開啟

## DI 註冊

在 `Program.cs` 新增：
- `services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>()`
- `services.AddSingleton<IFeatureQueryService, FeatureQueryService>()`
- `services.AddSingleton<IFeatureReportService, FeatureReportService>()`

## 客戶代碼/名稱邏輯

連線名稱去掉 `-Staging`、`-Test` 後綴作為代碼和名稱。例如：
- `Gma-Staging` → `Gma`
- `WayDoSoft01-Test` → `WayDoSoft01`
- `WDMIS` → `WDMIS`

## 錯誤處理

- 某個客戶連線失敗時跳過該客戶，繼續查詢其他客戶
- 最終報告哪些客戶查詢成功/失敗
- 所有客戶都失敗時顯示錯誤訊息，不產出 Excel

## 測試計畫

### 客戶代碼解析
- `ParseCustomerCode_RemovesStagingSuffix`
- `ParseCustomerCode_RemovesTestSuffix`
- `ParseCustomerCode_NoSuffix_ReturnsAsIs`

### FeatureQueryService
- Mock `ISqlConnectionFactory`，驗證 SQL 執行與結果對應
- 連線失敗時拋出例外

### FeatureReportService
- Mock `IFeatureQueryService`，注入假資料驗證 8 個 Sheet 的邏輯
- `QueryAllCustomerFeaturesAsync_PartialFailure_ReturnsSuccessAndFailures`
- `QueryAllCustomerFeaturesAsync_AllFailure_ReturnsEmpty`
- `ExportToExcelAsync` 用臨時目錄寫出 Excel，再用 ClosedXML 讀回驗證 Sheet 數量與內容

### Sheet 邏輯（純函式測試）
- 全客戶共有：所有客戶都 Y 的才列出
- 差異功能：至少有一個客戶不同
- 獨有功能：ITEM_ID 只出現在一個客戶
- 交叉表中 `-` 標記：客戶無此 ITEM_ID 時

## 跨平台備註

此功能依賴 `Microsoft.Data.SqlClient`，macOS/Linux 上需安裝 OpenSSL。功能本身不限定平台。
