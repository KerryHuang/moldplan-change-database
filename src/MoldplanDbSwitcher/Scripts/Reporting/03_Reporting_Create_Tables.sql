USE [<<Database>>];   -- ⚠️ 部署時把 <<Database>> 換成目標資料庫（獨立庫部署＝MoldPlan-Reporting；舊同庫部署＝客戶主庫名）
GO

-- ============================================================
-- 10 Reporting Create Tables (one-shot)
-- Source: apps/rest-api-v3/06.Database/.../Reporting/Tables/
-- Run after 00_Reporting_Create_Schema.sql
-- Order: RefreshLog 先（其他 SP 寫入此表），其餘 base/summary 互無依賴
-- ============================================================
GO

-- ---------- Tables/RefreshLog.sql ----------
CREATE TABLE [Reporting].[RefreshLog] (
    [Id]            BIGINT IDENTITY (1, 1) NOT NULL,
    [TargetTable]   NVARCHAR (128)         NOT NULL,
    [StartedAt]     DATETIME2 (3)          NOT NULL,
    [DurationMs]    INT                    NOT NULL,
    [RowsAffected]  INT                    NOT NULL,
    [Status]        NVARCHAR (20)          NOT NULL,
    [ErrorMessage]  NVARCHAR (MAX)         NULL,
    [CreatedAt]     DATETIME2 (3)          CONSTRAINT [DF_RefreshLog_CreatedAt] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_RefreshLog] PRIMARY KEY CLUSTERED ([Id] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_RefreshLog_TargetTable_StartedAt]
    ON [Reporting].[RefreshLog] ([TargetTable] ASC, [StartedAt] DESC)
    INCLUDE ([DurationMs], [RowsAffected], [Status]);

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Reporting 寬表刷新日誌（記錄每次排程刷新的成敗、耗時、列數）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'RefreshLog';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'流水號 (自增主鍵)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'RefreshLog', @level2type = N'COLUMN', @level2name = N'Id';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'目標 Reporting 表全名 (例: Reporting.SalesOrderRowData)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'RefreshLog', @level2type = N'COLUMN', @level2name = N'TargetTable';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'本次刷新開始時間 (UTC)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'RefreshLog', @level2type = N'COLUMN', @level2name = N'StartedAt';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新耗時 (毫秒)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'RefreshLog', @level2type = N'COLUMN', @level2name = N'DurationMs';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'本次刷新寫入列數 (失敗時為 0)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'RefreshLog', @level2type = N'COLUMN', @level2name = N'RowsAffected';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新結果 (Success / Failed)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'RefreshLog', @level2type = N'COLUMN', @level2name = N'Status';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'失敗時的錯誤訊息 (成功為 NULL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'RefreshLog', @level2type = N'COLUMN', @level2name = N'ErrorMessage';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'紀錄寫入時間 (UTC，與 StartedAt 可能有微小差距)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'RefreshLog', @level2type = N'COLUMN', @level2name = N'CreatedAt';
GO

