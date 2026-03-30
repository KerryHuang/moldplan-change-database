# 系統功能使用工時統計表 — 設計文件

日期：2026-03-30

## 功能目的

批次查詢所有客戶連線的 SYS030 登入離線記錄，統計各程式的累積使用分鐘數與登入次數，匯出為單一 Excel 檔案，協助了解 MIS 功能實際使用狀況。

## 資料來源

| 資料表 | 用途 |
|--------|------|
| SYS030 | 登入/離線記錄（主要計算來源） |
| SYS013 | 功能項目清單（取中文名稱 ITEM_DESC） |

## 核心 SQL

```sql
SELECT
    RTRIM(A.PROG_NO)     AS 程式編號,
    RTRIM(D.ITEM_DESC)   AS 程式名稱,
    ROUND(SUM(
        DATEDIFF(SECOND,
            CAST(RTRIM(A.TIME1)    AS TIME),
            CAST(RTRIM(A.TIME_OUT) AS TIME)
        ) / 60.0
    ), 2)                AS 使用時間_分,
    COUNT(*)             AS 次數
FROM SYS030 A
INNER JOIN SYS013 D
    ON RTRIM(A.PROG_NO) = RTRIM(D.ITEM_ID)
   AND D.DEL_MARK = 'N'
WHERE A.DEL_MARK  = 'N'
  AND A.ON_LINE   = 'X'
  AND A.TIME_OUT  > A.TIME1
  AND A.TIME_OUT  <> ' '
  AND A.LOG_DATE1 >= @StartDate
  AND A.LOG_DATE1 <  DATEADD(DAY, 1, @EndDate)
GROUP BY
    RTRIM(A.PROG_NO),
    RTRIM(D.ITEM_DESC)
HAVING ROUND(SUM(DATEDIFF(SECOND,
    CAST(RTRIM(A.TIME1) AS TIME),
    CAST(RTRIM(A.TIME_OUT) AS TIME)
) / 60.0), 2) > 0
ORDER BY 使用時間_分 DESC
```

日期範圍：`EndDate = 今天，StartDate = 今天 - 6 個月`（由 `UsageReportService` 內部計算）。

## 架構

新增檔案一覽，與現有 Feature 系列平行：

```
Models/
  UsageEntry.cs              ← 單筆統計結果
  UsageReportData.cs         ← 批次結果（含 FailedConnections、SkippedConnections）

Services/
  IUsageQueryService.cs      ← Task<List<UsageEntry>> QueryUsageAsync(ConnectionProfile, DateTime, DateTime)
  UsageQueryService.cs       ← 執行 SQL，依賴 ISqlConnectionFactory
  IUsageReportService.cs     ← Task<UsageReportData> QueryAllAsync(IProgress<string>?); Task ExportToExcelAsync(string, UsageReportData)
  UsageReportService.cs      ← 批次查詢 + Excel 匯出，依賴 IConnectionSourceService + IUsageQueryService
```

## Models

### UsageEntry

| 屬性 | 型別 | 說明 |
|------|------|------|
| ProgNo | string | 程式編號 |
| ProgName | string | 程式名稱（ITEM_DESC） |
| UsageMinutes | decimal | 使用時間（分），2 位小數 |
| Count | int | 次數 |

### UsageReportData

| 屬性 | 型別 | 說明 |
|------|------|------|
| Rows | List\<(string CustomerName, UsageEntry Entry)\> | 所有客戶資料列 |
| FailedConnections | List\<string\> | 連線失敗的客戶 |
| SkippedConnections | List\<string\> | 無資料的客戶 |

## Excel 輸出

- 工作表名稱：「使用工時統計」
- 欄位順序：客戶、程式編號、程式名稱、使用時間（分）、次數
- 標題列：藍底白字（沿用現有 `HeaderBg`/`HeaderFg`）
- 資料排序：依客戶分組，同客戶內按使用時間降冪
- AutoFilter、自動欄寬

## UI 入口

主選單「檔案」新增「匯出使用工時統計(_U)」，觸發流程與「匯出功能差異表」相同：
1. IsExporting = true，顯示進度文字
2. 批次查詢（IProgress\<string\> 回報每個客戶）
3. SaveFileDialog 選擇存檔路徑（.xlsx）
4. 匯出 Excel
5. StatusMessage 顯示結果（含失敗/跳過數量）

## 測試計畫

- `UsageQueryServiceTests`：mock `ISqlConnectionFactory`，驗證 SQL 參數與結果映射
- `UsageReportServiceTests`：mock `IConnectionSourceService` + `IUsageQueryService`，驗證批次邏輯（失敗、跳過、進度回報）
- **實際 SQL 驗證**：實作完成後對現有連線設定檔中的所有客戶實際執行，確認 SQL 無誤

## 注意事項

- TIME1 / TIME_OUT 為 CHAR(10)，需 RTRIM 後 CAST AS TIME
- 跨午夜記錄會產生負值，以 `HAVING 使用時間_分 > 0` 過濾
- 若 SYS013 缺少部分 PROG_NO，INNER JOIN 會自動排除，符合規格
