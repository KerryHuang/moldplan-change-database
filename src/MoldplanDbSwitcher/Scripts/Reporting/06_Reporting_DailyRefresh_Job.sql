USE msdb;
GO

-- =============================================================
-- SQL Server Agent Job：Reporting 寬表每日刷新（獨立資料庫版）
-- Job Name : Reporting_DailyRefresh_MoldPlan
-- Schedule : 每日 06:00 執行
-- 內容     : 10 張 base 寬表 + 3 張彙總寬表
-- =============================================================
-- 與舊版差異：@DatabaseName 固定為 MoldPlan-Reporting（不再每客戶改）。
--   SP 名稱仍是 [Reporting].[Refresh...]，因 Reporting schema 就在新庫內；
--   SP 內 View 對 dbo / Web schema 的參照由 View 三段式 [<<MAINDB>>] 跨庫解析。
-- 切換注意：建立本 Job 前，先停用/刪除主庫舊的同名 Job（指向客戶主庫者）。
-- =============================================================

DECLARE @JobName          NVARCHAR(128) = N'Reporting_DailyRefresh_MoldPlan';
DECLARE @DatabaseName     NVARCHAR(128) = N'<<Database>>';   -- ⚠️ 換成報表庫名（統一為 MoldPlan-Reporting）
DECLARE @JobOwner         NVARCHAR(128) = N'sa';
DECLARE @CategoryName     NVARCHAR(128) = N'[Uncategorized (Local)]';
DECLARE @ScheduleName     NVARCHAR(128) = N'Daily_06AM';

DECLARE @JobId UNIQUEIDENTIFIER;

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @JobName)
    EXEC dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;

EXEC dbo.sp_add_job
    @job_name        = @JobName,
    @enabled         = 1,
    @description     = N'每日 06:00 刷新 MoldPlan-Reporting 寬表：10 張 base + 3 張彙總',
    @category_name   = @CategoryName,
    @owner_login_name= @JobOwner,
    @job_id          = @JobId OUTPUT;

-- Step 1：Phase 1 — Base 寬表（10 張，互無依賴）
EXEC dbo.sp_add_jobstep
    @job_id          = @JobId,
    @step_name       = N'Phase1_BaseWideTables',
    @step_id         = 1,
    @subsystem       = N'TSQL',
    @database_name   = @DatabaseName,
    @command         = N'
SET NOCOUNT ON;
SET XACT_ABORT ON;

EXEC [Reporting].[RefreshSalesOrderRowData];
EXEC [Reporting].[RefreshSalesOrderDetailRowData];
EXEC [Reporting].[RefreshWorkOrderPartRowData];
EXEC [Reporting].[RefreshWorkOrderProcessRowData];
EXEC [Reporting].[RefreshWorkRecordRowData];
EXEC [Reporting].[RefreshMoldRowData];
EXEC [Reporting].[RefreshMoldPartRowData];
EXEC [Reporting].[RefreshPurchaseReceiveRowData];
EXEC [Reporting].[RefreshOutsourceReceiveRowData];
EXEC [Reporting].[RefreshHeatTreatmentReceiveRowData];
',
    @on_success_action = 3,   -- 3 = 進入下一個 step
    @on_fail_action    = 2,   -- 2 = 失敗時退出
    @retry_attempts    = 0,
    @retry_interval    = 0;

-- Step 2：Phase 2 — 彙總寬表（3 張，依賴 Phase 1）
EXEC dbo.sp_add_jobstep
    @job_id          = @JobId,
    @step_name       = N'Phase2_SummaryWideTables',
    @step_id         = 2,
    @subsystem       = N'TSQL',
    @database_name   = @DatabaseName,
    @command         = N'
SET NOCOUNT ON;
SET XACT_ABORT ON;

EXEC [Reporting].[RefreshMoldCostSummary];
EXEC [Reporting].[RefreshMoldPartCostSummary];
EXEC [Reporting].[RefreshMoldPartProcessCostSummary];
',
    @on_success_action = 1,   -- 1 = 成功結束
    @on_fail_action    = 2,
    @retry_attempts    = 0,
    @retry_interval    = 0;

-- Schedule：每日 06:00
EXEC dbo.sp_add_schedule
    @schedule_name      = @ScheduleName,
    @enabled            = 1,
    @freq_type          = 4,        -- 4 = Daily
    @freq_interval      = 1,        -- 每 1 天
    @freq_subday_type   = 1,        -- 1 = 一次
    @active_start_time  = 060000;   -- HHMMSS = 06:00:00

EXEC dbo.sp_attach_schedule
    @job_id          = @JobId,
    @schedule_name   = @ScheduleName;

EXEC dbo.sp_add_jobserver
    @job_id          = @JobId,
    @server_name     = N'(local)';

PRINT N'Job [' + @JobName + N'] 建立完成，每日 06:00 執行（DB = MoldPlan-Reporting）。';
GO
