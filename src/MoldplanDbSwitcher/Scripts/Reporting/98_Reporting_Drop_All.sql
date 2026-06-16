USE [<<Database>>];   -- ⚠️ 部署時把 <<Database>> 換成目標資料庫（獨立庫部署＝MoldPlan-Reporting；舊同庫部署＝客戶主庫名）
GO

-- ============================================================
-- 98 Reporting Drop All（危險！會清除整個 Reporting schema）
-- ============================================================
-- 用途：
--   - 環境重建：完整移除 Reporting 後重跑 01 ~ 06
--   - 客戶 DB 出貨清理
--   - QA / Staging 還原
--
-- 順序：
--   SP（依賴 Views/Tables）→ View（依賴 Tables）→ Table → Schema
--   彙總層先丟（依賴 base）→ base 後丟
--
-- 警告：
--   - 此腳本不會備份資料
--   - RefreshLog 歷史紀錄一併刪除
--   - 執行後須跑 01 ~ 06 才能恢復
-- ============================================================

USE [<your_database>];   -- ← 執行前替換為實際資料庫名稱
GO

PRINT N'=== 開始清除 Reporting schema ===';
GO

-- ============================================================
-- 1. Drop Stored Procedures
-- ============================================================
PRINT N'--- 1/4 Drop Stored Procedures ---';

-- 彙總層（先丟）
DROP PROCEDURE IF EXISTS [Reporting].[RefreshMoldPartProcessCostSummary];
DROP PROCEDURE IF EXISTS [Reporting].[RefreshMoldPartCostSummary];
DROP PROCEDURE IF EXISTS [Reporting].[RefreshMoldCostSummary];

-- 採購 / 外包 / 熱處理 base
DROP PROCEDURE IF EXISTS [Reporting].[RefreshHeatTreatmentReceiveRowData];
DROP PROCEDURE IF EXISTS [Reporting].[RefreshOutsourceReceiveRowData];
DROP PROCEDURE IF EXISTS [Reporting].[RefreshPurchaseReceiveRowData];

-- 模具 / 零件 / 工序 / 報工 / 業務 base
DROP PROCEDURE IF EXISTS [Reporting].[RefreshMoldPartRowData];
DROP PROCEDURE IF EXISTS [Reporting].[RefreshMoldRowData];
DROP PROCEDURE IF EXISTS [Reporting].[RefreshWorkRecordRowData];
DROP PROCEDURE IF EXISTS [Reporting].[RefreshWorkOrderProcessRowData];
DROP PROCEDURE IF EXISTS [Reporting].[RefreshWorkOrderPartRowData];
DROP PROCEDURE IF EXISTS [Reporting].[RefreshSalesOrderDetailRowData];
DROP PROCEDURE IF EXISTS [Reporting].[RefreshSalesOrderRowData];
GO

-- ============================================================
-- 2. Drop Views
-- ============================================================
PRINT N'--- 2/4 Drop Views ---';

-- 彙總層（先丟）
DROP VIEW IF EXISTS [Reporting].[MoldPartProcessCostSummaryView];
DROP VIEW IF EXISTS [Reporting].[MoldPartCostSummaryView];
DROP VIEW IF EXISTS [Reporting].[MoldCostSummaryView];

-- 採購 / 外包 / 熱處理 base
DROP VIEW IF EXISTS [Reporting].[HeatTreatmentReceiveRowDataView];
DROP VIEW IF EXISTS [Reporting].[OutsourceReceiveRowDataView];
DROP VIEW IF EXISTS [Reporting].[PurchaseReceiveRowDataView];

-- 模具 / 零件 / 工序 / 報工 / 業務 base
DROP VIEW IF EXISTS [Reporting].[MoldPartRowDataView];
DROP VIEW IF EXISTS [Reporting].[MoldRowDataView];
DROP VIEW IF EXISTS [Reporting].[WorkRecordRowDataView];
DROP VIEW IF EXISTS [Reporting].[WorkOrderProcessRowDataView];
DROP VIEW IF EXISTS [Reporting].[WorkOrderPartRowDataView];
DROP VIEW IF EXISTS [Reporting].[SalesOrderDetailRowDataView];
DROP VIEW IF EXISTS [Reporting].[SalesOrderRowDataView];
GO

-- ============================================================
-- 3. Drop Tables
-- ============================================================
PRINT N'--- 3/4 Drop Tables ---';

-- 彙總層（先丟）
DROP TABLE IF EXISTS [Reporting].[MoldPartProcessCostSummary];
DROP TABLE IF EXISTS [Reporting].[MoldPartCostSummary];
DROP TABLE IF EXISTS [Reporting].[MoldCostSummary];

-- 採購 / 外包 / 熱處理 base
DROP TABLE IF EXISTS [Reporting].[HeatTreatmentReceiveRowData];
DROP TABLE IF EXISTS [Reporting].[OutsourceReceiveRowData];
DROP TABLE IF EXISTS [Reporting].[PurchaseReceiveRowData];

-- 模具 / 零件 / 工序 / 報工 / 業務 base
DROP TABLE IF EXISTS [Reporting].[MoldPartRowData];
DROP TABLE IF EXISTS [Reporting].[MoldRowData];
DROP TABLE IF EXISTS [Reporting].[WorkRecordRowData];
DROP TABLE IF EXISTS [Reporting].[WorkOrderProcessRowData];
DROP TABLE IF EXISTS [Reporting].[WorkOrderPartRowData];
DROP TABLE IF EXISTS [Reporting].[SalesOrderDetailRowData];
DROP TABLE IF EXISTS [Reporting].[SalesOrderRowData];

-- 共用日誌表（最後丟）
DROP TABLE IF EXISTS [Reporting].[RefreshLog];
GO

-- ============================================================
-- 4. Drop Schema
-- ============================================================
PRINT N'--- 4/4 Drop Schema ---';

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Reporting')
BEGIN
    DROP SCHEMA [Reporting];
    PRINT N'已刪除 [Reporting] schema';
END
ELSE
BEGIN
    PRINT N'[Reporting] schema 不存在，略過';
END
GO

PRINT N'=== 完成 Reporting 清除 ===';
GO
