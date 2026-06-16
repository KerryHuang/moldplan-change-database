USE [<<Database>>];   -- ⚠️ 部署時把 <<Database>> 換成目標資料庫（獨立庫部署＝MoldPlan-Reporting；舊同庫部署＝客戶主庫名）
GO

-- ============================================================
-- 00 Reporting Schema (one-shot)
-- 建立 Reporting schema（若不存在）
-- 執行順序：00 → 10 → 20 → 30 → (建 Agent Job 01/02)
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Reporting')
BEGIN
    EXEC('CREATE SCHEMA [Reporting] AUTHORIZATION [dbo]');
    PRINT '已建立 [Reporting] schema';
END
ELSE
BEGIN
    PRINT '[Reporting] schema 已存在，略過';
END
GO
