-- =============================================
-- 獨立報表資料庫建立（MoldPlan-Reporting）
-- =============================================
-- 來源：PM-497 CR（Reporting 自主庫 schema 抽出至獨立資料庫）
-- 性質：一次性、每客戶各執行一次
-- 部署位置：與客戶主庫「同一個 SQL Server instance」
--
-- ⚠️ 部署時把 <<Database>> 換成報表庫名（統一為 MoldPlan-Reporting）。
-- ⚠️ 跨庫前提：報表庫的 View 以三段式名稱 [<<MAINDB>>].schema.table 跨庫
--   參照客戶主庫（見 04_Reporting_Create_Views.sql）。因此本庫必須與主庫
--   同 instance；不可單獨搬到其他主機/instance，否則跨庫參照失效。
-- =============================================

IF DB_ID(N'<<Database>>') IS NULL
BEGIN
    CREATE DATABASE [<<Database>>];
    PRINT N'已建立資料庫 <<Database>>';
END
ELSE
    PRINT N'資料庫 <<Database>> 已存在，略過建立';
GO

-- 建議：與主庫一致的相容性等級（SQL Server 2008 基準 → 100）。
-- 視客戶 instance 版本調整；新環境可維持預設不設。
-- ALTER DATABASE [<<Database>>] SET COMPATIBILITY_LEVEL = 100;
-- GO

-- 讀寫分離備援：開啟 RCSI，避免報表 / 即時查詢被寫操作鎖卡
-- （本庫以排程批次寫入為主，開啟成本低、效益高）。
ALTER DATABASE [<<Database>>] SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO
