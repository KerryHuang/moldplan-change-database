USE [<<Database>>];   -- ⚠️ 部署時把 <<Database>> 換成目標資料庫（獨立庫部署＝MoldPlan-Reporting；舊同庫部署＝客戶主庫名）
GO

-- ============================================================
-- 30 Reporting Create Stored Procedures (one-shot)
-- 依賴：Tables (含 RefreshLog) + Views
-- ============================================================
GO

-- ---------- Stored Procedures/RefreshSalesOrderRowData.sql ----------
CREATE PROCEDURE [Reporting].[RefreshSalesOrderRowData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[SalesOrderRowData];

        INSERT INTO [Reporting].[SalesOrderRowData] (
            SalesOrderId, SalesOrderNo, DocumentNo, QuotationNo,
            CustomerOrderNo, CustomerPurchaseOrderNo, Payment,
            CustomerId, CustomerSubname,
            SalesOrderTypeId, SalesOrderTypeCode, SalesOrderTypeName, BusinessPattern,
            SalesOrderCategoryId, SalesOrderCategoryCode, SalesOrderCategoryName,
            ProductTypeId, ProductTypeCode, ProductTypeName,
            CurrencyId, CurrencyName,
            ExchangeRate, OrderTotal, PayableAmount, FreeAmount, LatePenaltyAmount,
            SalesOrderStatusId, SalesOrderStatusCode, SalesOrderStatusName, CustomCode,
            UrgencyTypeId, UrgencyTypeCode, UrgencyTypeName,
            [Description], GeneralNote, ProductionNote, DiscussionNotes,
            InputDate, OrderDate, T1TrialDate, CompletionDate,
            DeliveryDate, FactoryDueDate, FactoryCompletionDate,
            PlannerEmployeeId, PlannerEmployeeName,
            SalespersonId, SalespersonName,
            FitterEmployeeId, FitterEmployeeName,
            CreatedEmployeeId, CreatedEmployeeName,
            LastModifiedEmployeeId, LastModifiedEmployeeName, ModifiedDate,
            DeleteFlag, RecordTimestamp, LastModifiedTime,
            MoldId, MoldNo, MoldName,
            IsShipped, IsDiscount, CompletedDays,
            RefreshedAt
        )
        SELECT
            LTRIM(RTRIM(v.SalesOrderId)),       LTRIM(RTRIM(v.SalesOrderNo)),       v.DocumentNo,                   LTRIM(RTRIM(v.QuotationNo)),
            LTRIM(RTRIM(v.CustomerOrderNo)),    v.CustomerPurchaseOrderNo,          LTRIM(RTRIM(v.Payment)),
            LTRIM(RTRIM(v.CustomerId)),         LTRIM(RTRIM(v.CustomerSubname)),
            v.SalesOrderTypeId,                 v.SalesOrderTypeCode,               LTRIM(RTRIM(v.SalesOrderTypeName)),     v.BusinessPattern,
            v.SalesOrderCategoryId,             v.SalesOrderCategoryCode,           LTRIM(RTRIM(v.SalesOrderCategoryName)),
            LTRIM(RTRIM(v.ProductTypeId)),      LTRIM(RTRIM(v.ProductTypeCode)),    LTRIM(RTRIM(v.ProductTypeName)),
            LTRIM(RTRIM(v.CurrencyId)),         LTRIM(RTRIM(v.CurrencyName)),
            v.ExchangeRate, v.OrderTotal, v.PayableAmount, v.FreeAmount, v.LatePenaltyAmount,
            v.SalesOrderStatusId,               v.SalesOrderStatusCode,             v.SalesOrderStatusName,                  v.CustomCode,
            v.UrgencyTypeId,                    LTRIM(RTRIM(v.UrgencyTypeCode)),    v.UrgencyTypeName,
            v.[Description], v.GeneralNote, v.ProductionNote, v.DiscussionNotes,
            v.InputDate, v.OrderDate, v.T1TrialDate, v.CompletionDate,
            v.DeliveryDate, v.FactoryDueDate, v.FactoryCompletionDate,
            LTRIM(RTRIM(v.PlannerEmployeeId)),  LTRIM(RTRIM(v.PlannerEmployeeName)),
            v.SalespersonId,                    LTRIM(RTRIM(v.SalespersonName)),
            v.FitterEmployeeId,                 LTRIM(RTRIM(v.FitterEmployeeName)),
            LTRIM(RTRIM(v.CreatedEmployeeId)),  LTRIM(RTRIM(v.CreatedEmployeeName)),
            LTRIM(RTRIM(v.LastModifiedEmployeeId)), LTRIM(RTRIM(v.LastModifiedEmployeeName)), v.ModifiedDate,
            v.DeleteFlag, v.RecordTimestamp, v.LastModifiedTime,
            LTRIM(RTRIM(v.MoldId)),             LTRIM(RTRIM(v.MoldNo)),             LTRIM(RTRIM(v.MoldName)),
            v.IsShipped, v.IsDiscount, v.CompletedDays,
            SYSUTCDATETIME()
        FROM [Reporting].[SalesOrderRowDataView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.SalesOrderRowData', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.SalesOrderRowData', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新銷售訂單寬表 (Reporting.SalesOrderRowData)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshSalesOrderRowData';
GO

-- ---------- Stored Procedures/RefreshSalesOrderDetailRowData.sql ----------
CREATE PROCEDURE [Reporting].[RefreshSalesOrderDetailRowData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[SalesOrderDetailRowData];

        INSERT INTO [Reporting].[SalesOrderDetailRowData] (
            SalesOrderDetailId, SalesOrderId, PaddedIndex,
            LineItemNo, LineItemName, VersionNumber, DrawingNumber,
            PartTypeId, PartTypeCode, PartTypeName,
            MaterialSpec, MaterialId, MaterialName,
            SourceTypeId, SourceTypeCode, SourceTypeName,
            OrderQuantity, ShippedQuantity, UnitPrice, LineTotal,
            UnitId, UnitName,
            ScheduledDeliveryDate, QuotationOrderId, Remark,
            DeleteFlag, LastModifiedTime, RecordTimestamp,
            RefreshedAt
        )
        SELECT
            LTRIM(RTRIM(v.SalesOrderDetailId)),  LTRIM(RTRIM(v.SalesOrderId)),  LTRIM(RTRIM(v.PaddedIndex)),
            LTRIM(RTRIM(v.LineItemNo)),          LTRIM(RTRIM(v.LineItemName)),  LTRIM(RTRIM(v.VersionNumber)),  LTRIM(RTRIM(v.DrawingNumber)),
            v.PartTypeId,                        v.PartTypeCode,                LTRIM(RTRIM(v.PartTypeName)),
            LTRIM(RTRIM(v.MaterialSpec)),        LTRIM(RTRIM(v.MaterialId)),    LTRIM(RTRIM(v.MaterialName)),
            v.SourceTypeId,                      v.SourceTypeCode,              LTRIM(RTRIM(v.SourceTypeName)),
            v.OrderQuantity, v.ShippedQuantity, v.UnitPrice, v.LineTotal,
            LTRIM(RTRIM(v.UnitId)),              LTRIM(RTRIM(v.UnitName)),
            v.ScheduledDeliveryDate,             LTRIM(RTRIM(v.QuotationOrderId)), LTRIM(RTRIM(v.Remark)),
            v.DeleteFlag, v.LastModifiedTime, v.RecordTimestamp,
            SYSUTCDATETIME()
        FROM [Reporting].[SalesOrderDetailRowDataView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.SalesOrderDetailRowData', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.SalesOrderDetailRowData', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新銷售訂單明細寬表 (Reporting.SalesOrderDetailRowData)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshSalesOrderDetailRowData';
GO

-- ---------- Stored Procedures/RefreshWorkOrderPartRowData.sql ----------
CREATE PROCEDURE [Reporting].[RefreshWorkOrderPartRowData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[WorkOrderPartRowData];

        INSERT INTO [Reporting].[WorkOrderPartRowData] (
            Id,
            SalesOrderId, SalesOrderNo,
            MoldId, MoldNo, MoldName, PartNo, PartName, DrawingNo, [Version], Quantity,
            MachiningSpec, MaterialSpec, DesignCompletionDate, EBomPartNo,
            MaterialId, MaterialName,
            PartTypeId, PartTypeCode, PartTypeName, PartGroupId, PartGroupName,
            SourceTypeId, SourceTypeCode, SourceTypeName, VendorId, VendorName,
            PurchasedDate, InternalSpareQuantity, CustomerSpareQuantity,
            MaterialWeight, EstimatedMaterialCost,
            IsNeedProcessing, IsOutsource, IsMaterialInspectionNeeded,
            UnitId, UnitName,
            InventoryItemId, InventoryItemName, WarehouseQuantity,
            ProductionReasonId, ProductionReasonName,
            IsProcessingStepIndex, IsConfirmed,
            PartStatusId, PartStatusName, ScrapQuantity,
            ClosureDate, EarliestStartDate, LatestEndDate, ParentPartNo,
            Remark, Priority, PlannerEmployeeId, PlannerEmployeeName,
            ProcessCheckCode, ProcessCheckName, ProcessCheckTime, ProcessChangeRecord, ProductionStartDate, CadFile,
            CostAttributionPartId, CostAttributionPartNo, CostAttributionPartName,
            DeleteFlag, RecordTimestamp, CreatedDate, LastModifiedTime,
            RefreshedAt
        )
        SELECT
            LTRIM(RTRIM(v.Id)),
            LTRIM(RTRIM(v.SalesOrderId)), LTRIM(RTRIM(v.SalesOrderNo)),
            LTRIM(RTRIM(v.MoldId)), LTRIM(RTRIM(v.MoldNo)), LTRIM(RTRIM(v.MoldName)),
            LTRIM(RTRIM(v.PartNo)), LTRIM(RTRIM(v.PartName)), LTRIM(RTRIM(v.DrawingNo)), LTRIM(RTRIM(v.[Version])), v.Quantity,
            LTRIM(RTRIM(v.MachiningSpec)), LTRIM(RTRIM(v.MaterialSpec)), v.DesignCompletionDate, LTRIM(RTRIM(v.EBomPartNo)),
            LTRIM(RTRIM(v.MaterialId)), LTRIM(RTRIM(v.MaterialName)),
            v.PartTypeId, v.PartTypeCode, LTRIM(RTRIM(v.PartTypeName)),
            LTRIM(RTRIM(v.PartGroupId)), LTRIM(RTRIM(v.PartGroupName)),
            v.SourceTypeId, v.SourceTypeCode, LTRIM(RTRIM(v.SourceTypeName)),
            LTRIM(RTRIM(v.VendorId)), LTRIM(RTRIM(v.VendorName)),
            v.PurchasedDate, v.InternalSpareQuantity, v.CustomerSpareQuantity,
            v.MaterialWeight, v.EstimatedMaterialCost,
            v.IsNeedProcessing, v.IsOutsource, v.IsMaterialInspectionNeeded,
            LTRIM(RTRIM(v.UnitId)), LTRIM(RTRIM(v.UnitName)),
            LTRIM(RTRIM(v.InventoryItemId)), LTRIM(RTRIM(v.InventoryItemName)), v.WarehouseQuantity,
            v.ProductionReasonId, LTRIM(RTRIM(v.ProductionReasonName)),
            v.IsProcessingStepIndex, v.IsConfirmed,
            LTRIM(RTRIM(v.PartStatusId)), LTRIM(RTRIM(v.PartStatusName)), v.ScrapQuantity,
            v.ClosureDate, v.EarliestStartDate, v.LatestEndDate, LTRIM(RTRIM(v.ParentPartNo)),
            LTRIM(RTRIM(v.Remark)), LTRIM(RTRIM(v.Priority)), LTRIM(RTRIM(v.PlannerEmployeeId)), LTRIM(RTRIM(v.PlannerEmployeeName)),
            LTRIM(RTRIM(v.ProcessCheckCode)), v.ProcessCheckName, v.ProcessCheckTime, v.ProcessChangeRecord, v.ProductionStartDate, LTRIM(RTRIM(v.CadFile)),
            LTRIM(RTRIM(v.CostAttributionPartId)), LTRIM(RTRIM(v.CostAttributionPartNo)), LTRIM(RTRIM(v.CostAttributionPartName)),
            v.DeleteFlag, v.RecordTimestamp, v.CreatedDate, v.LastModifiedTime,
            SYSUTCDATETIME()
        FROM [Reporting].[WorkOrderPartRowDataView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.WorkOrderPartRowData', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.WorkOrderPartRowData', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新工令零件寬表 (Reporting.WorkOrderPartRowData)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshWorkOrderPartRowData';
GO

-- ---------- Stored Procedures/RefreshWorkOrderProcessRowData.sql ----------
CREATE PROCEDURE [Reporting].[RefreshWorkOrderProcessRowData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[WorkOrderProcessRowData];

        INSERT INTO [Reporting].[WorkOrderProcessRowData] (
            ProcessId,
            SalesOrderId, SalesOrderNo, [Description],
            MoldId, MoldNo, MoldName,
            PartId, PartNo, PartName,
            ProcessSequence, ProcessTypeId, ProcessTypeName,
            EstimatedTimeHr, PastAccumulatedTimeHr, EstRemainingTime,
            ScheduledStartDate, ScheduledCompleteDate, ActualStartDate, ActualCompleteDate,
            IsOutsourced, EstimatedOutsourcingDays,
            OutsourceVendorId, OutsourceVendorName,
            DefaultVendorId, DefaultVendorName, OutsourcedQuantity,
            MachineGroup, PartQuantity, CompletedQuantity, EstimatedCost, FitterCount,
            IsAbnormalProcess, IsCompleted, IsAssigned, CompletionRate,
            ProcessStatusId, ProcessStatusName, AbnormalOrderNo,
            MachineId, MachineName, WorkstationId,
            RelationProcessTypeId, IsDesignProcessType, RelationProcessId,
            NextProcessId, NextProcessTypeId, NextProcessTypeName, NextProcessSequence, NextProcessStatusId,
            DependentPartTotalCount, DependentPartCompletedCount,
            IsArrived, ArrivalTime,
            DependentPartId, DependentPartNo, DependentPartName,
            Remark, ProcessingDescription,
            LatestWorkMode, LatestWorkerEmployeeId, LatestWorkerEmployeeName,
            LatestWorkStartedTime, LatestWorkPausedTime, LatestWorkCompletedTime,
            DeleteFlag, RecordTimestamp, CreatedDate, LastModifiedTime,
            RefreshedAt
        )
        SELECT
            LTRIM(RTRIM(v.ProcessId)),
            LTRIM(RTRIM(v.SalesOrderId)), LTRIM(RTRIM(v.SalesOrderNo)), v.[Description],
            LTRIM(RTRIM(v.MoldId)), LTRIM(RTRIM(v.MoldNo)), LTRIM(RTRIM(v.MoldName)),
            LTRIM(RTRIM(v.PartId)), LTRIM(RTRIM(v.PartNo)), LTRIM(RTRIM(v.PartName)),
            LTRIM(RTRIM(v.ProcessSequence)), LTRIM(RTRIM(v.ProcessTypeId)), LTRIM(RTRIM(v.ProcessTypeName)),
            v.EstimatedTimeHr, v.PastAccumulatedTimeHr, v.EstRemainingTime,
            v.ScheduledStartDate, v.ScheduledCompleteDate, v.ActualStartDate, v.ActualCompleteDate,
            v.IsOutsourced, v.EstimatedOutsourcingDays,
            LTRIM(RTRIM(v.OutsourceVendorId)), LTRIM(RTRIM(v.OutsourceVendorName)),
            LTRIM(RTRIM(v.DefaultVendorId)), LTRIM(RTRIM(v.DefaultVendorName)), v.OutsourcedQuantity,
            LTRIM(RTRIM(v.MachineGroup)), v.PartQuantity, v.CompletedQuantity, v.EstimatedCost, v.FitterCount,
            v.IsAbnormalProcess, v.IsCompleted, v.IsAssigned, v.CompletionRate,
            LTRIM(RTRIM(v.ProcessStatusId)), v.ProcessStatusName, LTRIM(RTRIM(v.AbnormalOrderNo)),
            LTRIM(RTRIM(v.MachineId)), LTRIM(RTRIM(v.MachineName)), v.WorkstationId,
            LTRIM(RTRIM(v.RelationProcessTypeId)), v.IsDesignProcessType, LTRIM(RTRIM(v.RelationProcessId)),
            LTRIM(RTRIM(v.NextProcessId)), LTRIM(RTRIM(v.NextProcessTypeId)), LTRIM(RTRIM(v.NextProcessTypeName)), LTRIM(RTRIM(v.NextProcessSequence)), LTRIM(RTRIM(v.NextProcessStatusId)),
            v.DependentPartTotalCount, v.DependentPartCompletedCount,
            v.IsArrived, v.ArrivalTime,
            LTRIM(RTRIM(v.DependentPartId)), LTRIM(RTRIM(v.DependentPartNo)), LTRIM(RTRIM(v.DependentPartName)),
            LTRIM(RTRIM(v.Remark)), v.ProcessingDescription,
            LTRIM(RTRIM(v.LatestWorkMode)), LTRIM(RTRIM(v.LatestWorkerEmployeeId)), LTRIM(RTRIM(v.LatestWorkerEmployeeName)),
            v.LatestWorkStartedTime, v.LatestWorkPausedTime, v.LatestWorkCompletedTime,
            v.DeleteFlag, v.RecordTimestamp, v.CreatedDate, v.LastModifiedTime,
            SYSUTCDATETIME()
        FROM [Reporting].[WorkOrderProcessRowDataView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.WorkOrderProcessRowData', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.WorkOrderProcessRowData', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新工令零件製程寬表 (Reporting.WorkOrderProcessRowData)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshWorkOrderProcessRowData';
GO

-- ---------- Stored Procedures/RefreshWorkRecordRowData.sql ----------
CREATE PROCEDURE [Reporting].[RefreshWorkRecordRowData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[WorkRecordRowData];

        INSERT INTO [Reporting].[WorkRecordRowData] (
            WorkRecordId,
            SalesOrderId, SalesOrderNo,
            MoldId, MoldNo, MoldName,
            PartId, PartNo, PartName,
            ProcessId, ProcessSequence, ProcessTypeId, ProcessTypeName,
            WorkStatusCode, WorkStatusName,
            ProcessStatusSnapshotCode, ProcessRateSnapshot,
            WorkReportSourceCode, WorkReportTypeCode, ShiftCode, IsMainJob,
            WorkStartTime, WorkEndTime,
            SystemStartTime, SystemEndTime, PlannedEndDate,
            ElapsedHours, MachineOccupiedHours, ManualEffectiveHours, MachineNetworkHours, AdjustedHours, TimeWeight,
            CompletedQuantity, CompletionRate, TotalWeight,
            QualityStatusCode, QualityStatusName,
            QcGoodQuantity, QcDefectQuantity, QcReviewQuantity, QcRemark,
            WorkerEmployeeId, WorkerEmployeeName, CoWorkerEmployeeIds, MachineId, MachineName, ProcessingRate,
            ApproverEmployeeId, ApproverEmployeeName, ApprovedTime,
            IsMachineTimeComputed, IsMachineTimeAccumulated,
            RepairReasonCode, Remark,
            DeleteFlag, RecordTimestamp, LastModifiedTime,
            RefreshedAt
        )
        SELECT
            LTRIM(RTRIM(v.WorkRecordId)),
            LTRIM(RTRIM(v.SalesOrderId)), LTRIM(RTRIM(v.SalesOrderNo)),
            LTRIM(RTRIM(v.MoldId)), LTRIM(RTRIM(v.MoldNo)), LTRIM(RTRIM(v.MoldName)),
            LTRIM(RTRIM(v.PartId)), LTRIM(RTRIM(v.PartNo)), LTRIM(RTRIM(v.PartName)),
            LTRIM(RTRIM(v.ProcessId)), LTRIM(RTRIM(v.ProcessSequence)), LTRIM(RTRIM(v.ProcessTypeId)), LTRIM(RTRIM(v.ProcessTypeName)),
            LTRIM(RTRIM(v.WorkStatusCode)), v.WorkStatusName,
            LTRIM(RTRIM(v.ProcessStatusSnapshotCode)), v.ProcessRateSnapshot,
            v.WorkReportSourceCode, LTRIM(RTRIM(v.WorkReportTypeCode)), LTRIM(RTRIM(v.ShiftCode)), v.IsMainJob,
            v.WorkStartTime, v.WorkEndTime,
            v.SystemStartTime, v.SystemEndTime, v.PlannedEndDate,
            v.ElapsedHours, v.MachineOccupiedHours, v.ManualEffectiveHours, v.MachineNetworkHours, v.AdjustedHours, v.TimeWeight,
            v.CompletedQuantity, v.CompletionRate, v.TotalWeight,
            LTRIM(RTRIM(v.QualityStatusCode)), v.QualityStatusName,
            v.QcGoodQuantity, v.QcDefectQuantity, v.QcReviewQuantity, v.QcRemark,
            LTRIM(RTRIM(v.WorkerEmployeeId)), LTRIM(RTRIM(v.WorkerEmployeeName)), LTRIM(RTRIM(v.CoWorkerEmployeeIds)), LTRIM(RTRIM(v.MachineId)), LTRIM(RTRIM(v.MachineName)), v.ProcessingRate,
            LTRIM(RTRIM(v.ApproverEmployeeId)), LTRIM(RTRIM(v.ApproverEmployeeName)), v.ApprovedTime,
            v.IsMachineTimeComputed, v.IsMachineTimeAccumulated,
            LTRIM(RTRIM(v.RepairReasonCode)), v.Remark,
            v.DeleteFlag, v.RecordTimestamp, v.LastModifiedTime,
            SYSUTCDATETIME()
        FROM [Reporting].[WorkRecordRowDataView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.WorkRecordRowData', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.WorkRecordRowData', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新報工記錄寬表 (Reporting.WorkRecordRowData)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshWorkRecordRowData';
GO

-- ---------- Stored Procedures/RefreshMoldRowData.sql ----------
CREATE PROCEDURE [Reporting].[RefreshMoldRowData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[MoldRowData];

        INSERT INTO [Reporting].[MoldRowData] (
            MoldId, MoldNo, MoldName, InternalMoldName,
            ProductType, ModelNumber, ProductId,
            MoldSourceTypeId, MoldSourceTypeName,
            PhotoPath, CustomVersion,
            MoldDate, MassProductionDate, T1TrialDate, TrialDate, ScrapDate,
            CustomerId, CustomerSubname,
            DesignerEmployeeId, DesignerEmployeeName,
            AssemblerEmployeeId, AssemblerEmployeeName,
            MoldingOperatorEmployeeId, MoldingOperatorEmployeeName,
            PlannerEmployeeId, PlannerEmployeeName,
            MachineMinTon, MachineMaxTon,
            CavityCount, MoldWeight, ShrinkageRateX, AverageThickness,
            FixedCoreInsertMaterialId, FixedCoreInsertMaterialName,
            MovableCoreInsertMaterialId, MovableCoreInsertMaterialName,
            MoldBaseMaterialId, MoldBaseMaterialName, MoldBaseHardness,
            ProductMaterialId, ProductMaterialName,
            ProductNotes, IsBomRequired,
            IsUnassigned, IsOrderIncomplete,
            DeleteFlag, RecordTimestamp, LastModifiedTime,
            RefreshedAt
        )
        SELECT
            LTRIM(RTRIM(v.MoldId)), LTRIM(RTRIM(v.MoldNo)), LTRIM(RTRIM(v.MoldName)), LTRIM(RTRIM(v.InternalMoldName)),
            LTRIM(RTRIM(v.ProductType)), LTRIM(RTRIM(v.ModelNumber)), LTRIM(RTRIM(v.ProductId)),
            LTRIM(RTRIM(v.MoldSourceTypeId)), v.MoldSourceTypeName,
            LTRIM(RTRIM(v.PhotoPath)), LTRIM(RTRIM(v.CustomVersion)),
            v.MoldDate, v.MassProductionDate, v.T1TrialDate, v.TrialDate, v.ScrapDate,
            LTRIM(RTRIM(v.CustomerId)), LTRIM(RTRIM(v.CustomerSubname)),
            LTRIM(RTRIM(v.DesignerEmployeeId)),          LTRIM(RTRIM(v.DesignerEmployeeName)),
            LTRIM(RTRIM(v.AssemblerEmployeeId)),         LTRIM(RTRIM(v.AssemblerEmployeeName)),
            LTRIM(RTRIM(v.MoldingOperatorEmployeeId)),   LTRIM(RTRIM(v.MoldingOperatorEmployeeName)),
            LTRIM(RTRIM(v.PlannerEmployeeId)),           LTRIM(RTRIM(v.PlannerEmployeeName)),
            v.MachineMinTon, v.MachineMaxTon,
            LTRIM(RTRIM(v.CavityCount)), v.MoldWeight, LTRIM(RTRIM(v.ShrinkageRateX)), v.AverageThickness,
            LTRIM(RTRIM(v.FixedCoreInsertMaterialId)),   LTRIM(RTRIM(v.FixedCoreInsertMaterialName)),
            LTRIM(RTRIM(v.MovableCoreInsertMaterialId)), LTRIM(RTRIM(v.MovableCoreInsertMaterialName)),
            LTRIM(RTRIM(v.MoldBaseMaterialId)),          LTRIM(RTRIM(v.MoldBaseMaterialName)),
            LTRIM(RTRIM(v.MoldBaseHardness)),
            LTRIM(RTRIM(v.ProductMaterialId)),           LTRIM(RTRIM(v.ProductMaterialName)),
            v.ProductNotes, v.IsBomRequired,
            v.IsUnassigned, v.IsOrderIncomplete,
            v.DeleteFlag, v.RecordTimestamp, v.LastModifiedTime,
            SYSUTCDATETIME()
        FROM [Reporting].[MoldRowDataView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.MoldRowData', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.MoldRowData', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新模具寬表 (Reporting.MoldRowData)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshMoldRowData';
GO

-- ---------- Stored Procedures/RefreshMoldPartRowData.sql ----------
CREATE PROCEDURE [Reporting].[RefreshMoldPartRowData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[MoldPartRowData];

        INSERT INTO [Reporting].[MoldPartRowData] (
            MoldPartId, MoldId,
            PartName, PartNameEn, PartNo, DrawingNo, CustomVersion,
            PartTypeId, PartTypeCode, PartTypeName, IsNeedProcessing,
            ProductionReasonId, ProductionReasonName,
            MachiningSpec, PartGroupId, PartGroupName, MaterialSpec,
            SourceTypeId, SourceTypeCode, SourceTypeName,
            MaterialId, MaterialName,
            CadFile, InventoryItemId, Remark,
            Quantity, MaterialWeight, CustomerSpareQuantity, InternalSpareQuantity,
            IsMaterialInspectionNeeded, IsCadChecked,
            CreatedDate, PurchasedDate,
            Priority, HeatTreatmentHardness,
            VendorId, VendorName,
            LastModifiedEmployeeId, LastModifiedEmployeeName, ModifiedDate,
            DeleteFlag, RecordTimestamp, LastModifiedTime,
            RefreshedAt
        )
        SELECT
            LTRIM(RTRIM(v.MoldPartId)), LTRIM(RTRIM(v.MoldId)),
            LTRIM(RTRIM(v.PartName)), LTRIM(RTRIM(v.PartNameEn)), LTRIM(RTRIM(v.PartNo)), LTRIM(RTRIM(v.DrawingNo)), LTRIM(RTRIM(v.CustomVersion)),
            v.PartTypeId, v.PartTypeCode, LTRIM(RTRIM(v.PartTypeName)), v.IsNeedProcessing,
            v.ProductionReasonId, LTRIM(RTRIM(v.ProductionReasonName)),
            LTRIM(RTRIM(v.MachiningSpec)), LTRIM(RTRIM(v.PartGroupId)), LTRIM(RTRIM(v.PartGroupName)), LTRIM(RTRIM(v.MaterialSpec)),
            v.SourceTypeId, v.SourceTypeCode, LTRIM(RTRIM(v.SourceTypeName)),
            LTRIM(RTRIM(v.MaterialId)), LTRIM(RTRIM(v.MaterialName)),
            LTRIM(RTRIM(v.CadFile)), LTRIM(RTRIM(v.InventoryItemId)), LTRIM(RTRIM(v.Remark)),
            v.Quantity, v.MaterialWeight, v.CustomerSpareQuantity, v.InternalSpareQuantity,
            v.IsMaterialInspectionNeeded, v.IsCadChecked,
            v.CreatedDate, v.PurchasedDate,
            LTRIM(RTRIM(v.Priority)), LTRIM(RTRIM(v.HeatTreatmentHardness)),
            LTRIM(RTRIM(v.VendorId)), LTRIM(RTRIM(v.VendorName)),
            LTRIM(RTRIM(v.LastModifiedEmployeeId)), LTRIM(RTRIM(v.LastModifiedEmployeeName)), v.ModifiedDate,
            v.DeleteFlag, v.RecordTimestamp, v.LastModifiedTime,
            SYSUTCDATETIME()
        FROM [Reporting].[MoldPartRowDataView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.MoldPartRowData', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.MoldPartRowData', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新模具零件寬表 (Reporting.MoldPartRowData)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshMoldPartRowData';
GO

-- ---------- Stored Procedures/RefreshPurchaseReceiveRowData.sql ----------
CREATE PROCEDURE [Reporting].[RefreshPurchaseReceiveRowData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[PurchaseReceiveRowData];

        INSERT INTO [Reporting].[PurchaseReceiveRowData] (
            PurchaseReceiveItemId, PurchaseReceiveId, ReceiveNo, PurchaseOrderItemId, LineItemNo,
            ReceiveDate, DeliveryNo, AccountingMonth, CurrencyCode, ExchangeRate, InvoiceNo,
            HeaderSubtotal, HeaderTax, HeaderTotalAmount, TaxRate, ReceiverName, ApproverEmployeeId, ApprovedTime,
            VendorRawId, VendorId, VendorName,
            SalesOrderNo, SalesOrderId, MoldNo, MoldId, MoldName,
            InventoryItemId, PartName, Spec, Material, Unit, Weight,
            Quantity, UnitPrice, Amount, ProcessingFee, DiscountPercent, IsFree,
            PurchaseReason, Remark,
            DeliveryStatusCode, DeliveryStatusName, QualityStatusCode, QualityStatusName,
            HasQcReport, IsClosed, AccountSubject, IncomingQcCode, InspectionCheckedCode,
            DeliveryConfirmedCode, QualityConfirmedCode,
            InspectionDate, AcceptanceDate, InspectorEmployeeId,
            QualifiedQuantity, SpecialAcceptanceQuantity, NgQuantity, StockedQuantity, Quantity3, Quantity5,
            PickedDate, PickerEmployeeId, PickerEmployeeName,
            WorkOrderItemNo,
            LastModifiedEmployeeName, ModifiedDate,
            DeleteFlag, RecordTimestamp, LastModifiedTime,
            RefreshedAt
        )
        SELECT
            LTRIM(RTRIM(v.PurchaseReceiveItemId)), LTRIM(RTRIM(v.PurchaseReceiveId)), LTRIM(RTRIM(v.ReceiveNo)), LTRIM(RTRIM(v.PurchaseOrderItemId)), LTRIM(RTRIM(v.LineItemNo)),
            v.ReceiveDate, LTRIM(RTRIM(v.DeliveryNo)), LTRIM(RTRIM(v.AccountingMonth)), LTRIM(RTRIM(v.CurrencyCode)), v.ExchangeRate, LTRIM(RTRIM(v.InvoiceNo)),
            v.HeaderSubtotal, v.HeaderTax, v.HeaderTotalAmount, v.TaxRate, LTRIM(RTRIM(v.ReceiverName)), LTRIM(RTRIM(v.ApproverEmployeeId)), v.ApprovedTime,
            LTRIM(RTRIM(v.VendorRawId)), LTRIM(RTRIM(v.VendorId)), LTRIM(RTRIM(v.VendorName)),
            LTRIM(RTRIM(v.SalesOrderNo)), LTRIM(RTRIM(v.SalesOrderId)), LTRIM(RTRIM(v.MoldNo)), LTRIM(RTRIM(v.MoldId)), LTRIM(RTRIM(v.MoldName)),
            LTRIM(RTRIM(v.InventoryItemId)), LTRIM(RTRIM(v.PartName)), LTRIM(RTRIM(v.Spec)), LTRIM(RTRIM(v.Material)), LTRIM(RTRIM(v.Unit)), LTRIM(RTRIM(v.Weight)),
            v.Quantity, v.UnitPrice, v.Amount, v.ProcessingFee, v.DiscountPercent, v.IsFree,
            LTRIM(RTRIM(v.PurchaseReason)), LTRIM(RTRIM(v.Remark)),
            LTRIM(RTRIM(v.DeliveryStatusCode)), v.DeliveryStatusName, LTRIM(RTRIM(v.QualityStatusCode)), v.QualityStatusName,
            LTRIM(RTRIM(v.HasQcReport)), LTRIM(RTRIM(v.IsClosed)), LTRIM(RTRIM(v.AccountSubject)), LTRIM(RTRIM(v.IncomingQcCode)), LTRIM(RTRIM(v.InspectionCheckedCode)),
            LTRIM(RTRIM(v.DeliveryConfirmedCode)), LTRIM(RTRIM(v.QualityConfirmedCode)),
            v.InspectionDate, v.AcceptanceDate, LTRIM(RTRIM(v.InspectorEmployeeId)),
            v.QualifiedQuantity, v.SpecialAcceptanceQuantity, v.NgQuantity, v.StockedQuantity, v.Quantity3, v.Quantity5,
            v.PickedDate, LTRIM(RTRIM(v.PickerEmployeeId)), LTRIM(RTRIM(v.PickerEmployeeName)),
            LTRIM(RTRIM(v.WorkOrderItemNo)),
            LTRIM(RTRIM(v.LastModifiedEmployeeName)), v.ModifiedDate,
            v.DeleteFlag, v.RecordTimestamp, v.LastModifiedTime,
            SYSUTCDATETIME()
        FROM [Reporting].[PurchaseReceiveRowDataView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.PurchaseReceiveRowData', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.PurchaseReceiveRowData', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新採購收料寬表 (Reporting.PurchaseReceiveRowData)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshPurchaseReceiveRowData';
GO

-- ---------- Stored Procedures/RefreshOutsourceReceiveRowData.sql ----------
CREATE PROCEDURE [Reporting].[RefreshOutsourceReceiveRowData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[OutsourceReceiveRowData];

        INSERT INTO [Reporting].[OutsourceReceiveRowData] (
            OutsourceReceiveItemId, OutsourceReceiveId, ReceiveNo, OutsourceOrderItemId, LineItemNo,
            ReceiveDate, DeliveryNo, DeliveryDate, AccountingMonth, CurrencyCode, ExchangeRate, InvoiceNo,
            HeaderTax, HeaderSubtotal, HeaderTotalAmount, TaxRate, ReceiverName, OutsourceCategoryName, PrintedTime,
            ApproverEmployeeId, ApprovedTime,
            VendorRawId, VendorId, VendorName,
            SalesOrderNo, SalesOrderId, MoldNo, MoldId, MoldName,
            PartNo, PartName, Spec, Material,
            ProcessTypeId, ProcessTypeName, ProcessTypeNameFromMaster,
            Quantity, EstimatedHours, UnitPrice, ProcessingFee, MaterialFee, Amount, DiscountPercent, IsFree,
            ProcessingDescription, Remark,
            IsClosed, DeliveryStatusCode, DeliveryStatusName, QualityStatusCode, QualityStatusName,
            DeliveryConfirmedCode, QualityConfirmedCode,
            PromisedDeliveryDate,
            WorkOrderItemNo, ProcessSequence,
            LastModifiedEmployeeName, ModifiedDate,
            DeleteFlag, RecordTimestamp, LastModifiedTime,
            RefreshedAt
        )
        SELECT
            LTRIM(RTRIM(v.OutsourceReceiveItemId)), LTRIM(RTRIM(v.OutsourceReceiveId)), LTRIM(RTRIM(v.ReceiveNo)), LTRIM(RTRIM(v.OutsourceOrderItemId)), LTRIM(RTRIM(v.LineItemNo)),
            v.ReceiveDate, LTRIM(RTRIM(v.DeliveryNo)), v.DeliveryDate, LTRIM(RTRIM(v.AccountingMonth)), LTRIM(RTRIM(v.CurrencyCode)), v.ExchangeRate, LTRIM(RTRIM(v.InvoiceNo)),
            v.HeaderTax, v.HeaderSubtotal, v.HeaderTotalAmount, v.TaxRate, LTRIM(RTRIM(v.ReceiverName)), LTRIM(RTRIM(v.OutsourceCategoryName)), v.PrintedTime,
            LTRIM(RTRIM(v.ApproverEmployeeId)), v.ApprovedTime,
            LTRIM(RTRIM(v.VendorRawId)), LTRIM(RTRIM(v.VendorId)), LTRIM(RTRIM(v.VendorName)),
            LTRIM(RTRIM(v.SalesOrderNo)), LTRIM(RTRIM(v.SalesOrderId)), LTRIM(RTRIM(v.MoldNo)), LTRIM(RTRIM(v.MoldId)), LTRIM(RTRIM(v.MoldName)),
            LTRIM(RTRIM(v.PartNo)), LTRIM(RTRIM(v.PartName)), LTRIM(RTRIM(v.Spec)), LTRIM(RTRIM(v.Material)),
            LTRIM(RTRIM(v.ProcessTypeId)), LTRIM(RTRIM(v.ProcessTypeName)), LTRIM(RTRIM(v.ProcessTypeNameFromMaster)),
            v.Quantity, v.EstimatedHours, v.UnitPrice, v.ProcessingFee, v.MaterialFee, v.Amount, v.DiscountPercent, v.IsFree,
            LTRIM(RTRIM(v.ProcessingDescription)), LTRIM(RTRIM(v.Remark)),
            LTRIM(RTRIM(v.IsClosed)), LTRIM(RTRIM(v.DeliveryStatusCode)), v.DeliveryStatusName, LTRIM(RTRIM(v.QualityStatusCode)), v.QualityStatusName,
            LTRIM(RTRIM(v.DeliveryConfirmedCode)), LTRIM(RTRIM(v.QualityConfirmedCode)),
            v.PromisedDeliveryDate,
            LTRIM(RTRIM(v.WorkOrderItemNo)), LTRIM(RTRIM(v.ProcessSequence)),
            LTRIM(RTRIM(v.LastModifiedEmployeeName)), v.ModifiedDate,
            v.DeleteFlag, v.RecordTimestamp, v.LastModifiedTime,
            SYSUTCDATETIME()
        FROM [Reporting].[OutsourceReceiveRowDataView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.OutsourceReceiveRowData', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.OutsourceReceiveRowData', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新外包收料寬表 (Reporting.OutsourceReceiveRowData)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshOutsourceReceiveRowData';
GO

-- ---------- Stored Procedures/RefreshHeatTreatmentReceiveRowData.sql ----------
CREATE PROCEDURE [Reporting].[RefreshHeatTreatmentReceiveRowData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[HeatTreatmentReceiveRowData];

        INSERT INTO [Reporting].[HeatTreatmentReceiveRowData] (
            HeatTreatmentReceiveItemId, HeatTreatmentReceiveId, ReceiveNo, HeatTreatmentOrderItemId, LineItemNo,
            ReceiveDate, AccountingMonth, CurrencyCode, ExchangeRate, InvoiceNo,
            HeaderTax, HeaderSubtotal, HeaderTotalAmount, TaxRate, QcInspectorName, ReceiverName,
            PaymentTermsCode, HeaderCategoryCode, ApproverEmployeeId, ApprovedTime,
            VendorRawId, VendorId, VendorName,
            SalesOrderNo, SalesOrderId, MoldNo, MoldId, MoldName,
            PartNo, PartName, Spec, Material, Unit, Weight,
            ProcessTypeId, ProcessTypeName, ProcessTypeNameFromMaster, HeatTreatmentTypeCode, HeatTreatmentTypeCodeAlt,
            HardnessRequirement, MeasuredHardness,
            Quantity, UnitPrice, Amount, IsFree,
            Remark,
            IsClosed, DeliveryStatusCode, DeliveryStatusName, QualityStatusCode, QualityStatusName,
            DeliveryConfirmedCode, QualityConfirmedCode, HasReport, RequiresReport,
            WorkOrderItemNo, ProcessSequence,
            DeleteFlag, RecordTimestamp, LastModifiedTime,
            RefreshedAt
        )
        SELECT
            LTRIM(RTRIM(v.HeatTreatmentReceiveItemId)), LTRIM(RTRIM(v.HeatTreatmentReceiveId)), LTRIM(RTRIM(v.ReceiveNo)), LTRIM(RTRIM(v.HeatTreatmentOrderItemId)), LTRIM(RTRIM(v.LineItemNo)),
            v.ReceiveDate, LTRIM(RTRIM(v.AccountingMonth)), LTRIM(RTRIM(v.CurrencyCode)), v.ExchangeRate, LTRIM(RTRIM(v.InvoiceNo)),
            v.HeaderTax, v.HeaderSubtotal, v.HeaderTotalAmount, v.TaxRate, LTRIM(RTRIM(v.QcInspectorName)), LTRIM(RTRIM(v.ReceiverName)),
            LTRIM(RTRIM(v.PaymentTermsCode)), LTRIM(RTRIM(v.HeaderCategoryCode)), LTRIM(RTRIM(v.ApproverEmployeeId)), v.ApprovedTime,
            LTRIM(RTRIM(v.VendorRawId)), LTRIM(RTRIM(v.VendorId)), LTRIM(RTRIM(v.VendorName)),
            LTRIM(RTRIM(v.SalesOrderNo)), LTRIM(RTRIM(v.SalesOrderId)), LTRIM(RTRIM(v.MoldNo)), LTRIM(RTRIM(v.MoldId)), LTRIM(RTRIM(v.MoldName)),
            LTRIM(RTRIM(v.PartNo)), LTRIM(RTRIM(v.PartName)), LTRIM(RTRIM(v.Spec)), LTRIM(RTRIM(v.Material)), LTRIM(RTRIM(v.Unit)), LTRIM(RTRIM(v.Weight)),
            LTRIM(RTRIM(v.ProcessTypeId)), LTRIM(RTRIM(v.ProcessTypeName)), LTRIM(RTRIM(v.ProcessTypeNameFromMaster)), LTRIM(RTRIM(v.HeatTreatmentTypeCode)), LTRIM(RTRIM(v.HeatTreatmentTypeCodeAlt)),
            LTRIM(RTRIM(v.HardnessRequirement)), LTRIM(RTRIM(v.MeasuredHardness)),
            v.Quantity, v.UnitPrice, v.Amount, v.IsFree,
            LTRIM(RTRIM(v.Remark)),
            LTRIM(RTRIM(v.IsClosed)), LTRIM(RTRIM(v.DeliveryStatusCode)), v.DeliveryStatusName, LTRIM(RTRIM(v.QualityStatusCode)), v.QualityStatusName,
            LTRIM(RTRIM(v.DeliveryConfirmedCode)), LTRIM(RTRIM(v.QualityConfirmedCode)), LTRIM(RTRIM(v.HasReport)), v.RequiresReport,
            LTRIM(RTRIM(v.WorkOrderItemNo)), LTRIM(RTRIM(v.ProcessSequence)),
            v.DeleteFlag, v.RecordTimestamp, v.LastModifiedTime,
            SYSUTCDATETIME()
        FROM [Reporting].[HeatTreatmentReceiveRowDataView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.HeatTreatmentReceiveRowData', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.HeatTreatmentReceiveRowData', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新熱處理外包收料寬表 (Reporting.HeatTreatmentReceiveRowData)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshHeatTreatmentReceiveRowData';
GO

-- ---------- Stored Procedures/RefreshMoldCostSummary.sql ----------
CREATE PROCEDURE [Reporting].[RefreshMoldCostSummary]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[MoldCostSummary];

        INSERT INTO [Reporting].[MoldCostSummary] (
            MoldId, MoldNo, MoldName,
            TotalProcessingHours, FirstWorkStartTime, LastWorkEndTime, WorkPeriodDays,
            LaborCost, MaterialCost, GeneralOutsourceCost, HeatTreatmentCost, OutsourceCost, TotalCost,
            HasWorkRecord, HasPurchase, HasOutsource, HasHeatTreatment,
            RefreshedAt
        )
        SELECT
            v.MoldId, v.MoldNo, v.MoldName,
            v.TotalProcessingHours, v.FirstWorkStartTime, v.LastWorkEndTime, v.WorkPeriodDays,
            v.LaborCost, v.MaterialCost, v.GeneralOutsourceCost, v.HeatTreatmentCost, v.OutsourceCost, v.TotalCost,
            v.HasWorkRecord, v.HasPurchase, v.HasOutsource, v.HasHeatTreatment,
            SYSUTCDATETIME()
        FROM [Reporting].[MoldCostSummaryView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.MoldCostSummary', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.MoldCostSummary', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新模具成本總表彙總寬表 (Reporting.MoldCostSummary)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。依賴四張 base 寬表：WorkRecordRowData / PurchaseReceiveRowData / OutsourceReceiveRowData / HeatTreatmentReceiveRowData。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshMoldCostSummary';
GO

-- ---------- Stored Procedures/RefreshMoldPartCostSummary.sql ----------
CREATE PROCEDURE [Reporting].[RefreshMoldPartCostSummary]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[MoldPartCostSummary];

        INSERT INTO [Reporting].[MoldPartCostSummary] (
            PartId, MoldId, MoldNo, MoldName, PartNo, PartName,
            TotalProcessingHours, FirstWorkStartTime, LastWorkEndTime, WorkPeriodDays,
            LaborCost, MaterialCost, GeneralOutsourceCost, HeatTreatmentCost, OutsourceCost, TotalCost,
            HasWorkRecord, HasPurchase, HasOutsource, HasHeatTreatment,
            RefreshedAt
        )
        SELECT
            v.PartId, v.MoldId, v.MoldNo, v.MoldName, v.PartNo, v.PartName,
            v.TotalProcessingHours, v.FirstWorkStartTime, v.LastWorkEndTime, v.WorkPeriodDays,
            v.LaborCost, v.MaterialCost, v.GeneralOutsourceCost, v.HeatTreatmentCost, v.OutsourceCost, v.TotalCost,
            v.HasWorkRecord, v.HasPurchase, v.HasOutsource, v.HasHeatTreatment,
            SYSUTCDATETIME()
        FROM [Reporting].[MoldPartCostSummaryView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.MoldPartCostSummary', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.MoldPartCostSummary', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新模具零件成本彙總寬表 (Reporting.MoldPartCostSummary)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。依賴四張 base 寬表 + WorkOrderPartRowData。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshMoldPartCostSummary';
GO

-- ---------- Stored Procedures/RefreshMoldPartProcessCostSummary.sql ----------
CREATE PROCEDURE [Reporting].[RefreshMoldPartProcessCostSummary]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @StartedAt    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected INT          = 0;
    DECLARE @DurationMs   INT;
    DECLARE @ErrorMsg     NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE [Reporting].[MoldPartProcessCostSummary];

        INSERT INTO [Reporting].[MoldPartProcessCostSummary] (
            MoldId, MoldNo, MoldName, PartId, PartNo, PartName, ProcessTypeId, ProcessTypeName,
            TotalProcessingHours, FirstWorkStartTime, LastWorkEndTime, WorkPeriodDays,
            LaborCost, GeneralOutsourceCost, HeatTreatmentCost, OutsourceCost, TotalCost,
            HasWorkRecord, HasOutsource, HasHeatTreatment, IsOutsourced,
            RefreshedAt
        )
        SELECT
            v.MoldId, v.MoldNo, v.MoldName, v.PartId, v.PartNo, v.PartName, v.ProcessTypeId, v.ProcessTypeName,
            v.TotalProcessingHours, v.FirstWorkStartTime, v.LastWorkEndTime, v.WorkPeriodDays,
            v.LaborCost, v.GeneralOutsourceCost, v.HeatTreatmentCost, v.OutsourceCost, v.TotalCost,
            v.HasWorkRecord, v.HasOutsource, v.HasHeatTreatment, v.IsOutsourced,
            SYSUTCDATETIME()
        FROM [Reporting].[MoldPartProcessCostSummaryView] v;

        SET @RowsAffected = @@ROWCOUNT;

        COMMIT TRAN;

        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.MoldPartProcessCostSummary', @StartedAt, @DurationMs, @RowsAffected, N'Success', NULL);

        SELECT @RowsAffected AS RowsAffected, @DurationMs AS DurationMs;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        SET @ErrorMsg   = ERROR_MESSAGE();
        SET @DurationMs = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());

        INSERT INTO [Reporting].[RefreshLog] (TargetTable, StartedAt, DurationMs, RowsAffected, Status, ErrorMessage)
        VALUES (N'Reporting.MoldPartProcessCostSummary', @StartedAt, @DurationMs, 0, N'Failed', @ErrorMsg);

        THROW;
    END CATCH
END

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新模具零件製程成本彙總寬表 (Reporting.MoldPartProcessCostSummary)：TRUNCATE + INSERT 自 View，並寫 RefreshLog。最細粒度成本，無料費。', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'PROCEDURE', @level1name = N'RefreshMoldPartProcessCostSummary';
GO
