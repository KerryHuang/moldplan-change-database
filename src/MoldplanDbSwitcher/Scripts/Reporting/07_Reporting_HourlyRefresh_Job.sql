USE msdb;
GO

-- =============================================================
-- SQL Server Agent Job：WorkRecord 寬表每小時刷新（獨立資料庫版）
-- Job Name : Reporting_HourlyRefresh_MoldPlan
-- Schedule : 每整點（0、1、2 ... 23 時的 0 分）
-- 目的     : 補強 Daily Job，現場報工資料 hourly 更新
-- 注意     : 06:00 與 daily job 重疊 1 次，但 TRUNCATE+INSERT 安全可接受
-- =============================================================
-- 與舊版差異：@DatabaseName 固定為 MoldPlan-Reporting（不再每客戶改）。
-- 切換注意：建立本 Job 前，先停用/刪除主庫舊的同名 Job。
-- =============================================================

DECLARE @JobName          NVARCHAR(128) = N'Reporting_HourlyRefresh_MoldPlan';
DECLARE @DatabaseName     NVARCHAR(128) = N'<<Database>>';   -- ⚠️ 換成報表庫名（統一為 MoldPlan-Reporting）
DECLARE @JobOwner         NVARCHAR(128) = N'sa';
DECLARE @CategoryName     NVARCHAR(128) = N'[Uncategorized (Local)]';
DECLARE @ScheduleName     NVARCHAR(128) = N'Hourly_OnTheHour';

DECLARE @JobId UNIQUEIDENTIFIER;

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @JobName)
    EXEC dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;

EXEC dbo.sp_add_job
    @job_name        = @JobName,
    @enabled         = 1,
    @description     = N'每小時刷新 MoldPlan-Reporting.WorkRecordRowData（補強現場報工即時性）',
    @category_name   = @CategoryName,
    @owner_login_name= @JobOwner,
    @job_id          = @JobId OUTPUT;

EXEC dbo.sp_add_jobstep
    @job_id          = @JobId,
    @step_name       = N'RefreshWorkRecordRowData',
    @step_id         = 1,
    @subsystem       = N'TSQL',
    @database_name   = @DatabaseName,
    @command         = N'
SET NOCOUNT ON;
SET XACT_ABORT ON;

EXEC [Reporting].[RefreshWorkRecordRowData];
',
    @on_success_action = 1,
    @on_fail_action    = 2,
    @retry_attempts    = 1,    -- 失敗後重試 1 次
    @retry_interval    = 2;    -- 間隔 2 分鐘

-- Schedule：每小時整點
EXEC dbo.sp_add_schedule
    @schedule_name        = @ScheduleName,
    @enabled              = 1,
    @freq_type            = 4,        -- 4 = Daily
    @freq_interval        = 1,        -- 每 1 天
    @freq_subday_type     = 8,        -- 8 = Hours
    @freq_subday_interval = 1,        -- 每 1 小時
    @active_start_time    = 000000,
    @active_end_time      = 235959;

EXEC dbo.sp_attach_schedule
    @job_id          = @JobId,
    @schedule_name   = @ScheduleName;

EXEC dbo.sp_add_jobserver
    @job_id          = @JobId,
    @server_name     = N'(local)';

PRINT N'Job [' + @JobName + N'] 建立完成，每小時整點執行（DB = MoldPlan-Reporting）。';
GO
