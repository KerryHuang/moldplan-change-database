USE [<<Database>>];   -- ⚠️ 部署時把 <<Database>> 換成目標資料庫（獨立庫部署＝MoldPlan-Reporting；舊同庫部署＝客戶主庫名）
GO

-- =============================================================
-- Reporting Agent Jobs 監控查詢
-- =============================================================

-- 1. 兩個 Job 最近 24 小時執行紀錄
SELECT j.name AS JobName, h.step_name AS StepName,
    CASE h.run_status
        WHEN 0 THEN '失敗' WHEN 1 THEN '成功'
        WHEN 2 THEN '重試' WHEN 3 THEN '取消'
    END AS 結果,
    h.run_date AS 執行日期,
    h.run_time AS 執行時間,
    h.run_duration AS 持續秒數,
    LEFT(h.message, 200) AS 訊息
FROM msdb.dbo.sysjobs j
    JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
WHERE j.name LIKE 'Reporting_%MoldPlan'
  AND h.run_date >= CONVERT(INT, CONVERT(VARCHAR, DATEADD(DAY, -1, GETDATE()), 112))
ORDER BY h.run_date DESC, h.run_time DESC;

-- 2. 各寬表的刷新紀錄（從 SP 內部寫入的 RefreshLog）
-- 注意：執行此查詢需先切到目標 DB
-- USE [WayDoSoft01-Test];
SELECT TOP 50
    TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage
FROM [Reporting].[RefreshLog]
ORDER BY StartedAt DESC;

-- 3. 手動觸發 Job（緊急刷新）
-- EXEC msdb.dbo.sp_start_job @job_name = N'Reporting_DailyRefresh_MoldPlan';
-- EXEC msdb.dbo.sp_start_job @job_name = N'Reporting_HourlyRefresh_MoldPlan';

-- 4. 啟用 / 停用 Job
-- EXEC msdb.dbo.sp_update_job @job_name = N'Reporting_DailyRefresh_MoldPlan', @enabled = 0;  -- 停用
-- EXEC msdb.dbo.sp_update_job @job_name = N'Reporting_DailyRefresh_MoldPlan', @enabled = 1;  -- 啟用

-- 5. 刪除 Job
-- EXEC msdb.dbo.sp_delete_job @job_name = N'Reporting_DailyRefresh_MoldPlan';
-- EXEC msdb.dbo.sp_delete_job @job_name = N'Reporting_HourlyRefresh_MoldPlan';