-- ---------- Tables/SalesOrderRowData.sql ----------
CREATE TABLE [Reporting].[SalesOrderRowData] (
    -- 寬表代理主鍵
    [RowId]                     BIGINT IDENTITY (1, 1) NOT NULL,

    -- 訂單基本資訊
    [SalesOrderId]              NVARCHAR (10)      NOT NULL,
    [SalesOrderNo]              NVARCHAR (30)  NULL,
    [DocumentNo]                NVARCHAR (50)  NULL,
    [QuotationNo]               NVARCHAR (30)  NULL,
    [CustomerOrderNo]           NVARCHAR (30)  NULL,
    [CustomerPurchaseOrderNo]   NVARCHAR (50)  NULL,
    [Payment]                   NVARCHAR (100) NULL,

    -- 客戶
    [CustomerId]                NVARCHAR (20)  NULL,
    [CustomerSubname]           NVARCHAR (100) NULL,

    -- 訂單類型 / 類別 / 產品類別
    [SalesOrderTypeId]          UNIQUEIDENTIFIER NULL,
    [SalesOrderTypeCode]        NVARCHAR (10)    NULL,
    [SalesOrderTypeName]        NVARCHAR (50)    NULL,
    [BusinessPattern]           NVARCHAR (30)    NULL,
    [SalesOrderCategoryId]      UNIQUEIDENTIFIER NULL,
    [SalesOrderCategoryCode]    NVARCHAR (10)    NULL,
    [SalesOrderCategoryName]    NVARCHAR (50)    NULL,
    [ProductTypeId]             NVARCHAR (10)        NULL,
    [ProductTypeCode]           NVARCHAR (20)    NULL,
    [ProductTypeName]           NVARCHAR (100)   NULL,

    -- 幣別 / 金額
    [CurrencyId]                NVARCHAR (10)  NULL,
    [CurrencyName]              NVARCHAR (50)  NULL,
    [ExchangeRate]              DECIMAL (18, 6) NULL,
    [OrderTotal]                DECIMAL (18, 4) NULL,
    [PayableAmount]             DECIMAL (18, 4) NULL,
    [FreeAmount]                DECIMAL (18, 4) NULL,
    [LatePenaltyAmount]         DECIMAL (18, 4) NULL,

    -- 狀態 / 緊急程度
    [SalesOrderStatusId]        UNIQUEIDENTIFIER NULL,
    [SalesOrderStatusCode]      NVARCHAR (5)   NULL,
    [SalesOrderStatusName]      NVARCHAR (30)  NULL,
    [CustomCode]                NVARCHAR (10)  NULL,
    [UrgencyTypeId]             INT            NULL,
    [UrgencyTypeCode]           NVARCHAR (5)   NULL,
    [UrgencyTypeName]           NVARCHAR (30)  NULL,

    -- 備註
    [Description]               NVARCHAR (MAX) NULL,
    [GeneralNote]               NVARCHAR (MAX) NULL,
    [ProductionNote]            NVARCHAR (MAX) NULL,
    [DiscussionNotes]           NVARCHAR (MAX) NULL,

    -- 時間
    [InputDate]                 DATETIME       NULL,
    [OrderDate]                 DATETIME       NULL,
    [T1TrialDate]               DATETIME       NULL,
    [CompletionDate]            DATETIME       NULL,
    [DeliveryDate]              DATETIME       NULL,
    [FactoryDueDate]            DATETIME       NULL,
    [FactoryCompletionDate]     DATETIME       NULL,

    -- 人員
    [PlannerEmployeeId]         NVARCHAR (10)  NULL,
    [PlannerEmployeeName]       NVARCHAR (50)  NULL,
    [SalespersonId]             NVARCHAR (10)  NULL,
    [SalespersonName]           NVARCHAR (50)  NULL,
    [FitterEmployeeId]          NVARCHAR (10)  NULL,
    [FitterEmployeeName]        NVARCHAR (50)  NULL,
    [CreatedEmployeeId]         NVARCHAR (10)  NULL,
    [CreatedEmployeeName]       NVARCHAR (50)  NULL,

    -- 修改紀錄
    [LastModifiedEmployeeId]    NVARCHAR (10)  NULL,
    [LastModifiedEmployeeName]  NVARCHAR (50)  NULL,
    [ModifiedDate]              DATETIME       NULL,

    -- 通用
    [DeleteFlag]                BIT            CONSTRAINT [DF_SalesOrderRowData_DeleteFlag] DEFAULT ((0)) NOT NULL,
    [RecordTimestamp]           BINARY (8)     NULL,
    [LastModifiedTime]          DATETIME2 (7)  NULL,

    -- 模具
    [MoldId]                    NVARCHAR (20)  NULL,
    [MoldNo]                    NVARCHAR (30)  NULL,
    [MoldName]                  NVARCHAR (100) NULL,

    -- 計算欄位
    [IsShipped]                 BIT            CONSTRAINT [DF_SalesOrderRowData_IsShipped] DEFAULT ((0)) NOT NULL,
    [IsDiscount]                BIT            CONSTRAINT [DF_SalesOrderRowData_IsDiscount] DEFAULT ((0)) NOT NULL,
    [CompletedDays]             INT            NULL,

    -- 刷新中繼資料
    [RefreshedAt]               DATETIME2 (3)  CONSTRAINT [DF_SalesOrderRowData_RefreshedAt] DEFAULT (SYSUTCDATETIME()) NOT NULL,

    CONSTRAINT [PK_SalesOrderRowData] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderRowData_SalesOrderId]
    ON [Reporting].[SalesOrderRowData] ([SalesOrderId] ASC);

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderRowData_SalesOrderNo]
    ON [Reporting].[SalesOrderRowData] ([SalesOrderNo] ASC);

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderRowData_Status_OrderDate]
    ON [Reporting].[SalesOrderRowData] ([SalesOrderStatusCode] ASC, [OrderDate] DESC)
    INCLUDE ([CustomerId], [BusinessPattern], [OrderTotal]);

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderRowData_Customer_OrderDate]
    ON [Reporting].[SalesOrderRowData] ([CustomerId] ASC, [OrderDate] DESC)
    INCLUDE ([SalesOrderStatusCode], [OrderTotal], [CurrencyId]);

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderRowData_Salesperson_OrderDate]
    ON [Reporting].[SalesOrderRowData] ([SalespersonId] ASC, [OrderDate] DESC)
    INCLUDE ([CustomerId], [OrderTotal], [SalesOrderStatusCode]);

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderRowData_DeliveryDate]
    ON [Reporting].[SalesOrderRowData] ([DeliveryDate] ASC)
    INCLUDE ([SalesOrderStatusCode], [CustomerId], [MoldNo])
    WHERE [DeliveryDate] IS NOT NULL;

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderRowData_MoldNo]
    ON [Reporting].[SalesOrderRowData] ([MoldNo] ASC)
    WHERE [MoldNo] IS NOT NULL;

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderRowData_BusinessPattern_OrderDate]
    ON [Reporting].[SalesOrderRowData] ([BusinessPattern] ASC, [OrderDate] DESC)
    INCLUDE ([CustomerId], [OrderTotal], [SalesOrderStatusCode]);

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'銷售訂單報表寬表（SAL041 + 維度展平，由排程刷新）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵 (IDENTITY，每次刷新自動產生)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'RowId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID (SAL04_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'文件編號 [鼎新訂單編號]', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'DocumentNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報價單號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'QuotationNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶訂單編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CustomerOrderNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶單號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CustomerPurchaseOrderNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'付款辦法', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'Payment';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CustomerId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶簡稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CustomerSubname';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'業務模式 (MoldProject/RepairProject/null)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'BusinessPattern';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單狀態代碼 (T=試模, Y=結案, P=暫停, C=作廢, K=待確認, D=銷毀)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderStatusCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'鼎新結案碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CustomCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類型ID (Sales.SalesOrderType.Id)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類型代碼 (Sales.SalesOrderType.SalesOrderTypeCode)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類型名稱 (TYPE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類別ID (Sales.SalesOrderCategory.Id)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderCategoryId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類別代碼 (Sales.SalesOrderCategory.SalesOrderCategoryCode)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderCategoryCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類別名稱 (TYPE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderCategoryName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品類別ID (PCM206.NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'ProductTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品類別代碼 (PRDNA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'ProductTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品類別名稱 (PCM206.REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'ProductTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'幣別ID (SAL051.BIL_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CurrencyId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'幣別名稱 (SAL051.BIL_NA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CurrencyName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'匯率 (EXCHANGE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'ExchangeRate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單總額 (AMT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'OrderTotal';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'應收金額 (AMT_Y)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'PayableAmount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'免收金額 (AMT_N)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'FreeAmount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'延遲罰款金額 (AMT_X)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'LatePenaltyAmount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單狀態ID (Sales.SalesOrderStatus.Id)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderStatusId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單狀態名稱 (Sales.SalesOrderStatus.SalesOrderStatusName)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderStatusName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'緊急程度ID (Sales.UrgencyType.UrgencyTypeId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'UrgencyTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'緊急程度代碼 (URGENT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'UrgencyTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'緊急程度名稱 (Sales.UrgencyType.UrgencyTypeName)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'UrgencyTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'主要內容 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'Description';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'一般備註 (MEMO1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'GeneralNote';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生產備註 (MEMO2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'ProductionNote';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'討論備註 (MEMO3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'DiscussionNotes';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'輸入日期 (DATE_INPUT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'InputDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單日期 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'OrderDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'T1 試模日 (T1_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'T1TrialDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'結案日 (OK_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CompletionDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'交期 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'DeliveryDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠內交期 (DATE4)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'FactoryDueDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠內完工日 (DATE6)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'FactoryCompletionDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生管人員ID (HumanResources.Employee.EmployeeId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生管人員姓名 (NAME3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'業務員ID (SAL270 對應，目前未填)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalespersonId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'業務員姓名 (SALES)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'SalespersonName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'鉗工ID (Sales.SalesOrderExt.FitterEmployeeId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'FitterEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'鉗工姓名 (HumanResources.Employee.EmployeeName)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'FitterEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'建檔員工ID (HumanResources.Employee.EmployeeId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CreatedEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'建檔員工姓名 (EMP_NA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CreatedEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改員工ID (HumanResources.Employee.EmployeeId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改員工姓名 (MOD_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'修改日期 (MOD_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'ModifiedDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記 (DEL_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳 (TIMESTAMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID (PCM010.PCM01_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'MoldId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'MoldNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱 (DIE_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'MoldName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否已出貨 (SHIP_DT 非空判斷)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'IsShipped';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否折扣 (AMT_N 為 0 判斷)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'IsDiscount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完成天數 (DATEDIFF(DAY, GETDATE(), OK_DATE)，未結案為 NULL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'CompletedDays';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新時間 (UTC)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderRowData', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/SalesOrderDetailRowData.sql ----------
CREATE TABLE [Reporting].[SalesOrderDetailRowData] (
    -- 寬表代理主鍵
    [RowId]                     BIGINT IDENTITY (1, 1) NOT NULL,

    -- 主鍵 / 關聯
    [SalesOrderDetailId]        NVARCHAR (10)         NOT NULL,
    [SalesOrderId]              NVARCHAR (10)         NOT NULL,
    [PaddedIndex]               NVARCHAR (4)          NULL,

    -- 品項
    [LineItemNo]                NVARCHAR (20)     NULL,
    [LineItemName]              NVARCHAR (50)     NULL,
    [VersionNumber]             NVARCHAR (5)      NULL,
    [DrawingNumber]             NVARCHAR (30)     NULL,

    -- 零件類別
    [PartTypeId]                UNIQUEIDENTIFIER  NULL,
    [PartTypeCode]              NVARCHAR (10)     NULL,
    [PartTypeName]              NVARCHAR (10)     NULL,

    -- 材料 / 材質
    [MaterialSpec]              NVARCHAR (80)     NULL,
    [MaterialId]                NVARCHAR (10)         NULL,
    [MaterialName]              NVARCHAR (15)     NULL,

    -- 來源類別
    [SourceTypeId]              UNIQUEIDENTIFIER  NULL,
    [SourceTypeCode]            NVARCHAR (1)      NULL,
    [SourceTypeName]            NVARCHAR (10)     NULL,

    -- 數量 / 金額
    [OrderQuantity]             DECIMAL (20, 0)   CONSTRAINT [DF_SalesOrderDetailRowData_OrderQuantity]   DEFAULT ((0)) NOT NULL,
    [ShippedQuantity]           DECIMAL (20, 0)   CONSTRAINT [DF_SalesOrderDetailRowData_ShippedQuantity] DEFAULT ((0)) NOT NULL,
    [UnitPrice]                 DECIMAL (12, 4)   CONSTRAINT [DF_SalesOrderDetailRowData_UnitPrice]       DEFAULT ((0)) NOT NULL,
    [LineTotal]                 DECIMAL (12, 4)   CONSTRAINT [DF_SalesOrderDetailRowData_LineTotal]       DEFAULT ((0)) NOT NULL,

    -- 單位
    [UnitId]                    NVARCHAR (10)         NULL,
    [UnitName]                  NVARCHAR (4)      NULL,

    -- 時間 / 其他
    [ScheduledDeliveryDate]     DATETIME          NULL,
    [QuotationOrderId]          NVARCHAR (10)         NULL,
    [Remark]                    NVARCHAR (200)    NULL,

    -- 通用
    [DeleteFlag]                BIT               CONSTRAINT [DF_SalesOrderDetailRowData_DeleteFlag] DEFAULT ((0)) NOT NULL,
    [LastModifiedTime]          DATETIME          NULL,
    [RecordTimestamp]           BINARY (8)        NULL,

    -- 刷新中繼資料
    [RefreshedAt]               DATETIME2 (3)     CONSTRAINT [DF_SalesOrderDetailRowData_RefreshedAt] DEFAULT (SYSUTCDATETIME()) NOT NULL,

    CONSTRAINT [PK_SalesOrderDetailRowData] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderDetailRowData_SalesOrderDetailId]
    ON [Reporting].[SalesOrderDetailRowData] ([SalesOrderDetailId] ASC);

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderDetailRowData_SalesOrderId]
    ON [Reporting].[SalesOrderDetailRowData] ([SalesOrderId] ASC, [PaddedIndex] ASC)
    INCLUDE ([LineItemNo], [LineItemName], [OrderQuantity], [ShippedQuantity], [LineTotal]);

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderDetailRowData_LineItemNo]
    ON [Reporting].[SalesOrderDetailRowData] ([LineItemNo] ASC)
    INCLUDE ([SalesOrderId], [OrderQuantity], [ShippedQuantity])
    WHERE [LineItemNo] IS NOT NULL;

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderDetailRowData_PartType]
    ON [Reporting].[SalesOrderDetailRowData] ([PartTypeCode] ASC)
    INCLUDE ([SalesOrderId], [LineItemNo], [LineTotal]);

GO
CREATE NONCLUSTERED INDEX [IX_SalesOrderDetailRowData_DeliveryDate]
    ON [Reporting].[SalesOrderDetailRowData] ([ScheduledDeliveryDate] ASC)
    INCLUDE ([SalesOrderId], [LineItemNo], [OrderQuantity], [ShippedQuantity])
    WHERE [ScheduledDeliveryDate] IS NOT NULL;

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'銷售訂單明細報表寬表（SAL042 + 維度展平，由排程刷新）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵 (IDENTITY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'RowId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單明細ID (SAL042_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderDetailId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID (SAL04_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'項次 (ITEM_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'PaddedIndex';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品號 / 零件編號 / 模具編號 (PROD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'LineItemNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品名 / 零件名稱 / 模具名稱 (DESCRIP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'LineItemName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材料尺寸 (SPECF)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'MaterialSpec';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'版次 (EDITION)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'VersionNumber';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'圖號 (DWG_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'DrawingNumber';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別ID (Production.PartType.Id)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'PartTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別代碼 (Production.PartType.PartTypeCode)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'PartTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別名稱 (TYPE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'PartTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質ID (Production.MaterialType.MaterialId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'MaterialId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質名稱 (MTRL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'MaterialName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源類別ID (Production.SourceType.Id)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'SourceTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源類別代碼 (Production.SourceType.SourceTypeCode)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'SourceTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源類別名稱 (PURCH_YN)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'SourceTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'OrderQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'已出貨量 (QTY2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'ShippedQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單價 (PRICE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'UnitPrice';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'金額 (AMOUNT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'LineTotal';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位ID (Production.Unit.UnitId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'UnitId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位名稱 (UNIT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'UnitName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預定交期 (DELIVERY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'ScheduledDeliveryDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'估價單號 (SAL022_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'QuotationOrderId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註 (REMARK2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'Remark';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記 (DEL_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳 (TIMESTAMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新時間 (UTC)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'SalesOrderDetailRowData', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/WorkOrderPartRowData.sql ----------
CREATE TABLE [Reporting].[WorkOrderPartRowData] (
    [RowId]                      BIGINT           IDENTITY (1, 1) NOT NULL,
    [Id]                         NVARCHAR (10)    NOT NULL,
    [SalesOrderId]               NVARCHAR (10)    NULL,
    [SalesOrderNo]               NVARCHAR (10)    NULL,
    [MoldId]                     NVARCHAR (10)    NULL,
    [MoldNo]                     NVARCHAR (20)    NULL,
    [MoldName]                   NVARCHAR (100)   NULL,
    [PartNo]                     NVARCHAR (20)    NULL,
    [PartName]                   NVARCHAR (50)    NULL,
    [DrawingNo]                  NVARCHAR (30)    NULL,
    [Version]                    NVARCHAR (3)     NULL,
    [Quantity]                   DECIMAL (8)      NULL,
    [MachiningSpec]              NVARCHAR (50)    NULL,
    [MaterialSpec]               NVARCHAR (50)    NULL,
    [DesignCompletionDate]       DATETIME         NULL,
    [EBomPartNo]                 NVARCHAR (20)    NULL,
    [MaterialId]                 NVARCHAR (10)    NULL,
    [MaterialName]               NVARCHAR (15)    NULL,
    [PartTypeId]                 UNIQUEIDENTIFIER NULL,
    [PartTypeCode]               NVARCHAR (10)    NULL,
    [PartTypeName]               NVARCHAR (6)     NULL,
    [PartGroupId]                NVARCHAR (20)    NULL,
    [PartGroupName]              NVARCHAR (20)    NULL,
    [SourceTypeId]               UNIQUEIDENTIFIER NULL,
    [SourceTypeCode]             NVARCHAR (1)     NULL,
    [SourceTypeName]             NVARCHAR (10)    NULL,
    [VendorId]                   NVARCHAR (15)    NULL,
    [VendorName]                 NVARCHAR (15)    NULL,
    [PurchasedDate]              DATETIME         NULL,
    [InternalSpareQuantity]      DECIMAL (20)     NULL,
    [CustomerSpareQuantity]      DECIMAL (20)     NULL,
    [MaterialWeight]             DECIMAL (12, 3)  NULL,
    [EstimatedMaterialCost]      DECIMAL (20, 2)  NULL,
    [IsNeedProcessing]           BIT              CONSTRAINT [DF_WorkOrderPartRowData_IsNeedProcessing] DEFAULT ((0)) NOT NULL,
    [IsOutsource]                BIT              CONSTRAINT [DF_WorkOrderPartRowData_IsOutsource] DEFAULT ((0)) NOT NULL,
    [IsMaterialInspectionNeeded] BIT              CONSTRAINT [DF_WorkOrderPartRowData_IsMaterialInspectionNeeded] DEFAULT ((0)) NOT NULL,
    [UnitId]                     NVARCHAR (10)    NULL,
    [UnitName]                   NVARCHAR (3)     NULL,
    [InventoryItemId]            NVARCHAR (20)    NULL,
    [InventoryItemName]          NVARCHAR (50)    NULL,
    [WarehouseQuantity]          DECIMAL (10, 2)  NULL,
    [ProductionReasonId]         NVARCHAR (1)     NULL,
    [ProductionReasonName]       NVARCHAR (20)    NULL,
    [IsProcessingStepIndex]      BIT              CONSTRAINT [DF_WorkOrderPartRowData_IsProcessingStepIndex] DEFAULT ((0)) NOT NULL,
    [IsConfirmed]                BIT              CONSTRAINT [DF_WorkOrderPartRowData_IsConfirmed] DEFAULT ((0)) NOT NULL,
    [PartStatusId]               NVARCHAR (1)     NULL,
    [PartStatusName]             NVARCHAR (20)    NULL,
    [ScrapQuantity]              DECIMAL (8)      NULL,
    [ClosureDate]                DATETIME         NULL,
    [EarliestStartDate]          DATETIME         NULL,
    [LatestEndDate]              DATETIME         NULL,
    [ParentPartNo]               NVARCHAR (20)    NULL,
    [Remark]                     NVARCHAR (80)    NULL,
    [Priority]                   NVARCHAR (3)     NULL,
    [PlannerEmployeeId]          NVARCHAR (10)    NULL,
    [PlannerEmployeeName]        NVARCHAR (50)    NULL,
    [ProcessCheckCode]           NVARCHAR (1)     NULL,
    [ProcessCheckName]           NVARCHAR (20)    NULL,
    [ProcessCheckTime]           DATETIME         NULL,
    [ProcessChangeRecord]        NVARCHAR (MAX)   NULL,
    [ProductionStartDate]        DATETIME         NULL,
    [CadFile]                    NVARCHAR (100)   NULL,
    [CostAttributionPartId]      NVARCHAR (10)    NULL,
    [CostAttributionPartNo]      NVARCHAR (20)    NULL,
    [CostAttributionPartName]    NVARCHAR (50)    NULL,
    [DeleteFlag]                 BIT              CONSTRAINT [DF_WorkOrderPartRowData_DeleteFlag] DEFAULT ((0)) NOT NULL,
    [RecordTimestamp]            BINARY (8)       NULL,
    [CreatedDate]                DATETIME         NULL,
    [LastModifiedTime]           DATETIME         NULL,
    [RefreshedAt]                DATETIME2 (3)    CONSTRAINT [DF_WorkOrderPartRowData_RefreshedAt] DEFAULT (sysutcdatetime()) NOT NULL,
    CONSTRAINT [PK_WorkOrderPartRowData] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderPartRowData_Id]
    ON [Reporting].[WorkOrderPartRowData] ([Id] ASC);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderPartRowData_SalesOrder]
    ON [Reporting].[WorkOrderPartRowData] ([SalesOrderId] ASC)
    INCLUDE ([PartNo], [PartName], [PartStatusId], [PartTypeCode]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderPartRowData_Mold]
    ON [Reporting].[WorkOrderPartRowData] ([MoldId] ASC, [PartNo] ASC)
    INCLUDE ([PartName], [PartStatusId]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderPartRowData_PartStatus]
    ON [Reporting].[WorkOrderPartRowData] ([PartStatusId] ASC)
    INCLUDE ([SalesOrderId], [MoldNo], [PartNo], [EarliestStartDate], [LatestEndDate]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderPartRowData_ProcessCheck]
    ON [Reporting].[WorkOrderPartRowData] ([ProcessCheckCode] ASC)
    INCLUDE ([SalesOrderId], [MoldNo], [PartNo]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderPartRowData_LatestEndDate]
    ON [Reporting].[WorkOrderPartRowData] ([LatestEndDate] ASC)
    INCLUDE ([SalesOrderId], [MoldNo], [PartNo], [PartStatusId])
    WHERE [LatestEndDate] IS NOT NULL;

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderPartRowData_PartType]
    ON [Reporting].[WorkOrderPartRowData] ([PartTypeCode] ASC)
    INCLUDE ([SalesOrderId], [MoldNo], [PartNo], [PartStatusId]);

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令零件報表寬表（PCM030 + 維度展平，僅含未完成訂單）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵 (IDENTITY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'RowId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件ID (PCM03_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'Id';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID (SAL04_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單編號 (JOB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID (PCM010.PCM01_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'MoldId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'MoldNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱 (PCM010.DIE_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'MoldName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號 (SUB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PartNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件名稱 (NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PartName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'圖號 (DWG_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'DrawingNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'版次 (VERSION)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'Version';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'Quantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工尺寸 (SPECF1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'MachiningSpec';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'素材尺寸 (SPECF2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'MaterialSpec';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'設計完成日 (DATE0)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'DesignCompletionDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'EBOM零件號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'EBomPartNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質ID (Production.MaterialType.MaterialId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'MaterialId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質名稱 (MTRL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'MaterialName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別ID (Production.PartType.Id)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PartTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別代碼 (Production.PartType.PartTypeCode)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PartTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別名稱 (TYPE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PartTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件群組ID (TYPE9)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PartGroupId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件群組名稱 (Production.PartGroup.PartGroupName)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PartGroupName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料來源ID (Production.SourceType.Id)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'SourceTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料來源代碼 (Production.SourceType.SourceTypeCode)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'SourceTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料來源名稱 (PURCH_YN)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'SourceTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'購料廠商ID (Purchasing.Vendor.VendorId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'VendorId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'購料廠商簡稱 (SUPPLIER)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'VendorName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'實際採購日 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PurchasedDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠內備品數量 (SPARE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'InternalSpareQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶備品數量 (SPARE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'CustomerSpareQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材料重量 KG (WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'MaterialWeight';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'估計材料費 (AMT_M)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'EstimatedMaterialCost';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否需加工 (TYPE_1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'IsNeedProcessing';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否外包 (TYPE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'IsOutsource';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否需進料檢 (QC_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'IsMaterialInspectionNeeded';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位ID (Production.Unit.UnitId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'UnitId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位名稱 (UNIT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'UnitName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'庫存料號ID (PART_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'InventoryItemId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'庫存料名稱 (Production.InventoryItem.InventoryItemName)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'InventoryItemName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'入庫數量 (QTY4)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'WarehouseQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製作原因ID (Production.ProductionReason.ProductionReasonId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'ProductionReasonId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製作原因名稱 (TYPE3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'ProductionReasonName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否為進度指標零件 (PART_INDEX)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'IsProcessingStepIndex';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否已完工 (OK_FLG)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'IsConfirmed';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件狀態ID (TYPE7)，X=已報廢', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PartStatusId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件狀態名稱 (Production.PartStatus.PartStatusName)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PartStatusName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報廢數量 (QTY3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'ScrapQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'結案日 (CLOSING)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'ClosureDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最早開工日 (DATE4)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'EarliestStartDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最遲完工日 (DATE5)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'LatestEndDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'上層零件號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'ParentPartNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'Remark';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'優先等級 (PRIORITY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'Priority';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生管人員ID (HumanResources.Employee.EmployeeId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生管人員姓名 (EMP_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程狀態代碼 (ACK): N=待確認 / A=製程已確認 / S=開工 / E=製程編輯中', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'ProcessCheckCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'ProcessCheckName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程確認時間 (ACK_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'ProcessCheckTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程變更記錄 (APPFILE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'ProcessChangeRecord';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'開工日 (來自 WIP020 最早 DATE_S)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'ProductionStartDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'圖檔路徑 (PCM030.ACAD)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'CadFile';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成本歸屬聯零件ID (PCM030.PCM03_NO 對應)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'CostAttributionPartId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成本歸屬聯零件號 (SUB_NO3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'CostAttributionPartNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成本歸屬聯零件名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'CostAttributionPartName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記 (DEL_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳 (TIMESTAMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件建檔日 (DATE7)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'CreatedDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新時間 (UTC)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderPartRowData', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/WorkOrderProcessRowData.sql ----------
CREATE TABLE [Reporting].[WorkOrderProcessRowData] (
    [RowId]                       BIGINT          IDENTITY (1, 1) NOT NULL,
    [ProcessId]                   NVARCHAR (10)   NOT NULL,
    [SalesOrderId]                NVARCHAR (10)   NULL,
    [SalesOrderNo]                NVARCHAR (10)   NULL,
    [Description]                 NVARCHAR (MAX)  NULL,
    [MoldId]                      NVARCHAR (10)   NULL,
    [MoldNo]                      NVARCHAR (20)   NULL,
    [MoldName]                    NVARCHAR (100)  NULL,
    [PartId]                      NVARCHAR (11)   NULL,
    [PartNo]                      NVARCHAR (20)   NULL,
    [PartName]                    NVARCHAR (50)   NULL,
    [ProcessSequence]             NVARCHAR (2)    NULL,
    [ProcessTypeId]               NVARCHAR (6)    NULL,
    [ProcessTypeName]             NVARCHAR (30)   NULL,
    [EstimatedTimeHr]             DECIMAL (18, 2) NULL,
    [PastAccumulatedTimeHr]       DECIMAL (18, 2) NULL,
    [EstRemainingTime]            DECIMAL (18, 2) NULL,
    [ScheduledStartDate]          DATETIME        NULL,
    [ScheduledCompleteDate]       DATETIME        NULL,
    [ActualStartDate]             DATETIME        NULL,
    [ActualCompleteDate]          DATETIME        NULL,
    [IsOutsourced]                BIT             CONSTRAINT [DF_WorkOrderProcessRowData_IsOutsourced] DEFAULT ((0)) NOT NULL,
    [EstimatedOutsourcingDays]    DECIMAL (8, 1)  NULL,
    [OutsourceVendorId]           NVARCHAR (15)   NULL,
    [OutsourceVendorName]         NVARCHAR (15)   NULL,
    [DefaultVendorId]             NVARCHAR (15)   NULL,
    [DefaultVendorName]           NVARCHAR (15)   NULL,
    [OutsourcedQuantity]          DECIMAL (5)     NULL,
    [MachineGroup]                NVARCHAR (10)   NULL,
    [PartQuantity]                DECIMAL (6)     NULL,
    [CompletedQuantity]           DECIMAL (6)     NULL,
    [EstimatedCost]               DECIMAL (9, 2)  NULL,
    [FitterCount]                 DECIMAL (10)    NULL,
    [IsAbnormalProcess]           BIT             CONSTRAINT [DF_WorkOrderProcessRowData_IsAbnormalProcess] DEFAULT ((0)) NOT NULL,
    [IsCompleted]                 BIT             CONSTRAINT [DF_WorkOrderProcessRowData_IsCompleted] DEFAULT ((0)) NOT NULL,
    [IsAssigned]                  BIT             CONSTRAINT [DF_WorkOrderProcessRowData_IsAssigned] DEFAULT ((0)) NOT NULL,
    [CompletionRate]              DECIMAL (5)     NULL,
    [ProcessStatusId]             NVARCHAR (1)    NULL,
    [ProcessStatusName]           NVARCHAR (50)   NULL,
    [AbnormalOrderNo]             NVARCHAR (10)   NULL,
    [MachineId]                   NVARCHAR (10)   NULL,
    [MachineName]                 NVARCHAR (30)   NULL,
    [WorkstationId]               INT             NULL,
    [RelationProcessTypeId]       NVARCHAR (10)   NULL,
    [IsDesignProcessType]         BIT             NULL,
    [RelationProcessId]           NVARCHAR (10)   NULL,
    [NextProcessId]               NVARCHAR (10)   NULL,
    [NextProcessTypeId]           NVARCHAR (6)    NULL,
    [NextProcessTypeName]         NVARCHAR (30)   NULL,
    [NextProcessSequence]         NVARCHAR (2)    NULL,
    [NextProcessStatusId]         NVARCHAR (1)    NULL,
    [DependentPartTotalCount]     INT             NULL,
    [DependentPartCompletedCount] INT             NULL,
    [IsArrived]                   BIT             CONSTRAINT [DF_WorkOrderProcessRowData_IsArrived] DEFAULT ((0)) NOT NULL,
    [ArrivalTime]                 DATETIME        NULL,
    [DependentPartId]             NVARCHAR (11)   NULL,
    [DependentPartNo]             NVARCHAR (20)   NULL,
    [DependentPartName]           NVARCHAR (50)   NULL,
    [Remark]                      NVARCHAR (100)  NULL,
    [ProcessingDescription]       NVARCHAR (MAX)  NULL,
    [LatestWorkMode]              NVARCHAR (1)    NULL,
    [LatestWorkerEmployeeId]      NVARCHAR (10)   NULL,
    [LatestWorkerEmployeeName]    NVARCHAR (50)   NULL,
    [LatestWorkStartedTime]       DATETIME        NULL,
    [LatestWorkPausedTime]        DATETIME        NULL,
    [LatestWorkCompletedTime]     DATETIME        NULL,
    [DeleteFlag]                  BIT             CONSTRAINT [DF_WorkOrderProcessRowData_DeleteFlag] DEFAULT ((0)) NOT NULL,
    [RecordTimestamp]             BINARY (8)      NULL,
    [CreatedDate]                 DATETIME        NULL,
    [LastModifiedTime]            DATETIME        NULL,
    [RefreshedAt]                 DATETIME2 (3)   CONSTRAINT [DF_WorkOrderProcessRowData_RefreshedAt] DEFAULT (sysutcdatetime()) NOT NULL,
    CONSTRAINT [PK_WorkOrderProcessRowData] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderProcessRowData_ProcessId]
    ON [Reporting].[WorkOrderProcessRowData] ([ProcessId] ASC);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderProcessRowData_Part_Sequence]
    ON [Reporting].[WorkOrderProcessRowData] ([PartId] ASC, [ProcessSequence] ASC)
    INCLUDE ([ProcessTypeId], [ProcessStatusId], [IsCompleted]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderProcessRowData_SalesOrder]
    ON [Reporting].[WorkOrderProcessRowData] ([SalesOrderId] ASC)
    INCLUDE ([PartId], [ProcessTypeId], [ProcessStatusId]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderProcessRowData_Mold]
    ON [Reporting].[WorkOrderProcessRowData] ([MoldId] ASC)
    INCLUDE ([PartId], [ProcessTypeId], [IsCompleted]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderProcessRowData_ProcessStatus]
    ON [Reporting].[WorkOrderProcessRowData] ([ProcessStatusId] ASC)
    INCLUDE ([SalesOrderId], [PartId], [ProcessTypeId]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderProcessRowData_ScheduledCompleteDate]
    ON [Reporting].[WorkOrderProcessRowData] ([ScheduledCompleteDate] ASC)
    INCLUDE ([SalesOrderId], [PartId], [ProcessTypeId], [IsCompleted])
    WHERE [ScheduledCompleteDate] IS NOT NULL;

GO
CREATE NONCLUSTERED INDEX [IX_WorkOrderProcessRowData_ProcessType]
    ON [Reporting].[WorkOrderProcessRowData] ([ProcessTypeId] ASC)
    INCLUDE ([SalesOrderId], [PartId], [IsCompleted]);

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令零件製程報表寬表（PSS022 + 維度展平，僅含未完成訂單）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵 (IDENTITY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'RowId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程ID (PSS02_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ProcessId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID (SAL04_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單編號 (JOB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'主要內容 (SAL041.REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'Description';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID (PCM010.PCM01_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'MoldId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'MoldNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱 (DIE_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'MoldName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件ID (PCM03_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'PartId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件編號 (PCM030.SUB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'PartNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件名稱 (PCM030.NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'PartName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程順序 (SR_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ProcessSequence';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別ID (MD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ProcessTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱 (PSS010.MD_NA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ProcessTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預估工時 (TIME1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'EstimatedTimeHr';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'過去累積時間 (TIME2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'PastAccumulatedTimeHr';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'均衡估計剩餘時間 (TIME1 - TIME2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'EstRemainingTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預計開始時間 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ScheduledStartDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預計完成時間 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ScheduledCompleteDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'實際開工時間 (DATE3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ActualStartDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'實際完工時間 (DATE4)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ActualCompleteDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否外包 (OUTSOURCE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'IsOutsourced';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預估外包天數 (DAYS，8h/天)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'EstimatedOutsourcingDays';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包廠商ID (PUR010.CUST_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'OutsourceVendorId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包廠商簡稱 (COMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'OutsourceVendorName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預設廠商ID (PUR010.CUST_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'DefaultVendorId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預設廠商簡稱 (SET_COMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'DefaultVendorName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包數量 (QTY3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'OutsourcedQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機器群組 (GROUP1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'MachineGroup';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'PartQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完成數量 (QTY2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'CompletedQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預估金額 (AMT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'EstimatedCost';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'鉗工人數 (ME_QTY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'FitterCount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否異常增加製程 (MD_TYPE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'IsAbnormalProcess';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否已完工 (OK_FLG)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'IsCompleted';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否已派工 (ASSIGN)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'IsAssigned';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完工率 (OK_RATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'CompletionRate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程狀態ID (STATUS)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ProcessStatusId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程狀態名稱 (Production.ProcessStatus.ProcessStatusName)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ProcessStatusName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'異常單號 (WIP05_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'AbnormalOrderNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台ID (PSS022.ME_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'MachineId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台名稱 (PSS050.DISCRIBE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'MachineName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽收工作站ID (Production.ProcessExt.WorkstationId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'WorkstationId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'關聯設計製程ID (Production.ProcessExt.RelationProcessTypeId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'RelationProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'設計工別關聯後置製程ID (PartExt.DependentProcessId，IsDesignProcessType=1 才填)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'RelationProcessId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'下一個製程ID (PSS022 self-join by PCM03_NO+SR_NO ASC)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'NextProcessId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'下一個製程的工別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'NextProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'下一個製程的工別名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'NextProcessTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'下一個製程順序 (SR_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'NextProcessSequence';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'下一個製程狀態 (STATUS)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'NextProcessStatusId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'相依零件總數 (PartExt aggregate by DependentProcessId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'DependentPartTotalCount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'相依零件完工數 (依 PCM030.OK_FLG=Y)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'DependentPartCompletedCount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否為設計製程 (Production.ProcessExt.IsDesignProcessType)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'IsDesignProcessType';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否已到站 (Production.ArrivedWorkpieceProcesses 判斷)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'IsArrived';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'到站時間 (Production.ProcessExt.ArrivalTime)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ArrivalTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'相依零件ID (Production.PartExt.DependentProcessId 反查)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'DependentPartId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'相依零件編號 (PCM030.SUB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'DependentPartNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'相依零件名稱 (PCM030.NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'DependentPartName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'Remark';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工說明 (REMARK1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'ProcessingDescription';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新一筆報工的 MODE (B=完工 / C=暫停 / A=開工中)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'LatestWorkMode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新一筆報工的報工人員ID (WIP020.EMP_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'LatestWorkerEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新一筆報工的報工人員姓名', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'LatestWorkerEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新一筆報工的開工時間（DATE_S+TIME_S，DATE_E IS NULL 時填）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'LatestWorkStartedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新一筆報工的暫停時間（DATE_E+TIME_E，MODE=C 時填）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'LatestWorkPausedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新一筆報工的完工時間（DATE_E+TIME_E，MODE=B 時填）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'LatestWorkCompletedTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記 (DEL_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳 (TIMESTAMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'建檔日期 (DATE5)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'CreatedDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新時間 (UTC)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkOrderProcessRowData', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/WorkRecordRowData.sql ----------
CREATE TABLE [Reporting].[WorkRecordRowData] (
    [RowId]                     BIGINT          IDENTITY (1, 1) NOT NULL,
    [WorkRecordId]              NVARCHAR (10)   NOT NULL,
    [SalesOrderId]              NVARCHAR (10)   NULL,
    [SalesOrderNo]              NVARCHAR (10)   NULL,
    [MoldId]                    NVARCHAR (10)   NULL,
    [MoldNo]                    NVARCHAR (20)   NULL,
    [MoldName]                  NVARCHAR (100)  NULL,
    [PartId]                    NVARCHAR (10)   NULL,
    [PartNo]                    NVARCHAR (20)   NULL,
    [PartName]                  NVARCHAR (50)   NULL,
    [ProcessId]                 NVARCHAR (10)   NULL,
    [ProcessSequence]           NVARCHAR (2)    NULL,
    [ProcessTypeId]             NVARCHAR (6)    NULL,
    [ProcessTypeName]           NVARCHAR (30)   NULL,
    [WorkStatusCode]            NVARCHAR (1)    NULL,
    [WorkStatusName]            NVARCHAR (10)   NULL,
    [ProcessStatusSnapshotCode] NVARCHAR (1)    NULL,
    [ProcessRateSnapshot]       DECIMAL (10, 2) NULL,
    [WorkReportSourceCode]      NVARCHAR (10)   NULL,
    [WorkReportTypeCode]        NVARCHAR (1)    NULL,
    [ShiftCode]                 NVARCHAR (1)    NULL,
    [IsMainJob]                 BIT             CONSTRAINT [DF_WorkRecordRowData_IsMainJob] DEFAULT ((0)) NOT NULL,
    [WorkStartTime]             DATETIME        NULL,
    [WorkEndTime]               DATETIME        NULL,
    [SystemStartTime]           DATETIME        NULL,
    [SystemEndTime]             DATETIME        NULL,
    [PlannedEndDate]            DATETIME        NULL,
    [ElapsedHours]              DECIMAL (8, 2)  NULL,
    [MachineOccupiedHours]      DECIMAL (8, 2)  NULL,
    [ManualEffectiveHours]      DECIMAL (8, 2)  NULL,
    [MachineNetworkHours]       DECIMAL (8, 2)  NULL,
    [AdjustedHours]             DECIMAL (9, 1)  NULL,
    [TimeWeight]                DECIMAL (8, 2)  NULL,
    [CompletedQuantity]         DECIMAL (8)     NULL,
    [CompletionRate]            DECIMAL (5)     NULL,
    [TotalWeight]               DECIMAL (10, 2) NULL,
    [QualityStatusCode]         NVARCHAR (1)    NULL,
    [QualityStatusName]         NVARCHAR (10)   NULL,
    [QcGoodQuantity]            DECIMAL (8)     NULL,
    [QcDefectQuantity]          DECIMAL (8)     NULL,
    [QcReviewQuantity]          DECIMAL (8)     NULL,
    [QcRemark]                  NVARCHAR (MAX)  NULL,
    [WorkerEmployeeId]          NVARCHAR (10)   NULL,
    [WorkerEmployeeName]        NVARCHAR (50)   NULL,
    [CoWorkerEmployeeIds]       NVARCHAR (20)   NULL,
    [MachineId]                 NVARCHAR (10)   NULL,
    [MachineName]               NVARCHAR (30)   NULL,
    [ProcessingRate]            DECIMAL (20, 1) NULL,
    [ApproverEmployeeId]        NVARCHAR (10)   NULL,
    [ApproverEmployeeName]      NVARCHAR (50)   NULL,
    [ApprovedTime]              DATETIME        NULL,
    [IsMachineTimeComputed]     BIT             CONSTRAINT [DF_WorkRecordRowData_IsMachineTimeComputed] DEFAULT ((0)) NOT NULL,
    [IsMachineTimeAccumulated]  BIT             CONSTRAINT [DF_WorkRecordRowData_IsMachineTimeAccumulated] DEFAULT ((0)) NOT NULL,
    [RepairReasonCode]          NVARCHAR (30)   NULL,
    [Remark]                    NVARCHAR (MAX)  NULL,
    [DeleteFlag]                BIT             CONSTRAINT [DF_WorkRecordRowData_DeleteFlag] DEFAULT ((0)) NOT NULL,
    [RecordTimestamp]           BINARY (8)      NULL,
    [LastModifiedTime]          DATETIME        NULL,
    [RefreshedAt]               DATETIME2 (3)   CONSTRAINT [DF_WorkRecordRowData_RefreshedAt] DEFAULT (sysutcdatetime()) NOT NULL,
    CONSTRAINT [PK_WorkRecordRowData] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_WorkRecordRowData_WorkRecordId]
    ON [Reporting].[WorkRecordRowData] ([WorkRecordId] ASC);

GO
CREATE NONCLUSTERED INDEX [IX_WorkRecordRowData_Process]
    ON [Reporting].[WorkRecordRowData] ([ProcessId] ASC, [WorkStartTime] ASC)
    INCLUDE ([WorkStatusCode], [CompletedQuantity]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkRecordRowData_SalesOrder]
    ON [Reporting].[WorkRecordRowData] ([SalesOrderId] ASC)
    INCLUDE ([PartId], [ProcessId], [WorkStatusCode]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkRecordRowData_Mold]
    ON [Reporting].[WorkRecordRowData] ([MoldId] ASC)
    INCLUDE ([PartId], [ProcessId], [WorkStatusCode]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkRecordRowData_Worker_Date]
    ON [Reporting].[WorkRecordRowData] ([WorkerEmployeeId] ASC, [WorkStartTime] DESC)
    INCLUDE ([ManualEffectiveHours], [CompletedQuantity]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkRecordRowData_Machine_Date]
    ON [Reporting].[WorkRecordRowData] ([MachineId] ASC, [WorkStartTime] DESC)
    INCLUDE ([MachineOccupiedHours], [MachineNetworkHours]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkRecordRowData_WorkStatus]
    ON [Reporting].[WorkRecordRowData] ([WorkStatusCode] ASC)
    INCLUDE ([SalesOrderId], [ProcessId], [WorkStartTime]);

GO
CREATE NONCLUSTERED INDEX [IX_WorkRecordRowData_WorkStartTime]
    ON [Reporting].[WorkRecordRowData] ([WorkStartTime] DESC)
    INCLUDE ([WorkerEmployeeId], [MachineId], [ManualEffectiveHours])
    WHERE [WorkStartTime] IS NOT NULL;

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工記錄報表寬表（WIP020 + 維度展平，僅含未完成訂單）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵 (IDENTITY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'RowId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工ID (WIP02_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'WorkRecordId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID (SAL04_NO，由 JOB_NO=ORDER_NO 反查 SAL041)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單編號 (JOB_NO，對應 SAL041.ORDER_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID (PCM010.PCM01_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'MoldId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'MoldNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱 (DIE_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'MoldName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件ID (PCM03_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'PartId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件編號 (SUB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'PartNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件名稱 (PCM030.NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'PartName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程ID (PSS02_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ProcessId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程順序 (SR_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ProcessSequence';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別ID (MD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ProcessTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱 (PSS010.MD_NA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ProcessTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工狀態代碼 (MODE): A=開工中 / B=完工 / C=暫停', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'WorkStatusCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'WorkStatusName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程狀態快照 (PR_STATUS): 報工當下 PSS022 狀態，A=開工/X=取消/P=暫停/R=準備/Y=完工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ProcessStatusSnapshotCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程合格率快照 (PR_RATE): 報工當下 PSS022.OK_RATE', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ProcessRateSnapshot';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工來源 (APP_NO): WIP020=單工 / WIP025=多工件 / WIP027=補報工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'WorkReportSourceCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工類型代碼 (MODE1，對應 WIP391)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'WorkReportTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'班別代碼 (TYP1): 日/夜班/加班班', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ShiftCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否為主報工 (MAIN_JOB): 多人協作時主要報工人員', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'IsMainJob';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工開始時間 (DATE_S + TIME_S 合併)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'WorkStartTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工結束時間 (DATE_E + TIME_E 合併)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'WorkEndTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'系統記錄開工時間 (R_START): 補報工識別用', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'SystemStartTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'系統記錄停工時間 (R_END): NULL 表示非 Web 報工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'SystemEndTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預計結束日 (P_DATE_E)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'PlannedEndDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'總經過時間 (TIMES) = WorkEndTime - WorkStartTime 牆鐘時長 (小時)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ElapsedHours';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台佔用工時 (TIME2) × T_WEIGHT，計成本用', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'MachineOccupiedHours';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'人工有效工時 (TIME3) × T_WEIGHT，計薪資用', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ManualEffectiveHours';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機聯網機台工時 (TIME_MA) × T_WEIGHT: PLC 信號實際加工時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'MachineNetworkHours';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'調整工時 (TIME2B): 加班/特殊工時 (用途待業務確認)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'AdjustedHours';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'多工件工時權重 (T_WEIGHT): 單工件=1.0，多工件併加工時依比例分配', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'TimeWeight';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完成數量 (QTY2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'CompletedQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完成率 (RATE): 暫停=當段%；完工=100', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'CompletionRate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'總重量 KG (T_WEIGHT 同欄但業務語意為重量時)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'TotalWeight';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品檢狀態代碼 (QC_MARK): V=良品 / X=不良 / 空=不適用', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'QualityStatusCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品檢狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'QualityStatusName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品檢良品數 (QC_QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'QcGoodQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品檢不良數 (QC_QTY2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'QcDefectQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品檢備查數 (QC_QTY3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'QcReviewQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品檢備註 (QCREMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'QcRemark';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工人員ID (EMP_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'WorkerEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工人員姓名 (HumanResources.Employee.EmployeeName)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'WorkerEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'協作人員ID列表 (EMP_NO2): 自由格式字串，未規範分隔符', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'CoWorkerEmployeeIds';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台ID (ME_NO，對應 PSS050)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'MachineId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台名稱 (PSS050.DISCRIBE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'MachineName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工費率：優先取 PSS055 當月 (YYMM=WorkStartTime 月份)，無則 fallback PSS050.AMT1', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ProcessingRate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核人員ID (APPROVE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ApproverEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核人員姓名 (HumanResources.Employee.EmployeeName)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ApproverEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核時間 (D_APPROVE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'ApprovedTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台工時已計算 (HAS_TMA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'IsMachineTimeComputed';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台工時已累加 (MA_ADDED)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'IsMachineTimeAccumulated';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'重工原因代碼 (REWORK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'RepairReasonCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工備註 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'Remark';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記 (DEL_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳 (TIMESTAMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新時間 (UTC)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'WorkRecordRowData', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/MoldRowData.sql ----------
CREATE TABLE [Reporting].[MoldRowData] (
    -- 寬表代理主鍵
    [RowId]                             BIGINT IDENTITY (1, 1) NOT NULL,

    -- 模具 (主屬性)
    [MoldId]                            NVARCHAR (10)     NOT NULL,
    [MoldNo]                            NVARCHAR (20)     NULL,
    [MoldName]                          NVARCHAR (60)     NULL,
    [InternalMoldName]                  NVARCHAR (60)     NULL,
    [ProductType]                       NVARCHAR (20)     NULL,
    [ModelNumber]                       NVARCHAR (15)     NULL,
    [ProductId]                         NVARCHAR (20)     NULL,
    [MoldSourceTypeId]                  NVARCHAR (1)      NULL,
    [MoldSourceTypeName]                NVARCHAR (10)     NULL,
    [PhotoPath]                         NVARCHAR (100)    NULL,
    [CustomVersion]                     NVARCHAR (3)      NULL,

    -- 時間
    [MoldDate]                          DATETIME          NULL,
    [MassProductionDate]                DATETIME          NULL,
    [T1TrialDate]                       DATETIME          NULL,
    [TrialDate]                         DATETIME          NULL,
    [ScrapDate]                         DATETIME          NULL,

    -- 客戶
    [CustomerId]                        NVARCHAR (15)     NULL,
    [CustomerSubname]                   NVARCHAR (100)    NULL,

    -- 人員
    [DesignerEmployeeId]                NVARCHAR (10)     NULL,
    [DesignerEmployeeName]              NVARCHAR (50)     NULL,
    [AssemblerEmployeeId]               NVARCHAR (10)     NULL,
    [AssemblerEmployeeName]             NVARCHAR (50)     NULL,
    [MoldingOperatorEmployeeId]         NVARCHAR (10)     NULL,
    [MoldingOperatorEmployeeName]       NVARCHAR (16)     NULL,
    [PlannerEmployeeId]                 NVARCHAR (10)     NULL,
    [PlannerEmployeeName]               NVARCHAR (50)     NULL,

    -- 規格 / 機台
    [MachineMinTon]                     DECIMAL (18, 2)   NULL,
    [MachineMaxTon]                     DECIMAL (18, 2)   NULL,
    [CavityCount]                       NVARCHAR (10)     NULL,
    [MoldWeight]                        DECIMAL (20, 2)   NULL,
    [ShrinkageRateX]                    NVARCHAR (10)     NULL,
    [AverageThickness]                  DECIMAL (9, 0)    NULL,

    -- 材質
    [FixedCoreInsertMaterialId]         NVARCHAR (10)     NULL,
    [FixedCoreInsertMaterialName]       NVARCHAR (15)     NULL,
    [MovableCoreInsertMaterialId]       NVARCHAR (10)     NULL,
    [MovableCoreInsertMaterialName]     NVARCHAR (15)     NULL,
    [MoldBaseMaterialId]                NVARCHAR (10)     NULL,
    [MoldBaseMaterialName]              NVARCHAR (15)     NULL,
    [MoldBaseHardness]                  NVARCHAR (12)     NULL,
    [ProductMaterialId]                 NVARCHAR (10)     NULL,
    [ProductMaterialName]               NVARCHAR (10)     NULL,

    -- 備註 / 擴充
    [ProductNotes]                      NVARCHAR (MAX)    NULL,
    [IsBomRequired]                     BIT               NULL,

    -- 計算欄位
    [IsUnassigned]                      BIT               CONSTRAINT [DF_MoldRowData_IsUnassigned]      DEFAULT ((1)) NOT NULL,
    [IsOrderIncomplete]                 BIT               CONSTRAINT [DF_MoldRowData_IsOrderIncomplete] DEFAULT ((0)) NOT NULL,

    -- 通用
    [DeleteFlag]                        BIT               CONSTRAINT [DF_MoldRowData_DeleteFlag] DEFAULT ((0)) NOT NULL,
    [RecordTimestamp]                   BINARY (8)        NULL,
    [LastModifiedTime]                  DATETIME          NULL,

    -- 刷新中繼資料
    [RefreshedAt]                       DATETIME2 (3)     CONSTRAINT [DF_MoldRowData_RefreshedAt] DEFAULT (SYSUTCDATETIME()) NOT NULL,

    CONSTRAINT [PK_MoldRowData] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_MoldRowData_MoldId]
    ON [Reporting].[MoldRowData] ([MoldId] ASC);

GO
CREATE NONCLUSTERED INDEX [IX_MoldRowData_MoldNo]
    ON [Reporting].[MoldRowData] ([MoldNo] ASC)
    INCLUDE ([MoldName], [CustomerId], [MoldSourceTypeId]);

GO
CREATE NONCLUSTERED INDEX [IX_MoldRowData_Customer]
    ON [Reporting].[MoldRowData] ([CustomerId] ASC)
    INCLUDE ([MoldNo], [MoldName], [IsOrderIncomplete]);

GO
CREATE NONCLUSTERED INDEX [IX_MoldRowData_OrderStatus]
    ON [Reporting].[MoldRowData] ([IsUnassigned] ASC, [IsOrderIncomplete] ASC)
    INCLUDE ([MoldNo], [CustomerId]);

GO
CREATE NONCLUSTERED INDEX [IX_MoldRowData_MoldDate]
    ON [Reporting].[MoldRowData] ([MoldDate] DESC)
    INCLUDE ([MoldNo], [CustomerId])
    WHERE [MoldDate] IS NOT NULL;

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具報表寬表（PCM010 + 維度展平，全量模具）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵 (IDENTITY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'RowId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID (PCM01_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱 (DIE_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠內模名 (YM_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'InternalMoldName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品類型 (DIETYPE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'ProductType';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機種 (MODEL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'ModelNumber';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成品編號 (PROD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'ProductId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具來源ID (DIE_SOURCE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldSourceTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具來源名稱 (Production.MoldSourceType.MoldSourceTypeName)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldSourceTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'圖檔位置 (PHOTO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'PhotoPath';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'自訂版本號 (EDITION)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'CustomVersion';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'開模日期 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'量產日期 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MassProductionDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'T1 試模日期 (T1_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'T1TrialDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Tn 試模日期 (T_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'TrialDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報廢日期 (POOP_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'ScrapDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶ID (CUST_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'CustomerId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶簡稱 (SAL010.SUBNAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'CustomerSubname';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'設計人員ID (HumanResources.Employee.EmployeeId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'DesignerEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'設計人員姓名 (DESIGNER)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'DesignerEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'組立人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'AssemblerEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'組立人員姓名 (NAME2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'AssemblerEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成型人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldingOperatorEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成型人員姓名 (BROKER)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldingOperatorEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生技人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生技人員姓名 (NAME3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機器噸數起 (TON，CHAR 轉 DECIMAL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MachineMinTon';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機器噸數迄 (TON2，CHAR 轉 DECIMAL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MachineMaxTon';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模穴數 (C_CAV)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'CavityCount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具重量 KG (WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldWeight';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'縮水率 % (SHRINK_X)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'ShrinkageRateX';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'平均肉厚 (AMT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'AverageThickness';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模仁固定材質ID (Production.MaterialType.MaterialId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'FixedCoreInsertMaterialId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模仁固定材質名稱 (INSERT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'FixedCoreInsertMaterialName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模仁移動材質ID (Production.MaterialType.MaterialId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MovableCoreInsertMaterialId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模仁移動材質名稱 (INSERT2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MovableCoreInsertMaterialName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模座材質ID (Production.MaterialType.MaterialId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldBaseMaterialId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模座材質名稱 (BASE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldBaseMaterialName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模座硬度 (BASE_HD)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'MoldBaseHardness';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品材質ID (Production.MaterialType.MaterialId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'ProductMaterialId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品材質名稱 (PROD_MTRL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'ProductMaterialName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成品備註 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'ProductNotes';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否需要 BOM (Design.MoldExt.IsBomRequired)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'IsBomRequired';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'未分配訂單: 此模具尚無訂單引用', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'IsUnassigned';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單未完成: 此模具至少有一筆 SAL041.OK_FLG IN (空, T) 的建立中/試模訂單', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'IsOrderIncomplete';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記 (DEL_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳 (TIMESTAMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新時間 (UTC)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldRowData', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/MoldPartRowData.sql ----------
CREATE TABLE [Reporting].[MoldPartRowData] (
    -- 寬表代理主鍵
    [RowId]                             BIGINT IDENTITY (1, 1) NOT NULL,

    -- 主鍵 / 模具關聯
    [MoldPartId]                        NVARCHAR (10)     NOT NULL,
    [MoldId]                            NVARCHAR (10)     NULL,

    -- 零件 (畫面欄位)
    [PartName]                          NVARCHAR (40)     NULL,
    [PartNameEn]                        NVARCHAR (50)     NULL,
    [PartNo]                            NVARCHAR (20)     NULL,
    [DrawingNo]                         NVARCHAR (30)     NULL,
    [CustomVersion]                     NVARCHAR (5)      NULL,

    -- 類別
    [PartTypeId]                        UNIQUEIDENTIFIER  NULL,
    [PartTypeCode]                      NVARCHAR (10)     NULL,
    [PartTypeName]                      NVARCHAR (10)     NULL,
    [IsNeedProcessing]                  BIT               CONSTRAINT [DF_MoldPartRowData_IsNeedProcessing] DEFAULT ((0)) NOT NULL,

    -- 製作原因
    [ProductionReasonId]                NVARCHAR (1)      NULL,
    [ProductionReasonName]              NVARCHAR (20)     NULL,

    -- 規格 / 群組
    [MachiningSpec]                     NVARCHAR (80)     NULL,
    [PartGroupId]                       NVARCHAR (20)     NULL,
    [PartGroupName]                     NVARCHAR (20)     NULL,
    [MaterialSpec]                      NVARCHAR (80)     NULL,

    -- 來源 / 材質
    [SourceTypeId]                      UNIQUEIDENTIFIER  NULL,
    [SourceTypeCode]                    NVARCHAR (1)      NULL,
    [SourceTypeName]                    NVARCHAR (10)     NULL,
    [MaterialId]                        NVARCHAR (10)     NULL,
    [MaterialName]                      NVARCHAR (15)     NULL,

    -- CAD / 領料 / 備註
    [CadFile]                           NVARCHAR (100)    NULL,
    [InventoryItemId]                   NVARCHAR (20)     NULL,
    [Remark]                            NVARCHAR (80)     NULL,

    -- 數量 / 重量 / 備品
    [Quantity]                          DECIMAL (20, 0)   NULL,
    [MaterialWeight]                    DECIMAL (20, 2)   NULL,
    [CustomerSpareQuantity]             DECIMAL (20, 0)   NULL,
    [InternalSpareQuantity]             DECIMAL (20, 0)   NULL,

    -- 檢驗 / 確認
    [IsMaterialInspectionNeeded]        BIT               CONSTRAINT [DF_MoldPartRowData_IsMaterialInspectionNeeded] DEFAULT ((0)) NOT NULL,
    [IsCadChecked]                      BIT               CONSTRAINT [DF_MoldPartRowData_IsCadChecked]                DEFAULT ((0)) NOT NULL,

    -- 時間
    [CreatedDate]                       DATETIME          NULL,
    [PurchasedDate]                     DATETIME          NULL,

    -- 優先 / 熱處理
    [Priority]                          NVARCHAR (3)      NULL,
    [HeatTreatmentHardness]             NVARCHAR (10)     NULL,

    -- 廠商
    [VendorId]                          NVARCHAR (15)     NULL,
    [VendorName]                        NVARCHAR (15)     NULL,

    -- 編修
    [LastModifiedEmployeeId]            NVARCHAR (10)     NULL,
    [LastModifiedEmployeeName]          NVARCHAR (12)     NULL,
    [ModifiedDate]                      DATETIME          NULL,

    -- 通用
    [DeleteFlag]                        BIT               CONSTRAINT [DF_MoldPartRowData_DeleteFlag] DEFAULT ((0)) NOT NULL,
    [RecordTimestamp]                   BINARY (8)        NULL,
    [LastModifiedTime]                  DATETIME          NULL,

    -- 刷新中繼資料
    [RefreshedAt]                       DATETIME2 (3)     CONSTRAINT [DF_MoldPartRowData_RefreshedAt] DEFAULT (SYSUTCDATETIME()) NOT NULL,

    CONSTRAINT [PK_MoldPartRowData] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_MoldPartRowData_MoldPartId]
    ON [Reporting].[MoldPartRowData] ([MoldPartId] ASC);

GO
CREATE NONCLUSTERED INDEX [IX_MoldPartRowData_Mold]
    ON [Reporting].[MoldPartRowData] ([MoldId] ASC, [PartNo] ASC)
    INCLUDE ([PartName], [MaterialName]);

GO
CREATE NONCLUSTERED INDEX [IX_MoldPartRowData_PartNo]
    ON [Reporting].[MoldPartRowData] ([PartNo] ASC)
    WHERE [PartNo] IS NOT NULL;

GO
CREATE NONCLUSTERED INDEX [IX_MoldPartRowData_PartType]
    ON [Reporting].[MoldPartRowData] ([PartTypeCode] ASC)
    INCLUDE ([MoldId], [PartNo]);

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具零件報表寬表（PCM020 + 維度展平，依 PCM010E 畫面欄位）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵 (IDENTITY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'RowId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具零件ID (PCM02_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'MoldPartId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID (PCM01_NO，PCM010 隱含 FK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'MoldId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品名 (NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'PartName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'英文品名 (ENG_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'PartNameEn';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號 (SUB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'PartNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'圖號 (DWG_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'DrawingNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'自訂版本 (EDITION)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'CustomVersion';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'類別ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'PartTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'類別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'PartTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'類別 (TYPE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'PartTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'需加工 (TYPE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'IsNeedProcessing';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製作原因ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'ProductionReasonId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製作原因 (TYPE3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'ProductionReasonName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工尺寸 (SPECF1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'MachiningSpec';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件群組ID (TYPE9)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'PartGroupId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件群組名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'PartGroupName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'素材尺寸 (SPECF2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'MaterialSpec';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料來源ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'SourceTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料來源代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'SourceTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源 (PURCH_YN)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'SourceTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'MaterialId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質 (MTRL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'MaterialName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'CAD檔名 (ACAD)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'CadFile';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'領用料號 (PART_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'InventoryItemId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'Remark';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'Quantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'素材重量 (WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'MaterialWeight';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶備品 (SPARE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'CustomerSpareQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠內備品 (SPARE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'InternalSpareQuantity';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'QC_MARK 進料檢驗', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'IsMaterialInspectionNeeded';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'資料確認 (CAD_CHK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'IsCadChecked';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'建檔日期 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'CreatedDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'採購日期 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'PurchasedDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'優先等級 (PRIORITY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'Priority';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理硬度 (HARDNESS)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'HeatTreatmentHardness';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'VendorId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商名稱 (SUPPLIER)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'VendorName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'資料編修人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'資料編修 (MOD_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'編修日期 (MOD_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'ModifiedDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記 (DEL_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳 (TIMESTAMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後更新時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刷新時間 (UTC)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartRowData', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/PurchaseReceiveRowData.sql ----------
CREATE TABLE [Reporting].[PurchaseReceiveRowData] (
    [RowId]                     BIGINT          IDENTITY (1, 1) NOT NULL,
    [PurchaseReceiveItemId]     NVARCHAR (10)   NOT NULL,
    [PurchaseReceiveId]         NVARCHAR (10)   NULL,
    [ReceiveNo]                 NVARCHAR (12)   NULL,
    [PurchaseOrderItemId]       NVARCHAR (10)   NULL,
    [LineItemNo]                NVARCHAR (4)    NULL,
    [ReceiveDate]               DATETIME        NULL,
    [DeliveryNo]                NVARCHAR (20)   NULL,
    [AccountingMonth]           NVARCHAR (6)    NULL,
    [CurrencyCode]              NVARCHAR (3)    NULL,
    [ExchangeRate]              DECIMAL (10, 4) NULL,
    [InvoiceNo]                 NVARCHAR (10)   NULL,
    [HeaderSubtotal]            DECIMAL (20, 2) NULL,
    [HeaderTax]                 DECIMAL (20, 2) NULL,
    [HeaderTotalAmount]         DECIMAL (20, 2) NULL,
    [TaxRate]                   DECIMAL (10, 1) NULL,
    [ReceiverName]              NVARCHAR (10)   NULL,
    [ApproverEmployeeId]        NVARCHAR (10)   NULL,
    [ApprovedTime]              DATETIME        NULL,
    [VendorRawId]               NVARCHAR (15)   NULL,
    [VendorId]                  NVARCHAR (15)   NULL,
    [VendorName]                NVARCHAR (50)   NULL,
    [SalesOrderNo]              NVARCHAR (10)   NULL,
    [SalesOrderId]              NVARCHAR (10)   NULL,
    [MoldNo]                    NVARCHAR (20)   NULL,
    [MoldId]                    NVARCHAR (10)   NULL,
    [MoldName]                  NVARCHAR (100)  NULL,
    [InventoryItemId]           NVARCHAR (20)   NULL,
    [PartName]                  NVARCHAR (50)   NULL,
    [Spec]                      NVARCHAR (80)   NULL,
    [Material]                  NVARCHAR (15)   NULL,
    [Unit]                      NVARCHAR (5)    NULL,
    [Weight]                    NVARCHAR (8)    NULL,
    [Quantity]                  DECIMAL (20, 2) NULL,
    [UnitPrice]                 DECIMAL (20, 4) NULL,
    [Amount]                    DECIMAL (20, 2) NULL,
    [ProcessingFee]             DECIMAL (20, 2) NULL,
    [DiscountPercent]           DECIMAL (9)     NULL,
    [IsFree]                    BIT             CONSTRAINT [DF_PurchaseReceiveRowData_IsFree] DEFAULT ((0)) NOT NULL,
    [PurchaseReason]            NVARCHAR (100)  NULL,
    [Remark]                    NVARCHAR (100)  NULL,
    [DeliveryStatusCode]        NVARCHAR (1)    NULL,
    [DeliveryStatusName]        NVARCHAR (10)   NULL,
    [QualityStatusCode]         NVARCHAR (1)    NULL,
    [QualityStatusName]         NVARCHAR (10)   NULL,
    [HasQcReport]               NVARCHAR (1)    NULL,
    [IsClosed]                  NVARCHAR (1)    NULL,
    [AccountSubject]            NVARCHAR (10)   NULL,
    [IncomingQcCode]            NVARCHAR (1)    NULL,
    [InspectionCheckedCode]     NVARCHAR (1)    NULL,
    [DeliveryConfirmedCode]     NVARCHAR (1)    NULL,
    [QualityConfirmedCode]      NVARCHAR (1)    NULL,
    [InspectionDate]            DATETIME        NULL,
    [AcceptanceDate]            DATETIME        NULL,
    [InspectorEmployeeId]       NVARCHAR (10)   NULL,
    [QualifiedQuantity]         DECIMAL (12, 2) NULL,
    [SpecialAcceptanceQuantity] DECIMAL (12, 2) NULL,
    [NgQuantity]                DECIMAL (12, 1) NULL,
    [StockedQuantity]           DECIMAL (12, 1) NULL,
    [Quantity3]                 DECIMAL (11, 2) NULL,
    [Quantity5]                 DECIMAL (11, 2) NULL,
    [PickedDate]                DATETIME        NULL,
    [PickerEmployeeId]          NVARCHAR (10)   NULL,
    [PickerEmployeeName]        NVARCHAR (12)   NULL,
    [WorkOrderItemNo]           NVARCHAR (10)   NULL,
    [LastModifiedEmployeeName]  NVARCHAR (12)   NULL,
    [ModifiedDate]              DATETIME        NULL,
    [DeleteFlag]                BIT             CONSTRAINT [DF_PurchaseReceiveRowData_DeleteFlag] DEFAULT ((0)) NOT NULL,
    [RecordTimestamp]           BINARY (8)      NULL,
    [LastModifiedTime]          DATETIME        NULL,
    [RefreshedAt]               DATETIME2 (3)   CONSTRAINT [DF_PurchaseReceiveRowData_RefreshedAt] DEFAULT (sysutcdatetime()) NOT NULL,
    CONSTRAINT [PK_PurchaseReceiveRowData] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_PurchaseReceiveRowData_Item] ON [Reporting].[PurchaseReceiveRowData] ([PurchaseReceiveItemId]);
GO
CREATE NONCLUSTERED INDEX [IX_PurchaseReceiveRowData_Receive] ON [Reporting].[PurchaseReceiveRowData] ([PurchaseReceiveId]);
GO
CREATE NONCLUSTERED INDEX [IX_PurchaseReceiveRowData_Mold] ON [Reporting].[PurchaseReceiveRowData] ([MoldNo]);
GO
CREATE NONCLUSTERED INDEX [IX_PurchaseReceiveRowData_SalesOrder_Part] ON [Reporting].[PurchaseReceiveRowData] ([SalesOrderNo], [InventoryItemId]);
GO
CREATE NONCLUSTERED INDEX [IX_PurchaseReceiveRowData_Vendor] ON [Reporting].[PurchaseReceiveRowData] ([VendorId]);
GO
CREATE NONCLUSTERED INDEX [IX_PurchaseReceiveRowData_ReceiveDate] ON [Reporting].[PurchaseReceiveRowData] ([ReceiveDate] DESC);
GO

-- 表級描述
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'採購收料寬表（MTR021+MTR022 展平，料費 base）— PUR030 採購收料作業', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData';
-- 欄位描述
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'RowId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'明細 PK (MTR02_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'PurchaseReceiveItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料單 PK (MTR02_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'PurchaseReceiveId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料編號 (MTR021.NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'ReceiveNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源 PUR022 明細 (PUR02_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'PurchaseOrderItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'項次 (ITEM_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'LineItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料日期 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'ReceiveDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'送貨單號 (DLV_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'帳款月份 (YM)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'AccountingMonth';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'幣別 (BIL_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'CurrencyCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'匯率 (EXCHANGE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'ExchangeRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'發票號碼 (INVOICE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'InvoiceNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'表頭小計 (MTR021.AMT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeaderSubtotal';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'表頭營業稅 (MTR021.TAX)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeaderTax';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'含稅總額 (MTR021.AMT2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeaderTotalAmount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'增值稅率 (R_TAX)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'TaxRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料人姓名 (MTR021.QC，含工號如「楊惠萍 #309」)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'ReceiverName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核人員ID (APPROVE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'ApproverEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核時間 (APPRO_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'ApprovedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商編號原始值 (CUST_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'VendorRawId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'VendorId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'VendorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令號 (JOB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID (SAL04_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料編號 (PART_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'InventoryItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品名 (NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'規格 (SPECF)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'Spec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質 (MTRL，free text)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'Material';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位 (UNIT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'Unit';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'重量 (WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'Weight';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'Quantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單價 (AMT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'UnitPrice';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'金額 (AMT2) — 料費 base', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'Amount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工費 (AMT_HR)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessingFee';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'折數 (DISCOUNT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'DiscountPercent';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'免費 (AMT_N)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'IsFree';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'採購原因 (MISTAKE，多用途：一般存採購原因文字；旗標 ''退貨'' 表退回廠商不可刪除；東易客戶會被覆寫成 PUR_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'PurchaseReason';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註 (QC_REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期狀態 (S_DELIVER): Y=合格如期 / N=逾期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質狀態 (S_QUALITY): Y=合格 / A=特採 / N=不合格', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'QualityStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'QualityStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'附報告 (REPORT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'HasQcReport';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'結案 (OK_FLG)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'IsClosed';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'會計科目 (ACC_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'AccountSubject';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'進料檢驗 (QC_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'IncomingQcCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'檢驗確認 (CHK_YN)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'InspectionCheckedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'交期確認 (D_CHK1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質確認 (Q_CHK1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'QualityConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'驗收日 (DAT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'InspectionDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'驗收完成日 (DAT2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'AcceptanceDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'檢驗人員ID (EMP1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'InspectorEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'合格數量 (STOR1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'QualifiedQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'特採數量 (STOR2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'SpecialAcceptanceQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'NG 數量 (NG_QTY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'NgQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'入庫數量 (SP_QTY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'StockedQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 3 (QTY3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'Quantity3';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 5 (QTY5)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'Quantity5';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'領料日 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'PickedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'領料人ID (EMP2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'PickerEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'經手人姓名 (EMP_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'PickerEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令連線單號 (WIP05_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'WorkOrderItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'編修人員姓名 (MOD_NAME，含工號)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'編修日期 (MOD_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'ModifiedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳 (TIMESTAMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表刷新時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'PurchaseReceiveRowData', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/OutsourceReceiveRowData.sql ----------
CREATE TABLE [Reporting].[OutsourceReceiveRowData] (
    [RowId]                     BIGINT          IDENTITY (1, 1) NOT NULL,
    [OutsourceReceiveItemId]    NVARCHAR (12)   NOT NULL,
    [OutsourceReceiveId]        NVARCHAR (10)   NULL,
    [ReceiveNo]                 NVARCHAR (10)   NULL,
    [OutsourceOrderItemId]      NVARCHAR (12)   NULL,
    [LineItemNo]                NVARCHAR (4)    NULL,
    [ReceiveDate]               DATETIME        NULL,
    [DeliveryNo]                NVARCHAR (20)   NULL,
    [DeliveryDate]              DATETIME        NULL,
    [AccountingMonth]           NVARCHAR (6)    NULL,
    [CurrencyCode]              NVARCHAR (3)    NULL,
    [ExchangeRate]              DECIMAL (12, 4) NULL,
    [InvoiceNo]                 NVARCHAR (10)   NULL,
    [HeaderTax]                 DECIMAL (11, 2) NULL,
    [HeaderSubtotal]            DECIMAL (20, 2) NULL,
    [HeaderTotalAmount]         DECIMAL (20, 2) NULL,
    [TaxRate]                   DECIMAL (10, 1) NULL,
    [ReceiverName]              NVARCHAR (50)   NULL,
    [OutsourceCategoryName]     NVARCHAR (10)   NULL,
    [PrintedTime]               DATETIME        NULL,
    [ApproverEmployeeId]        NVARCHAR (10)   NULL,
    [ApprovedTime]              DATETIME        NULL,
    [VendorRawId]               NVARCHAR (15)   NULL,
    [VendorId]                  NVARCHAR (15)   NULL,
    [VendorName]                NVARCHAR (50)   NULL,
    [SalesOrderNo]              NVARCHAR (10)   NULL,
    [SalesOrderId]              NVARCHAR (10)   NULL,
    [MoldNo]                    NVARCHAR (20)   NULL,
    [MoldId]                    NVARCHAR (10)   NULL,
    [MoldName]                  NVARCHAR (100)  NULL,
    [PartNo]                    NVARCHAR (20)   NULL,
    [PartName]                  NVARCHAR (50)   NULL,
    [Spec]                      NVARCHAR (80)   NULL,
    [Material]                  NVARCHAR (15)   NULL,
    [ProcessTypeId]             NVARCHAR (3)    NULL,
    [ProcessTypeName]           NVARCHAR (30)   NULL,
    [ProcessTypeNameFromMaster] NVARCHAR (30)   NULL,
    [Quantity]                  DECIMAL (14, 2) NULL,
    [EstimatedHours]            DECIMAL (11, 2) NULL,
    [UnitPrice]                 DECIMAL (20, 4) NULL,
    [ProcessingFee]             DECIMAL (11, 2) NULL,
    [MaterialFee]               DECIMAL (11, 2) NULL,
    [Amount]                    DECIMAL (20, 2) NULL,
    [DiscountPercent]           DECIMAL (11)    NULL,
    [IsFree]                    BIT             CONSTRAINT [DF_OutsourceReceiveRowData_IsFree] DEFAULT ((0)) NOT NULL,
    [ProcessingDescription]     NVARCHAR (150)  NULL,
    [Remark]                    NVARCHAR (100)  NULL,
    [IsClosed]                  NVARCHAR (1)    NULL,
    [DeliveryStatusCode]        NVARCHAR (1)    NULL,
    [DeliveryStatusName]        NVARCHAR (10)   NULL,
    [QualityStatusCode]         NVARCHAR (1)    NULL,
    [QualityStatusName]         NVARCHAR (10)   NULL,
    [DeliveryConfirmedCode]     NVARCHAR (1)    NULL,
    [QualityConfirmedCode]      NVARCHAR (1)    NULL,
    [PromisedDeliveryDate]      DATETIME        NULL,
    [WorkOrderItemNo]           NVARCHAR (10)   NULL,
    [ProcessSequence]           NVARCHAR (2)    NULL,
    [LastModifiedEmployeeName]  NVARCHAR (12)   NULL,
    [ModifiedDate]              DATETIME        NULL,
    [DeleteFlag]                BIT             CONSTRAINT [DF_OutsourceReceiveRowData_DeleteFlag] DEFAULT ((0)) NOT NULL,
    [RecordTimestamp]           BINARY (8)      NULL,
    [LastModifiedTime]          DATETIME        NULL,
    [RefreshedAt]               DATETIME2 (3)   CONSTRAINT [DF_OutsourceReceiveRowData_RefreshedAt] DEFAULT (sysutcdatetime()) NOT NULL,
    CONSTRAINT [PK_OutsourceReceiveRowData] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_OutsourceReceiveRowData_Item] ON [Reporting].[OutsourceReceiveRowData] ([OutsourceReceiveItemId]);
GO
CREATE NONCLUSTERED INDEX [IX_OutsourceReceiveRowData_Receive] ON [Reporting].[OutsourceReceiveRowData] ([OutsourceReceiveId]);
GO
CREATE NONCLUSTERED INDEX [IX_OutsourceReceiveRowData_Mold] ON [Reporting].[OutsourceReceiveRowData] ([MoldNo]);
GO
CREATE NONCLUSTERED INDEX [IX_OutsourceReceiveRowData_SalesOrder_Part_Process] ON [Reporting].[OutsourceReceiveRowData] ([SalesOrderNo], [PartNo], [ProcessTypeId]);
GO
CREATE NONCLUSTERED INDEX [IX_OutsourceReceiveRowData_Vendor] ON [Reporting].[OutsourceReceiveRowData] ([VendorId]);
GO
CREATE NONCLUSTERED INDEX [IX_OutsourceReceiveRowData_ProcessType] ON [Reporting].[OutsourceReceiveRowData] ([ProcessTypeId]);
GO
CREATE NONCLUSTERED INDEX [IX_OutsourceReceiveRowData_ReceiveDate] ON [Reporting].[OutsourceReceiveRowData] ([ReceiveDate] DESC);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包收料寬表（PUR041+PUR042 展平，外包費 base，含 MD_NO 製程歸因）— PUR060 外包收料作業', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'RowId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'明細 PK (PUR04_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'OutsourceReceiveItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料單 PK (PUR04_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'OutsourceReceiveId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料編號 (PUR041.NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ReceiveNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源 PUR032 明細 (PUR03_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'OutsourceOrderItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'項次 (ITEM_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'LineItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'日期 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ReceiveDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'送貨單號 (DLV_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'送貨日期 (DLV_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'帳款月份 (YYMM)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'AccountingMonth';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'幣別 (BIL_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'CurrencyCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'匯率', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ExchangeRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'發票號碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'InvoiceNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'增值稅 (TAX)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeaderTax';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'合計金額 (AMT2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeaderSubtotal';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'含稅總額 (AMT3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeaderTotalAmount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'增值稅率 (R_TAX)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'TaxRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料者姓名 (EMP_NAME，含工號)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ReceiverName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'類別 (TYPE1，例：訂單外包)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'OutsourceCategoryName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'列印日期 (PRINT_DT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'PrintedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ApproverEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ApprovedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商編號原始值 (CUST_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'VendorRawId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'VendorId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'VendorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令號 (JOB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID (SAL04_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號 (SUB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品名 (NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'規格 (SPECF)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'Spec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質 (MTRL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'Material';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別代碼 (MD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱 (MD_NA，明細登錄)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱（主檔 PSS010）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessTypeNameFromMaster';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'Quantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預估工時 (TIME1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'EstimatedHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單價 (AMT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'UnitPrice';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工費 (AMT_HR)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessingFee';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'料價 (AMT_MTR)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'MaterialFee';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'金額 (AMT2) — 外包費 base', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'Amount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'折數 (DISCOUNT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'DiscountPercent';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'免費 (AMT_N)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'IsFree';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工說明 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessingDescription';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品管備註欄 (QC_REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完工代號 (OK_FLG)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'IsClosed';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期 (S_DELIVER): Y=合格如期 / N=逾期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質 (S_QUALITY): Y=合格 / N=曾退貨', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'QualityStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'QualityStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'交期確認 (D_CHK1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質確認 (Q_CHK1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'QualityConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預交貨日 (DATE2) — 品檢退回時必填，預設今天+3天，同步寫回 PUR032', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'PromisedDeliveryDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令連線單號 (WIP05_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'WorkOrderItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程順序 (SR_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessSequence';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'編修人員姓名 (含工號)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'編修日期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'ModifiedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表刷新時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'OutsourceReceiveRowData', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/HeatTreatmentReceiveRowData.sql ----------
CREATE TABLE [Reporting].[HeatTreatmentReceiveRowData] (
    [RowId]                      BIGINT          IDENTITY (1, 1) NOT NULL,
    [HeatTreatmentReceiveItemId] NVARCHAR (10)   NOT NULL,
    [HeatTreatmentReceiveId]     NVARCHAR (10)   NULL,
    [ReceiveNo]                  NVARCHAR (10)   NULL,
    [HeatTreatmentOrderItemId]   NVARCHAR (10)   NULL,
    [LineItemNo]                 NVARCHAR (4)    NULL,
    [ReceiveDate]                DATETIME        NULL,
    [AccountingMonth]            NVARCHAR (6)    NULL,
    [CurrencyCode]               NVARCHAR (3)    NULL,
    [ExchangeRate]               DECIMAL (12, 4) NULL,
    [InvoiceNo]                  NVARCHAR (10)   NULL,
    [HeaderTax]                  DECIMAL (9, 2)  NULL,
    [HeaderSubtotal]             DECIMAL (20, 2) NULL,
    [HeaderTotalAmount]          DECIMAL (20, 2) NULL,
    [TaxRate]                    DECIMAL (10, 1) NULL,
    [QcInspectorName]            NVARCHAR (8)    NULL,
    [ReceiverName]               NVARCHAR (50)   NULL,
    [PaymentTermsCode]           NVARCHAR (1)    NULL,
    [HeaderCategoryCode]         NVARCHAR (20)   NULL,
    [ApproverEmployeeId]         NVARCHAR (10)   NULL,
    [ApprovedTime]               DATETIME        NULL,
    [VendorRawId]                NVARCHAR (15)   NULL,
    [VendorId]                   NVARCHAR (15)   NULL,
    [VendorName]                 NVARCHAR (50)   NULL,
    [SalesOrderNo]               NVARCHAR (10)   NULL,
    [SalesOrderId]               NVARCHAR (10)   NULL,
    [MoldNo]                     NVARCHAR (20)   NULL,
    [MoldId]                     NVARCHAR (10)   NULL,
    [MoldName]                   NVARCHAR (100)  NULL,
    [PartNo]                     NVARCHAR (20)   NULL,
    [PartName]                   NVARCHAR (50)   NULL,
    [Spec]                       NVARCHAR (40)   NULL,
    [Material]                   NVARCHAR (15)   NULL,
    [Unit]                       NVARCHAR (6)    NULL,
    [Weight]                     NVARCHAR (6)    NULL,
    [ProcessTypeId]              NVARCHAR (3)    NULL,
    [ProcessTypeName]            NVARCHAR (30)   NULL,
    [ProcessTypeNameFromMaster]  NVARCHAR (30)   NULL,
    [HeatTreatmentTypeCode]      NVARCHAR (20)   NULL,
    [HeatTreatmentTypeCodeAlt]   NVARCHAR (20)   NULL,
    [HardnessRequirement]        NVARCHAR (10)   NULL,
    [MeasuredHardness]           NVARCHAR (10)   NULL,
    [Quantity]                   DECIMAL (5)     NULL,
    [UnitPrice]                  DECIMAL (20, 4) NULL,
    [Amount]                     DECIMAL (18, 2) NULL,
    [IsFree]                     BIT             CONSTRAINT [DF_HeatTreatmentReceiveRowData_IsFree] DEFAULT ((0)) NOT NULL,
    [Remark]                     NVARCHAR (100)  NULL,
    [IsClosed]                   NVARCHAR (1)    NULL,
    [DeliveryStatusCode]         NVARCHAR (1)    NULL,
    [DeliveryStatusName]         NVARCHAR (10)   NULL,
    [QualityStatusCode]          NVARCHAR (1)    NULL,
    [QualityStatusName]          NVARCHAR (10)   NULL,
    [DeliveryConfirmedCode]      NVARCHAR (1)    NULL,
    [QualityConfirmedCode]       NVARCHAR (1)    NULL,
    [HasReport]                  NVARCHAR (1)    NULL,
    [RequiresReport]             BIT             CONSTRAINT [DF_HeatTreatmentReceiveRowData_RequiresReport] DEFAULT ((0)) NOT NULL,
    [WorkOrderItemNo]            NVARCHAR (10)   NULL,
    [ProcessSequence]            NVARCHAR (2)    NULL,
    [DeleteFlag]                 BIT             CONSTRAINT [DF_HeatTreatmentReceiveRowData_DeleteFlag] DEFAULT ((0)) NOT NULL,
    [RecordTimestamp]            BINARY (8)      NULL,
    [LastModifiedTime]           DATETIME        NULL,
    [RefreshedAt]                DATETIME2 (3)   CONSTRAINT [DF_HeatTreatmentReceiveRowData_RefreshedAt] DEFAULT (sysutcdatetime()) NOT NULL,
    CONSTRAINT [PK_HeatTreatmentReceiveRowData] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_HeatTreatmentReceiveRowData_Item] ON [Reporting].[HeatTreatmentReceiveRowData] ([HeatTreatmentReceiveItemId]);
GO
CREATE NONCLUSTERED INDEX [IX_HeatTreatmentReceiveRowData_Receive] ON [Reporting].[HeatTreatmentReceiveRowData] ([HeatTreatmentReceiveId]);
GO
CREATE NONCLUSTERED INDEX [IX_HeatTreatmentReceiveRowData_Mold] ON [Reporting].[HeatTreatmentReceiveRowData] ([MoldNo]);
GO
CREATE NONCLUSTERED INDEX [IX_HeatTreatmentReceiveRowData_SalesOrder_Part_Process] ON [Reporting].[HeatTreatmentReceiveRowData] ([SalesOrderNo], [PartNo], [ProcessTypeId]);
GO
CREATE NONCLUSTERED INDEX [IX_HeatTreatmentReceiveRowData_Vendor] ON [Reporting].[HeatTreatmentReceiveRowData] ([VendorId]);
GO
CREATE NONCLUSTERED INDEX [IX_HeatTreatmentReceiveRowData_ProcessType] ON [Reporting].[HeatTreatmentReceiveRowData] ([ProcessTypeId]);
GO
CREATE NONCLUSTERED INDEX [IX_HeatTreatmentReceiveRowData_ReceiveDate] ON [Reporting].[HeatTreatmentReceiveRowData] ([ReceiveDate] DESC);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理外包收料寬表（PUR061+PUR062 展平，熱處理外包費 base，含 MD_NO 製程歸因與硬度需求/實測）— PUR080 熱處理外包收料作業', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'RowId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'明細 PK (PUR06_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeatTreatmentReceiveItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料單 PK (PUR06_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeatTreatmentReceiveId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料編號 (PUR061.NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'ReceiveNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源 PUR052 明細 (PUR05_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeatTreatmentOrderItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'項次 (ITEM_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'LineItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'日期 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'ReceiveDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'帳款月份 (YYMM)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'AccountingMonth';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'幣別', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'CurrencyCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'匯率', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'ExchangeRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'發票號碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'InvoiceNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'增值稅 (TAX)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeaderTax';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'合計金額 (AMT2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeaderSubtotal';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'含稅總額 (AMT3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeaderTotalAmount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'增值稅率 (R_TAX)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'TaxRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品管者姓名 (PUR061.QC，含工號)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'QcInspectorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料者姓名 (EMP_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'ReceiverName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'付款方式 (PAY_TYPE1)：例 A=月結', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'PaymentTermsCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'表頭類別 (PUR061.TYPE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeaderCategoryCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'ApproverEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'ApprovedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商編號原始值 (CUST_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'VendorRawId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'VendorId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'VendorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令號 (JOB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號 (SUB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品名 (NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'規格 (SPECF)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'Spec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質 (MTRL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'Material';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位 (UNIT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'Unit';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'重量@ (WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'Weight';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別代碼 (MD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別/熱處理名稱 (MD_NA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱（主檔 PSS010）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessTypeNameFromMaster';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理別 (TYPE1，一般客戶；對應 MTR207 主檔)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeatTreatmentTypeCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理別替代欄 (TYPE6，明基客戶放於此)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HeatTreatmentTypeCodeAlt';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'硬度要求 (HARDNESS，從 PUR052 帶下)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HardnessRequirement';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'實際/實測硬度 (REALHARD，收料填，完工時寫回 PCM010.HD4)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'MeasuredHardness';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'Quantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單價 (AMT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'UnitPrice';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'金額 (AMT2) — 熱處理外包費 base', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'Amount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'免費 (AMT_N)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'IsFree';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註欄 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完工代號 (OK_FLG)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'IsClosed';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期 (S_DELIVER): Y=合格如期 / N=逾期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質 (S_QUALITY): Y=合格 / N=曾退貨', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'QualityStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'QualityStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'交期確認 (D_CHK1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeliveryConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質確認 (Q_CHK1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'QualityConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報告 (REPORT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'HasReport';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'需報告 (R_REPORT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'RequiresReport';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令連線單號 (WIP05_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'WorkOrderItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程順序 (SR_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'ProcessSequence';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表刷新時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'HeatTreatmentReceiveRowData', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/MoldCostSummary.sql ----------
CREATE TABLE [Reporting].[MoldCostSummary] (
    [RowId]                BIGINT          IDENTITY (1, 1) NOT NULL,
    [MoldId]               NVARCHAR (10)   NULL,
    [MoldNo]               NVARCHAR (20)   NOT NULL,
    [MoldName]             NVARCHAR (60)   NULL,
    [TotalProcessingHours] DECIMAL (18, 2) NULL,
    [FirstWorkStartTime]   DATETIME        NULL,
    [LastWorkEndTime]      DATETIME        NULL,
    [WorkPeriodDays]       INT             NULL,
    [LaborCost]            DECIMAL (20, 2) NULL,
    [MaterialCost]         DECIMAL (20, 2) NULL,
    [GeneralOutsourceCost] DECIMAL (20, 2) NULL,
    [HeatTreatmentCost]    DECIMAL (20, 2) NULL,
    [OutsourceCost]        DECIMAL (20, 2) NULL,
    [TotalCost]            DECIMAL (20, 2) NULL,
    [HasWorkRecord]        BIT             CONSTRAINT [DF_MoldCostSummary_HasWorkRecord] DEFAULT ((0)) NOT NULL,
    [HasPurchase]          BIT             CONSTRAINT [DF_MoldCostSummary_HasPurchase] DEFAULT ((0)) NOT NULL,
    [HasOutsource]         BIT             CONSTRAINT [DF_MoldCostSummary_HasOutsource] DEFAULT ((0)) NOT NULL,
    [HasHeatTreatment]     BIT             CONSTRAINT [DF_MoldCostSummary_HasHeatTreatment] DEFAULT ((0)) NOT NULL,
    [RefreshedAt]          DATETIME2 (3)   CONSTRAINT [DF_MoldCostSummary_RefreshedAt] DEFAULT (sysutcdatetime()) NOT NULL,
    CONSTRAINT [PK_MoldCostSummary] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_MoldCostSummary_Mold] ON [Reporting].[MoldCostSummary] ([MoldNo]);
GO
CREATE NONCLUSTERED INDEX [IX_MoldCostSummary_MoldId] ON [Reporting].[MoldCostSummary] ([MoldId]);
GO
CREATE NONCLUSTERED INDEX [IX_MoldCostSummary_TotalCost] ON [Reporting].[MoldCostSummary] ([TotalCost] DESC);
GO
CREATE NONCLUSTERED INDEX [IX_MoldCostSummary_WorkPeriod] ON [Reporting].[MoldCostSummary] ([WorkPeriodDays] DESC);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具成本總表彙總寬表（每模具一行，跨 WorkRecord/Purchase/Outsource/HeatTreatment 四 base 寬表彙總）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'RowId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID (PCM01_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO，彙總歸因鍵)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱 (DIE_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工總工時 (Σ WIP020.TIME2 機工時)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'TotalProcessingHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最早報工開工時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'FirstWorkStartTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最晚報工完工時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'LastWorkEndTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工期天數 = DATEDIFF(DAY, MIN(WorkStart), MAX(WorkEnd))', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'WorkPeriodDays';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工費 = Σ (MachineOccupiedHours × ProcessingRate)，ProcessingRate 來自 WorkRecordRowData (PSS055 月度優先，PSS050.AMT1 fallback)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'LaborCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'料費 = Σ PurchaseReceiveRowData.Amount', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'MaterialCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'一般外包費 = Σ OutsourceReceiveRowData.Amount', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'GeneralOutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理外包費 = Σ HeatTreatmentReceiveRowData.Amount', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'HeatTreatmentCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包費合計 = 一般外包 + 熱處理外包', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'OutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'總金額 = 工費 + 料費 + 外包費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'TotalCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有報工記錄', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'HasWorkRecord';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有採購收料', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'HasPurchase';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有外包收料', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'HasOutsource';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有熱處理外包', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'HasHeatTreatment';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表刷新時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldCostSummary', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/MoldPartCostSummary.sql ----------
CREATE TABLE [Reporting].[MoldPartCostSummary] (
    [RowId]                BIGINT          IDENTITY (1, 1) NOT NULL,
    [PartId]               NVARCHAR (10)   NULL,
    [MoldId]               NVARCHAR (10)   NULL,
    [MoldNo]               NVARCHAR (20)   NOT NULL,
    [MoldName]             NVARCHAR (100)  NULL,
    [PartNo]               NVARCHAR (20)   NOT NULL,
    [PartName]             NVARCHAR (50)   NULL,
    [TotalProcessingHours] DECIMAL (18, 2) NULL,
    [FirstWorkStartTime]   DATETIME        NULL,
    [LastWorkEndTime]      DATETIME        NULL,
    [WorkPeriodDays]       INT             NULL,
    [LaborCost]            DECIMAL (20, 2) NULL,
    [MaterialCost]         DECIMAL (20, 2) NULL,
    [GeneralOutsourceCost] DECIMAL (20, 2) NULL,
    [HeatTreatmentCost]    DECIMAL (20, 2) NULL,
    [OutsourceCost]        DECIMAL (20, 2) NULL,
    [TotalCost]            DECIMAL (20, 2) NULL,
    [HasWorkRecord]        BIT             CONSTRAINT [DF_MoldPartCostSummary_HasWorkRecord] DEFAULT ((0)) NOT NULL,
    [HasPurchase]          BIT             CONSTRAINT [DF_MoldPartCostSummary_HasPurchase] DEFAULT ((0)) NOT NULL,
    [HasOutsource]         BIT             CONSTRAINT [DF_MoldPartCostSummary_HasOutsource] DEFAULT ((0)) NOT NULL,
    [HasHeatTreatment]     BIT             CONSTRAINT [DF_MoldPartCostSummary_HasHeatTreatment] DEFAULT ((0)) NOT NULL,
    [RefreshedAt]          DATETIME2 (3)   CONSTRAINT [DF_MoldPartCostSummary_RefreshedAt] DEFAULT (sysutcdatetime()) NOT NULL,
    CONSTRAINT [PK_MoldPartCostSummary] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_MoldPartCostSummary_MoldPart] ON [Reporting].[MoldPartCostSummary] ([MoldNo], [PartNo]);
GO
CREATE NONCLUSTERED INDEX [IX_MoldPartCostSummary_PartNo] ON [Reporting].[MoldPartCostSummary] ([PartNo]);
GO
CREATE NONCLUSTERED INDEX [IX_MoldPartCostSummary_PartId] ON [Reporting].[MoldPartCostSummary] ([PartId]);
GO
CREATE NONCLUSTERED INDEX [IX_MoldPartCostSummary_TotalCost] ON [Reporting].[MoldPartCostSummary] ([TotalCost] DESC);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具零件成本彙總寬表（每模具+零件一行，跨 WorkRecord/Purchase/Outsource/HeatTreatment 四 base 寬表彙總）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'RowId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件ID (PCM03_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'PartId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID (PCM01_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號 (SUB_NO，彙總歸因鍵)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工總工時 (Σ 機工時)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'TotalProcessingHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最早報工開工時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'FirstWorkStartTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最晚報工完工時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'LastWorkEndTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工期天數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'WorkPeriodDays';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工費 = Σ (機工時 × ProcessingRate)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'LaborCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'料費 = Σ PurchaseReceive.Amount，歸因鍵：MoldNo + InventoryItemId 對齊 PartNo（注意：MTR022.PART_NO 為庫存料號，命中率視客戶料號規範而定）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'MaterialCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'一般外包費 = Σ OutsourceReceive.Amount by MoldNo+PartNo', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'GeneralOutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理外包費 = Σ HeatTreatmentReceive.Amount by MoldNo+PartNo', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'HeatTreatmentCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包費合計', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'OutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'總金額', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'TotalCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有報工記錄', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'HasWorkRecord';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有採購收料', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'HasPurchase';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有外包收料', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'HasOutsource';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有熱處理外包', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'HasHeatTreatment';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表刷新時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartCostSummary', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO

-- ---------- Tables/MoldPartProcessCostSummary.sql ----------
CREATE TABLE [Reporting].[MoldPartProcessCostSummary] (
    [RowId]                BIGINT          IDENTITY (1, 1) NOT NULL,
    [MoldId]               NVARCHAR (10)   NULL,
    [MoldNo]               NVARCHAR (20)   NOT NULL,
    [MoldName]             NVARCHAR (100)  NULL,
    [PartId]               NVARCHAR (11)   NULL,
    [PartNo]               NVARCHAR (20)   NOT NULL,
    [PartName]             NVARCHAR (50)   NULL,
    [ProcessTypeId]        NVARCHAR (6)    NOT NULL,
    [ProcessTypeName]      NVARCHAR (30)   NULL,
    [TotalProcessingHours] DECIMAL (18, 2) NULL,
    [FirstWorkStartTime]   DATETIME        NULL,
    [LastWorkEndTime]      DATETIME        NULL,
    [WorkPeriodDays]       INT             NULL,
    [LaborCost]            DECIMAL (20, 2) NULL,
    [GeneralOutsourceCost] DECIMAL (20, 2) NULL,
    [HeatTreatmentCost]    DECIMAL (20, 2) NULL,
    [OutsourceCost]        DECIMAL (20, 2) NULL,
    [TotalCost]            DECIMAL (20, 2) NULL,
    [HasWorkRecord]        BIT             CONSTRAINT [DF_MoldPartProcessCostSummary_HasWorkRecord] DEFAULT ((0)) NOT NULL,
    [HasOutsource]         BIT             CONSTRAINT [DF_MoldPartProcessCostSummary_HasOutsource] DEFAULT ((0)) NOT NULL,
    [HasHeatTreatment]     BIT             CONSTRAINT [DF_MoldPartProcessCostSummary_HasHeatTreatment] DEFAULT ((0)) NOT NULL,
    [IsOutsourced]         BIT             CONSTRAINT [DF_MoldPartProcessCostSummary_IsOutsourced] DEFAULT ((0)) NOT NULL,
    [RefreshedAt]          DATETIME2 (3)   CONSTRAINT [DF_MoldPartProcessCostSummary_RefreshedAt] DEFAULT (sysutcdatetime()) NOT NULL,
    CONSTRAINT [PK_MoldPartProcessCostSummary] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

GO
CREATE NONCLUSTERED INDEX [IX_MoldPartProcessCostSummary_MoldPartProcess] ON [Reporting].[MoldPartProcessCostSummary] ([MoldNo], [PartNo], [ProcessTypeId]);
GO
CREATE NONCLUSTERED INDEX [IX_MoldPartProcessCostSummary_ProcessType] ON [Reporting].[MoldPartProcessCostSummary] ([ProcessTypeId]);
GO
CREATE NONCLUSTERED INDEX [IX_MoldPartProcessCostSummary_TotalCost] ON [Reporting].[MoldPartProcessCostSummary] ([TotalCost] DESC);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具零件製程成本彙總寬表（每模具+零件+工別一行，最細粒度成本分析。無料費，因 MTR022 無 MD_NO 歸因）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表代理主鍵', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'RowId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'PartId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號 (SUB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別代碼 (MD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'ProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'ProcessTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工總工時', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'TotalProcessingHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最早開工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'FirstWorkStartTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最晚完工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'LastWorkEndTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工期天數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'WorkPeriodDays';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工費 = Σ (機工時 × ProcessingRate)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'LaborCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'一般外包費 = Σ OutsourceReceive.Amount by MoldNo+PartNo+ProcessTypeId', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'GeneralOutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理外包費 = Σ HeatTreatmentReceive.Amount by MoldNo+PartNo+ProcessTypeId', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'HeatTreatmentCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包費合計', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'OutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'總金額 = 工費 + 外包費（無料費）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'TotalCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有廠內報工記錄', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'HasWorkRecord';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有一般外包', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'HasOutsource';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有熱處理外包', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'HasHeatTreatment';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否外發製程（HasOutsource 或 HasHeatTreatment）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'IsOutsourced';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'寬表刷新時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'TABLE', @level1name = N'MoldPartProcessCostSummary', @level2type = N'COLUMN', @level2name = N'RefreshedAt';
GO
