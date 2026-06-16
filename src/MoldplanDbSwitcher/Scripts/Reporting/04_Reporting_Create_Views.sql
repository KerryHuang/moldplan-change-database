USE [<<Database>>];   -- ⚠️ 換成報表庫名（統一為 MoldPlan-Reporting）
GO

-- =============================================
-- 13 個 Reporting View（跨庫三段式命名版）
-- =============================================
-- 來源：PM-497 CR（Reporting 自主庫抽出至獨立資料庫）
-- 性質：一次性。FROM/JOIN 的跨庫 schema（dbo/Production/Sales/
--       HumanResources/Design）一律加 [<<MAINDB>>]. 前綴指向客戶主庫；
--       本地寬表 [Reporting].* 維持兩段式不動。
--
-- ⚠️ 本檔有「兩個占位符」要換：
--    1. <<Database>>（第 1 行 USE）→ 報表庫名 MoldPlan-Reporting
--    2. <<MAINDB>>（全檔 97 處）→ 該客戶主庫名
--       例：gma-staging / waydosoft01-test / moldplan-fupite-staging …
--    （編輯器全取代最直觀，不需 SQLCMD 模式）
--
-- ⚠️ 維護：本檔與 SSDT 源頭 06.Database/.../Reporting/Views/ 已「刻意分岔」
--    （源頭為同庫兩段式版）。日後改 View，兩邊都要同步。
-- =============================================

-- ============================================================
-- 20 Reporting Create Views (one-shot)
-- 互無依賴；summary view 直接 JOIN 既有寬表
-- ============================================================
GO

-- ---------- Views/SalesOrderRowDataView.sql ----------
CREATE VIEW [Reporting].[SalesOrderRowDataView]
AS
SELECT
    -- 訂單基本資訊
    SAL041.SAL04_NO                                  AS SalesOrderId,
    SAL041.ORDER_NO                                  AS SalesOrderNo,
    EXT.DocumentNo                                   AS DocumentNo,
    SAL041.QUOT_NO                                   AS QuotationNo,
    SAL041.CUST_ORDER                                AS CustomerOrderNo,
    EXT.CustomerPurchaseOrderNo                      AS CustomerPurchaseOrderNo,
    SAL041.PAYMENT                                   AS Payment,

    -- 客戶
    SAL041.CUST_NO                                   AS CustomerId,
    SAL010.SUBNAME                                   AS CustomerSubname,

    -- 訂單類型 / 類別 / 產品類別
    SOT.Id                                           AS SalesOrderTypeId,
    SOT.SalesOrderTypeCode                           AS SalesOrderTypeCode,
    SAL041.TYPE1                                     AS SalesOrderTypeName,
    SOT.BusinessPattern                              AS BusinessPattern,
    SOC.Id                                           AS SalesOrderCategoryId,
    SOC.SalesOrderCategoryCode                       AS SalesOrderCategoryCode,
    SAL041.TYPE2                                     AS SalesOrderCategoryName,
    PCM206.[NO]                                      AS ProductTypeId,
    SAL041.PRDNA                                     AS ProductTypeCode,
    PCM206.REMARK                                    AS ProductTypeName,

    -- 幣別 / 金額
    SAL051.BIL_NO                                    AS CurrencyId,
    SAL051.BIL_NA                                    AS CurrencyName,
    SAL041.EXCHANGE                                  AS ExchangeRate,
    SAL041.AMT1                                      AS OrderTotal,
    SAL041.AMT_Y                                     AS PayableAmount,
    SAL041.AMT_N                                     AS FreeAmount,
    SAL041.AMT_X                                     AS LatePenaltyAmount,

    -- 狀態 / 緊急程度
    SOS.Id                                           AS SalesOrderStatusId,
    SOS.SalesOrderStatusCode                         AS SalesOrderStatusCode,
    SOS.SalesOrderStatusName                         AS SalesOrderStatusName,
    EXT.CustomCode                                   AS CustomCode,
    URG.UrgencyTypeId                                AS UrgencyTypeId,
    SAL041.URGENT                                    AS UrgencyTypeCode,
    URG.UrgencyTypeName                              AS UrgencyTypeName,

    -- 備註
    CAST(SAL041.REMARK AS NVARCHAR(MAX))             AS [Description],
    CAST(SAL041.MEMO1  AS NVARCHAR(MAX))             AS GeneralNote,
    CAST(SAL041.MEMO2  AS NVARCHAR(MAX))             AS ProductionNote,
    CAST(SAL041.MEMO3  AS NVARCHAR(MAX))             AS DiscussionNotes,

    -- 時間
    SAL041.DATE_INPUT                                AS InputDate,
    SAL041.DATE1                                     AS OrderDate,
    SAL041.T1_DATE                                   AS T1TrialDate,
    SAL041.OK_DATE                                   AS CompletionDate,
    SAL041.DATE2                                     AS DeliveryDate,
    SAL041.DATE4                                     AS FactoryDueDate,
    SAL041.DATE6                                     AS FactoryCompletionDate,

    -- 人員
    PPER010.EmployeeId                               AS PlannerEmployeeId,
    SAL041.NAME3                                     AS PlannerEmployeeName,
    CAST(NULL AS NVARCHAR(10))                       AS SalespersonId,
    SAL041.SALES                                     AS SalespersonName,
    EXT.FitterEmployeeId                             AS FitterEmployeeId,
    FPER010.EmployeeName                             AS FitterEmployeeName,
    CPER010.EmployeeId                               AS CreatedEmployeeId,
    SAL041.EMP_NA                                    AS CreatedEmployeeName,

    -- 修改紀錄
    MPER010.EmployeeId                               AS LastModifiedEmployeeId,
    SAL041.MOD_NAME                                  AS LastModifiedEmployeeName,
    SAL041.MOD_DATE                                  AS ModifiedDate,

    -- 通用
    ISNULL(CONVERT(BIT, CASE WHEN SAL041.DEL_MARK = 'Y' THEN 1 ELSE 0 END), 0) AS DeleteFlag,
    SAL041.[TIMESTAMP]                               AS RecordTimestamp,
    SAL041.UTIME                                     AS LastModifiedTime,

    -- 模具
    M.PCM01_NO                                       AS MoldId,
    SAL041.DIE_NO                                    AS MoldNo,
    SAL041.DIE_NAME                                  AS MoldName,

    -- 計算欄位
    ISNULL(CONVERT(BIT, CASE WHEN SAL041.SHIP_DT IS NOT NULL THEN 1 ELSE 0 END), 0) AS IsShipped,
    ISNULL(CONVERT(BIT, CASE WHEN SAL041.AMT_N = 0           THEN 1 ELSE 0 END), 0) AS IsDiscount,
    CASE WHEN SAL041.OK_FLG <> 'Y' OR SAL041.OK_DATE IS NULL THEN NULL
         ELSE DATEDIFF(DAY, GETDATE(), SAL041.OK_DATE) END                          AS CompletedDays

FROM [<<MAINDB>>].dbo.SAL041
    LEFT JOIN [<<MAINDB>>].dbo.SAL010                          ON SAL041.CUST_NO   = SAL010.CUST_NO              AND SAL010.DEL_MARK    = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.PCM206                          ON SAL041.PRDNA     = PCM206.PROD_TYPE            AND PCM206.DEL_MARK    = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.SAL051                          ON SAL041.BIL_NO    = SAL051.BIL_NO               AND SAL051.DEL_MARK    = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.PCM010                       M  ON SAL041.DIE_NO    = M.DIE_NO                    AND M.DEL_MARK         = 'N'
    LEFT JOIN [<<MAINDB>>].[Sales].[SalesOrderType]     SOT    ON SAL041.TYPE1     = SOT.SalesOrderTypeName      AND SOT.DeleteFlag     = 0
    LEFT JOIN [<<MAINDB>>].[Sales].[SalesOrderCategory] SOC    ON SAL041.TYPE2     = SOC.SalesOrderCategoryName  AND SOC.DeleteFlag     = 0
    LEFT JOIN [<<MAINDB>>].[Sales].[SalesOrderStatus]   SOS    ON SAL041.OK_FLG    = SOS.SalesOrderStatusCode    AND SOS.DeleteFlag     = 0
    LEFT JOIN [<<MAINDB>>].[Sales].[UrgencyType]        URG    ON SAL041.URGENT    = URG.UrgencyTypeCode         AND URG.DeleteFlag     = 0
    LEFT JOIN [<<MAINDB>>].[Sales].[SalesOrderExt]      EXT    ON SAL041.SAL04_NO  = EXT.SalesOrderId
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee] PPER010 ON SAL041.NAME3    = PPER010.EmployeeName         AND PPER010.DeleteFlag = 0
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee] CPER010 ON SAL041.EMP_NA   = CPER010.EmployeeName         AND CPER010.DeleteFlag = 0
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee] MPER010 ON SAL041.MOD_NAME = MPER010.EmployeeName         AND MPER010.DeleteFlag = 0
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee] FPER010 ON EXT.FitterEmployeeId = FPER010.EmployeeId      AND FPER010.DeleteFlag = 0
WHERE SAL041.DEL_MARK = 'N'
  AND SAL041.SYS_TYPE IN ('MOLDPLAN', '');

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'銷售訂單寬表 View（SAL041 + 維度展平，不含 LTRIM 清洗，由 SP 寫入寬表時處理）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID (SAL04_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'文件編號 [鼎新訂單編號]', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'DocumentNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報價單號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'QuotationNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶訂單編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CustomerOrderNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶單號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CustomerPurchaseOrderNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'付款辦法', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'Payment';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CustomerId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶簡稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CustomerSubname';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類型ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類型代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類型名稱 (TYPE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'業務模式 (MoldProject/RepairProject/null)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'BusinessPattern';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類別ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderCategoryId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderCategoryCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單類別名稱 (TYPE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderCategoryName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品類別ID (PCM206.NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'ProductTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品類別代碼 (PRDNA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'ProductTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品類別名稱 (PCM206.REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'ProductTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'幣別ID (SAL051.BIL_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CurrencyId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'幣別名稱 (SAL051.BIL_NA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CurrencyName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'匯率 (EXCHANGE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'ExchangeRate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單總額 (AMT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'OrderTotal';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'應收金額 (AMT_Y)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'PayableAmount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'免收金額 (AMT_N)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'FreeAmount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'延遲罰款金額 (AMT_X)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'LatePenaltyAmount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單狀態ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderStatusId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單狀態代碼 (T=試模, Y=結案, P=暫停, C=作廢, K=待確認, D=銷毀)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderStatusCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderStatusName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'鼎新結案碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CustomCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'緊急程度ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'UrgencyTypeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'緊急程度代碼 (URGENT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'UrgencyTypeCode';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'緊急程度名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'UrgencyTypeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'主要內容 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'Description';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'一般備註 (MEMO1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'GeneralNote';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生產備註 (MEMO2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'ProductionNote';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'討論備註 (MEMO3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'DiscussionNotes';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'輸入日期 (DATE_INPUT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'InputDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單日期 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'OrderDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'T1 試模日 (T1_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'T1TrialDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'結案日 (OK_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CompletionDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'交期 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠內交期 (DATE4)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'FactoryDueDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠內完工日 (DATE6)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'FactoryCompletionDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生管人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生管人員姓名 (NAME3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'業務員ID (SAL270 對應，目前未填)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalespersonId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'業務員姓名 (SALES)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'SalespersonName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'鉗工ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'FitterEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'鉗工姓名', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'FitterEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'建檔員工ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CreatedEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'建檔員工姓名 (EMP_NA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CreatedEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改員工ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改員工姓名 (MOD_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'修改日期 (MOD_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'ModifiedDate';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記 (DEL_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳 (TIMESTAMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'MoldId';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'MoldNo';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱 (DIE_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'MoldName';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否已出貨 (SHIP_DT 非空判斷)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'IsShipped';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否折扣 (AMT_N 為 0 判斷)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'IsDiscount';
GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完成天數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderRowDataView', @level2type = N'COLUMN', @level2name = N'CompletedDays';
GO

-- ---------- Views/SalesOrderDetailRowDataView.sql ----------
CREATE VIEW [Reporting].[SalesOrderDetailRowDataView]
AS
SELECT
    -- 主鍵 / 關聯
    SAL042.SAL042_NO                                AS SalesOrderDetailId,
    SAL042.SAL04_NO                                 AS SalesOrderId,
    SAL042.ITEM_NO                                  AS PaddedIndex,

    -- 品項
    SAL042.PROD_NO                                  AS LineItemNo,
    SAL042.DESCRIP                                  AS LineItemName,
    SAL042.EDITION                                  AS VersionNumber,
    SAL042.DWG_NO                                   AS DrawingNumber,

    -- 零件類別
    PT.Id                                           AS PartTypeId,
    PT.PartTypeCode                                 AS PartTypeCode,
    SAL042.TYPE2                                    AS PartTypeName,

    -- 材料 / 材質
    SAL042.SPECF                                    AS MaterialSpec,
    M.MaterialId                                    AS MaterialId,
    SAL042.MTRL                                     AS MaterialName,

    -- 來源類別
    ST.Id                                           AS SourceTypeId,
    ST.SourceTypeCode                               AS SourceTypeCode,
    SAL042.PURCH_YN                                 AS SourceTypeName,

    -- 數量 / 金額
    ISNULL(SAL042.QTY1, 0)                          AS OrderQuantity,
    ISNULL(SAL042.QTY2, 0)                          AS ShippedQuantity,
    ISNULL(
        CASE WHEN ISNUMERIC(SAL042.PRICE) = 0 OR LTRIM(RTRIM(SAL042.PRICE)) = ''
             THEN CONVERT(DECIMAL(12, 4), 0)
             ELSE CONVERT(DECIMAL(12, 4), REPLACE(SAL042.PRICE, ',', ''))
        END, 0)                                     AS UnitPrice,
    ISNULL(SAL042.AMOUNT, 0)                        AS LineTotal,

    -- 單位
    U.UnitId                                        AS UnitId,
    SAL042.UNIT                                     AS UnitName,

    -- 時間 / 其他
    SAL042.DELIVERY                                 AS ScheduledDeliveryDate,
    SAL042.SAL022_SEQ                               AS QuotationOrderId,
    SAL042.REMARK2                                  AS Remark,

    -- 通用
    ISNULL(CONVERT(BIT, CASE WHEN SAL042.DEL_MARK = 'Y' THEN 1 ELSE 0 END), 0) AS DeleteFlag,
    SAL042.UTIME                                    AS LastModifiedTime,
    SAL042.[TIMESTAMP]                              AS RecordTimestamp

FROM [<<MAINDB>>].dbo.SAL042
    INNER JOIN [<<MAINDB>>].dbo.SAL041                       ON SAL042.SAL04_NO = SAL041.SAL04_NO
                                               AND SAL041.DEL_MARK = 'N'
                                               AND SAL041.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].[Production].[SourceType]    ST   ON SAL042.PURCH_YN = ST.SourceTypeName       AND ST.DeleteFlag = 0
    LEFT JOIN [<<MAINDB>>].[Production].[MaterialType]  M    ON SAL042.MTRL     = M.MaterialName
    LEFT JOIN [<<MAINDB>>].[Production].[Unit]          U    ON SAL042.UNIT     = U.UnitName
    LEFT JOIN [<<MAINDB>>].[Production].[PartType]      PT   ON SAL042.TYPE2    = PT.PartTypeName         AND PT.DeleteFlag = 0
WHERE SAL042.DEL_MARK = 'N';

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'銷售訂單明細寬表 View（SAL042 + 維度展平）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單明細ID (SAL042_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderDetailId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID (SAL04_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'項次 (ITEM_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'PaddedIndex';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品號/零件/模具編號 (PROD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'LineItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品名/零件/模具名稱 (DESCRIP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'LineItemName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'版次 (EDITION)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'VersionNumber';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'圖號 (DWG_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'DrawingNumber';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'PartTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'PartTypeCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別名稱 (TYPE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'PartTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材料尺寸 (SPECF)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialSpec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質名稱 (MTRL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源類別ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'SourceTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源類別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'SourceTypeCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源類別名稱 (PURCH_YN)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'SourceTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'OrderQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'已出貨量 (QTY2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'ShippedQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單價 (PRICE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'UnitPrice';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'金額 (AMOUNT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'LineTotal';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'UnitId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位名稱 (UNIT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'UnitName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預定交期 (DELIVERY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'ScheduledDeliveryDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'估價單號 (SAL022_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'QuotationOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註 (REMARK2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'SalesOrderDetailRowDataView', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
GO

-- ---------- Views/WorkOrderPartRowDataView.sql ----------
CREATE VIEW [Reporting].[WorkOrderPartRowDataView]
AS
SELECT
    -- 主鍵
    PCM030.PCM03_NO                                  AS Id,

    -- 訂單
    SAL041.SAL04_NO                                  AS SalesOrderId,
    PCM030.JOB_NO                                    AS SalesOrderNo,

    -- 模具 / 零件設計
    PCM010.PCM01_NO                                  AS MoldId,
    PCM030.DIE_NO                                    AS MoldNo,
    PCM010.DIE_NAME                                  AS MoldName,
    PCM030.SUB_NO                                    AS PartNo,
    PCM030.[NAME]                                    AS PartName,
    PCM030.DWG_NO                                    AS DrawingNo,
    PCM030.[VERSION]                                 AS [Version],
    PCM030.QTY1                                      AS Quantity,
    PCM030.SPECF1                                    AS MachiningSpec,
    PCM030.SPECF2                                    AS MaterialSpec,
    PCM030.DATE0                                     AS DesignCompletionDate,
    PCM030.EBomPartNo                                AS EBomPartNo,

    -- 材質
    M.MaterialId                                     AS MaterialId,
    PCM030.MTRL                                      AS MaterialName,

    -- 零件類別 / 群組
    PT.Id                                            AS PartTypeId,
    PT.PartTypeCode                                  AS PartTypeCode,
    PCM030.TYPE1                                     AS PartTypeName,
    PCM030.TYPE9                                     AS PartGroupId,
    PG.PartGroupName                                 AS PartGroupName,

    -- 物料來源 / 採購
    S.Id                                             AS SourceTypeId,
    S.SourceTypeCode                                 AS SourceTypeCode,
    PCM030.PURCH_YN                                  AS SourceTypeName,
    V.VendorId                                       AS VendorId,
    PCM030.SUPPLIER                                  AS VendorName,
    PCM030.DATE2                                     AS PurchasedDate,
    PCM030.SPARE2                                    AS InternalSpareQuantity,
    PCM030.SPARE                                     AS CustomerSpareQuantity,
    PCM030.[WEIGHT]                                  AS MaterialWeight,
    PCM030.AMT_M                                     AS EstimatedMaterialCost,
    CONVERT(BIT, CASE WHEN PCM030.TYPE_1  = 'Y' THEN 1 ELSE 0 END) AS IsNeedProcessing,
    CONVERT(BIT, CASE WHEN PCM030.TYPE2   = 'Y' THEN 1 ELSE 0 END) AS IsOutsource,
    CONVERT(BIT, CASE WHEN PCM030.QC_MARK = 'Y' THEN 1 ELSE 0 END) AS IsMaterialInspectionNeeded,

    -- 單位
    U.UnitId                                         AS UnitId,
    PCM030.UNIT                                      AS UnitName,

    -- 庫存
    PCM030.PART_NO                                   AS InventoryItemId,
    P.InventoryItemName                              AS InventoryItemName,
    PCM030.[QTY4]                                    AS WarehouseQuantity,

    -- 生管
    PR.ProductionReasonId                            AS ProductionReasonId,
    PCM030.TYPE3                                     AS ProductionReasonName,
    CONVERT(BIT, CASE WHEN PCM030.PART_INDEX = 'Y' THEN 1 ELSE 0 END) AS IsProcessingStepIndex,
    CONVERT(BIT, CASE WHEN PCM030.OK_FLG     = 'Y' THEN 1 ELSE 0 END) AS IsConfirmed,
    PCM030.TYPE7                                     AS PartStatusId,
    PS.PartStatusName                                AS PartStatusName,
    PCM030.QTY3                                      AS ScrapQuantity,
    PCM030.CLOSING                                   AS ClosureDate,
    PCM030.DATE4                                     AS EarliestStartDate,
    PCM030.DATE5                                     AS LatestEndDate,
    PCM030.ParentPartNo                              AS ParentPartNo,
    PCM030.REMARK                                    AS Remark,
    PCM030.[PRIORITY]                                AS Priority,
    PPER010.EmployeeId                               AS PlannerEmployeeId,
    PCM030.EMP_NAME                                  AS PlannerEmployeeName,

    -- 製程狀態
    PCM030.ACK                                       AS ProcessCheckCode,
    CASE PCM030.ACK
        WHEN 'N' THEN N'待確認'
        WHEN 'A' THEN N'製程已確認'
        WHEN 'S' THEN N'開工'
        WHEN 'E' THEN N'製程編輯中'
        ELSE N''
    END                                              AS ProcessCheckName,
    PCM030.ACK_DATE                                  AS ProcessCheckTime,
    CAST(PCM030.APPFILE AS NVARCHAR(MAX))            AS ProcessChangeRecord,
    WIP020.DATE_S                                    AS ProductionStartDate,
    PCM030.ACAD                                      AS CadFile,

    -- 成本歸屬聯
    C.PCM03_NO                                       AS CostAttributionPartId,
    PCM030.SUB_NO3                                   AS CostAttributionPartNo,
    C.[NAME]                                         AS CostAttributionPartName,

    -- 通用
    ISNULL(CONVERT(BIT, CASE WHEN PCM030.DEL_MARK = 'Y' THEN 1 ELSE 0 END), 0) AS DeleteFlag,
    PCM030.[TIMESTAMP]                               AS RecordTimestamp,
    PCM030.DATE7                                     AS CreatedDate,
    PCM030.[UTIME]                                   AS LastModifiedTime

FROM [<<MAINDB>>].dbo.PCM030
    INNER JOIN [<<MAINDB>>].dbo.SAL041                            ON PCM030.JOB_NO   = SAL041.ORDER_NO
                                                    AND SAL041.DEL_MARK = 'N'
                                                    AND SAL041.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].dbo.PCM010                             ON PCM030.DIE_NO   = PCM010.DIE_NO   AND PCM010.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].[Production].[PartGroup]        PG     ON PCM030.TYPE9    = PG.PartGroupId
    LEFT JOIN [<<MAINDB>>].[Production].[PartStatus]       PS     ON PCM030.TYPE7    = PS.PartStatusId
    LEFT JOIN [<<MAINDB>>].[Production].[InventoryItem]    P      ON PCM030.PART_NO  = P.Id
    LEFT JOIN [<<MAINDB>>].[Purchasing].[Vendor]           V      ON PCM030.SUPPLIER = V.VendorName
    LEFT JOIN [<<MAINDB>>].[Production].[Unit]             U      ON PCM030.UNIT     = U.UnitName
    LEFT JOIN [<<MAINDB>>].[Production].[MaterialType]     M      ON PCM030.MTRL     = M.MaterialName
    LEFT JOIN [<<MAINDB>>].[Production].[PartType]         PT     ON PCM030.TYPE1    = PT.PartTypeName       AND PT.DeleteFlag = 0
    LEFT JOIN [<<MAINDB>>].[Production].[ProductionReason] PR     ON PCM030.TYPE3    = PR.ProductionReasonName
    LEFT JOIN [<<MAINDB>>].[Production].[SourceType]       S      ON PCM030.PURCH_YN = S.SourceTypeName      AND S.DeleteFlag  = 0
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee]     PPER010 ON PCM030.EMP_NAME = PPER010.EmployeeName  AND PPER010.DeleteFlag = 0
    LEFT JOIN (
        SELECT JOB_NO, DIE_NO, SUB_NO, MIN(DATE_S) AS DATE_S
        FROM [<<MAINDB>>].dbo.WIP020
        WHERE DEL_MARK = 'N'
        GROUP BY JOB_NO, DIE_NO, SUB_NO
    )                                          WIP020 ON PCM030.JOB_NO  = WIP020.JOB_NO
                                                     AND PCM030.DIE_NO  = WIP020.DIE_NO
                                                     AND PCM030.SUB_NO  = WIP020.SUB_NO
    LEFT JOIN [<<MAINDB>>].dbo.PCM030                       C      ON PCM030.JOB_NO  = C.JOB_NO
                                                     AND PCM030.SUB_NO  = C.SUB_NO2
                                                     AND C.DEL_MARK     = 'N'
WHERE PCM030.DEL_MARK = 'N';

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令零件寬表 View（PCM030 + 維度展平）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件ID (PCM03_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'Id';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單編號 (JOB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號 (SUB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'圖號 (DWG_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'DrawingNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'版次 (VERSION)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'Version';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'Quantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工尺寸 (SPECF1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'MachiningSpec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'素材尺寸 (SPECF2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialSpec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'設計完成日 (DATE0)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'DesignCompletionDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'EBOM零件號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'EBomPartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質名稱 (MTRL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartTypeCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件類別名稱 (TYPE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件群組ID (TYPE9)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartGroupId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件群組名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartGroupName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料來源ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'SourceTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料來源代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'SourceTypeCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料來源名稱 (PURCH_YN)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'SourceTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'供應商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'VendorId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'供應商簡稱 (SUPPLIER)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'VendorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'實際採購日 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PurchasedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠內備品數量 (SPARE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'InternalSpareQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶備品數量 (SPARE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'CustomerSpareQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材料重量 KG (WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialWeight';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'估計材料費 (AMT_M)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'EstimatedMaterialCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'需加工 (TYPE_1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'IsNeedProcessing';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包 (TYPE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'IsOutsource';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'進料檢 (QC_MARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'IsMaterialInspectionNeeded';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'UnitId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位名稱 (UNIT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'UnitName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'庫存料號ID (PART_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'InventoryItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'庫存料名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'InventoryItemName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'入庫數量 (QTY4)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'WarehouseQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製作原因ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'ProductionReasonId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製作原因名稱 (TYPE3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'ProductionReasonName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'進度指標零件 (PART_INDEX)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'IsProcessingStepIndex';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'已完工 (OK_FLG)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'IsConfirmed';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件狀態ID (TYPE7)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartStatusId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報廢數量 (QTY3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'ScrapQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'結案日 (CLOSING)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'ClosureDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最早開工日 (DATE4)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'EarliestStartDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最遲完工日 (DATE5)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'LatestEndDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'上層零件號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'ParentPartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'優先等級', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'Priority';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生管人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生管人員姓名 (EMP_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程狀態代碼 (ACK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessCheckCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessCheckName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程確認時間 (ACK_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessCheckTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程變更記錄 (APPFILE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessChangeRecord';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'開工日 (WIP020 最早 DATE_S)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'ProductionStartDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'圖檔路徑 (PCM030.ACAD)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'CadFile';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成本歸屬聯零件ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'CostAttributionPartId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成本歸屬聯零件號 (SUB_NO3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'CostAttributionPartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成本歸屬聯零件名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'CostAttributionPartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件建檔日 (DATE7)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'CreatedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderPartRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO

-- ---------- Views/WorkOrderProcessRowDataView.sql ----------
CREATE VIEW [Reporting].[WorkOrderProcessRowDataView]
AS
SELECT
    PSS022.PSS02_NO                                  AS ProcessId,
    SAL041.SAL04_NO                                  AS SalesOrderId,
    PSS022.JOB_NO                                    AS SalesOrderNo,
    CAST(SAL041.REMARK AS NVARCHAR(MAX))             AS [Description],
    PCM010.PCM01_NO                                  AS MoldId,
    PCM010.DIE_NO                                    AS MoldNo,
    PCM010.DIE_NAME                                  AS MoldName,
    PSS022.PCM03_NO                                  AS PartId,
    PCM030.SUB_NO                                    AS PartNo,
    PCM030.[NAME]                                    AS PartName,
    PSS022.SR_NO                                     AS ProcessSequence,
    PSS010.MD_NO                                     AS ProcessTypeId,
    PSS010.MD_NA                                     AS ProcessTypeName,
    PSS022.TIME1                                     AS EstimatedTimeHr,
    PSS022.TIME2                                     AS PastAccumulatedTimeHr,
    CASE
        WHEN ISNULL(PSS022.TIME1, 0) - ISNULL(PSS022.TIME2, 0) < 0 THEN 0
        ELSE ISNULL(PSS022.TIME1, 0) - ISNULL(PSS022.TIME2, 0)
    END                                              AS EstRemainingTime,
    PSS022.DATE1                                     AS ScheduledStartDate,
    PSS022.DATE2                                     AS ScheduledCompleteDate,
    PSS022.DATE3                                     AS ActualStartDate,
    PSS022.DATE4                                     AS ActualCompleteDate,
    PSS022.OUTSOURCE                                 AS IsOutsourced,
    PSS022.[DAYS]                                    AS EstimatedOutsourcingDays,
    PUR010.CUST_NO                                   AS OutsourceVendorId,
    PSS022.COMP                                      AS OutsourceVendorName,
    DefaultVendor.CUST_NO                            AS DefaultVendorId,
    PSS022.SET_COMP                                  AS DefaultVendorName,
    PSS022.QTY3                                      AS OutsourcedQuantity,
    PSS022.GROUP1                                    AS MachineGroup,
    PSS022.QTY1                                      AS PartQuantity,
    PSS022.QTY2                                      AS CompletedQuantity,
    PSS022.AMT1                                      AS EstimatedCost,
    PSS022.ME_QTY                                    AS FitterCount,
    PSS022.MD_TYPE                                   AS IsAbnormalProcess,
    ISNULL(CONVERT(BIT, CASE WHEN PSS022.OK_FLG = 'Y' THEN 1 ELSE 0 END), 0) AS IsCompleted,
    ISNULL(CONVERT(BIT, CASE WHEN PSS022.ASSIGN = 'Y' THEN 1 ELSE 0 END), 0) AS IsAssigned,
    PSS022.OK_RATE                                   AS CompletionRate,
    PSS022.STATUS                                    AS ProcessStatusId,
    ProcessStatus.ProcessStatusName                  AS ProcessStatusName,
    PSS022.WIP05_NO                                  AS AbnormalOrderNo,
    -- 機台 (PSS050) / 工作站 (ProcessExt)
    PSS022.ME_NO                                     AS MachineId,
    PSS050.DISCRIBE                                  AS MachineName,
    ProcessExt.WorkstationId                         AS WorkstationId,
    ProcessExt.RelationProcessTypeId                 AS RelationProcessTypeId,
    ProcessExt.IsDesignProcessType                   AS IsDesignProcessType,
    -- 設計工別關聯：當 IsDesignProcessType=1 時取 PartExt.DependentProcessId
    CASE WHEN ProcessExt.IsDesignProcessType = 1 THEN R_PartExt.DependentProcessId ELSE NULL END AS RelationProcessId,
    -- 下一個製程（依 PCM03_NO + SR_NO ASC 取下一筆）
    NXT.NextProcessId                                AS NextProcessId,
    NXT.NextProcessTypeId                            AS NextProcessTypeId,
    NXT_PT.MD_NA                                     AS NextProcessTypeName,
    NXT.NextProcessSequence                          AS NextProcessSequence,
    NXT.NextProcessStatusId                          AS NextProcessStatusId,
    -- 相依零件統計（per 製程，當 IsDesignProcessType=1 時有意義）
    ISNULL(DPS.DependentPartTotalCount, 0)           AS DependentPartTotalCount,
    ISNULL(DPS.DependentPartCompletedCount, 0)       AS DependentPartCompletedCount,
    CONVERT(BIT, CASE WHEN AWP.ProcessId IS NOT NULL THEN 1 ELSE 0 END) AS IsArrived,
    ProcessExt.ArrivalTime                           AS ArrivalTime,
    D_PCM030.PCM03_NO                                AS DependentPartId,
    D_PCM030.SUB_NO                                  AS DependentPartNo,
    D_PCM030.[NAME]                                  AS DependentPartName,
    PSS022.REMARK                                    AS Remark,
    CAST(PSS022.REMARK1 AS NVARCHAR(MAX))            AS ProcessingDescription,
    -- 最新一筆報工（per ProcessId，由 LatestWorkReport 派生欄位帶入）
    LWR.MODE                                         AS LatestWorkMode,
    LWR.EMP_NO                                       AS LatestWorkerEmployeeId,
    LWR_EMP.EmployeeName                             AS LatestWorkerEmployeeName,
    CASE
        WHEN LWR.DATE_S IS NOT NULL AND LWR.DATE_E IS NULL
             AND LTRIM(RTRIM(LWR.TIME_S)) <> ''
             AND LWR.TIME_S LIKE '[0-9][0-9]:[0-9][0-9]'
        THEN CAST(CAST(LWR.DATE_S AS DATE) AS DATETIME) + CAST(LWR.TIME_S + ':00' AS DATETIME)
        ELSE NULL
    END                                              AS LatestWorkStartedTime,
    CASE
        WHEN LWR.DATE_S IS NOT NULL AND LWR.DATE_E IS NOT NULL AND LWR.MODE = 'C'
             AND LTRIM(RTRIM(LWR.TIME_E)) <> ''
             AND LWR.TIME_E LIKE '[0-9][0-9]:[0-9][0-9]'
        THEN CAST(CAST(LWR.DATE_E AS DATE) AS DATETIME) + CAST(LWR.TIME_E + ':00' AS DATETIME)
        ELSE NULL
    END                                              AS LatestWorkPausedTime,
    CASE
        WHEN LWR.DATE_S IS NOT NULL AND LWR.DATE_E IS NOT NULL AND LWR.MODE = 'B'
             AND LTRIM(RTRIM(LWR.TIME_E)) <> ''
             AND LWR.TIME_E LIKE '[0-9][0-9]:[0-9][0-9]'
        THEN CAST(CAST(LWR.DATE_E AS DATE) AS DATETIME) + CAST(LWR.TIME_E + ':00' AS DATETIME)
        ELSE NULL
    END                                              AS LatestWorkCompletedTime,
    ISNULL(CONVERT(BIT, CASE WHEN PSS022.DEL_MARK = 'Y' THEN 1 ELSE 0 END), 0) AS DeleteFlag,
    PSS022.[TIMESTAMP]                               AS RecordTimestamp,
    PSS022.DATE5                                     AS CreatedDate,
    PSS022.UTIME                                     AS LastModifiedTime
FROM [<<MAINDB>>].dbo.PSS022
    INNER JOIN [<<MAINDB>>].dbo.SAL041                                ON PSS022.JOB_NO   = SAL041.ORDER_NO
                                                        AND SAL041.DEL_MARK = 'N'
                                                        AND SAL041.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].dbo.PCM030                                 ON PSS022.PCM03_NO = PCM030.PCM03_NO        AND PCM030.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.PCM010                                 ON PCM030.DIE_NO   = PCM010.DIE_NO          AND PCM010.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.PSS010                                 ON PSS022.MD_NO    = PSS010.MD_NO
                                                        AND PSS010.DEL_MARK = 'N'
                                                        AND PSS010.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].dbo.PUR010                                 ON PSS022.COMP     = PUR010.SUBNAME         AND PUR010.DEL_MARK = 'N' AND PSS022.COMP <> ''
    LEFT JOIN [<<MAINDB>>].dbo.PUR010                  DefaultVendor  ON PSS022.SET_COMP = DefaultVendor.SUBNAME  AND DefaultVendor.DEL_MARK = 'N' AND PSS022.SET_COMP <> ''
    LEFT JOIN [<<MAINDB>>].[Production].[ProcessStatus]               ON PSS022.STATUS   = ProcessStatus.ProcessStatusCode
    LEFT JOIN [<<MAINDB>>].[Production].[ArrivedWorkpieceProcesses] AWP ON PSS022.PSS02_NO = AWP.ProcessId
    LEFT JOIN [<<MAINDB>>].[Production].[ProcessExt]                  ON PSS022.PSS02_NO = ProcessExt.ProcessId
    LEFT JOIN [<<MAINDB>>].[Production].[PartExt]      D_PartExt      ON PSS022.PSS02_NO = D_PartExt.DependentProcessId
    LEFT JOIN [<<MAINDB>>].dbo.PCM030                  D_PCM030       ON D_PartExt.PartId = D_PCM030.PCM03_NO     AND D_PCM030.DEL_MARK = 'N'
    -- 機台主檔
    LEFT JOIN [<<MAINDB>>].dbo.PSS050                                 ON PSS022.ME_NO    = PSS050.ME_NO           AND PSS050.DEL_MARK = 'N'
    -- 設計工別關聯：當前製程的 Part 在 PartExt 上記載的 DependentProcessId（取一筆）
    OUTER APPLY (
        SELECT TOP 1 PE.DependentProcessId
        FROM [<<MAINDB>>].[Production].[PartExt] PE
        WHERE PE.PartId = PSS022.PCM03_NO AND PE.DependentProcessId IS NOT NULL
    ) R_PartExt
    -- 下一個製程（per PCM03_NO 依 SR_NO ASC 取 next）
    OUTER APPLY (
        SELECT TOP 1
            NX.PSS02_NO AS NextProcessId,
            NX.MD_NO    AS NextProcessTypeId,
            NX.SR_NO    AS NextProcessSequence,
            NX.STATUS   AS NextProcessStatusId
        FROM [<<MAINDB>>].dbo.PSS022 NX
        WHERE NX.PCM03_NO = PSS022.PCM03_NO
          AND NX.SR_NO    > PSS022.SR_NO
          AND NX.DEL_MARK = 'N'
        ORDER BY NX.SR_NO ASC
    ) NXT
    LEFT JOIN [<<MAINDB>>].dbo.PSS010                  NXT_PT         ON NXT.NextProcessTypeId = NXT_PT.MD_NO     AND NXT_PT.DEL_MARK = 'N'
    -- 相依零件統計（per 設計工別製程）
    OUTER APPLY (
        SELECT
            COUNT(DISTINCT PE.PartId)                            AS DependentPartTotalCount,
            SUM(CASE WHEN P.OK_FLG = 'Y' THEN 1 ELSE 0 END)      AS DependentPartCompletedCount
        FROM [<<MAINDB>>].[Production].[PartExt] PE
            INNER JOIN [<<MAINDB>>].dbo.PCM030 P ON PE.PartId = P.PCM03_NO    AND P.DEL_MARK = 'N'
        WHERE PE.DependentProcessId = PSS022.PSS02_NO
    ) DPS
    -- 最新一筆 WIP020 報工（per PSS02_NO，依 DATE_S+TIME_S DESC）
    OUTER APPLY (
        SELECT TOP 1 W.EMP_NO, W.DATE_S, W.DATE_E, W.TIME_S, W.TIME_E, W.MODE
        FROM [<<MAINDB>>].dbo.WIP020 W
        WHERE W.PSS02_NO = PSS022.PSS02_NO AND W.DEL_MARK = 'N'
        ORDER BY W.DATE_S DESC, W.TIME_S DESC
    ) LWR
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee] LWR_EMP ON LWR.EMP_NO = LWR_EMP.EmployeeId AND LWR_EMP.DeleteFlag = 0
WHERE PSS022.DEL_MARK = 'N';

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令零件製程寬表 View（PSS022 + 維度展平）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程ID (PSS02_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單編號 (JOB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'主要內容 (SAL041.REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'Description';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'PartId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程順序 (SR_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessSequence';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別ID (MD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱 (PSS010.MD_NA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預估工時 (TIME1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'EstimatedTimeHr';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'過去累積時間 (TIME2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'PastAccumulatedTimeHr';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'均衡估計剩餘時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'EstRemainingTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預計開始 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ScheduledStartDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預計完成 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ScheduledCompleteDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'實際開工 (DATE3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ActualStartDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'實際完工 (DATE4)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ActualCompleteDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否外包 (OUTSOURCE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'IsOutsourced';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預估外包天數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'EstimatedOutsourcingDays';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包廠商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'OutsourceVendorId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包廠商 (COMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'OutsourceVendorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預設廠商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'DefaultVendorId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預設廠商 (SET_COMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'DefaultVendorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包數量 (QTY3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'OutsourcedQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機器群組 (GROUP1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'MachineGroup';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'PartQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完成數量 (QTY2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'CompletedQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預估金額 (AMT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'EstimatedCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'鉗工人數 (ME_QTY)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'FitterCount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'異常增加製程 (MD_TYPE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'IsAbnormalProcess';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'已完工 (OK_FLG)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'IsCompleted';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'已派工 (ASSIGN)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'IsAssigned';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完工率 (OK_RATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'CompletionRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程狀態ID (STATUS)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessStatusId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'異常單號 (WIP05_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'AbnormalOrderNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台ID (PSS022.ME_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'MachineId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台名稱 (PSS050.DISCRIBE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'MachineName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽收工作站ID (ProcessExt.WorkstationId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'WorkstationId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'關聯設計製程ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'RelationProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'設計工別關聯後置製程ID (PartExt.DependentProcessId)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'RelationProcessId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'下一個製程ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'NextProcessId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'下一個製程工別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'NextProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'下一個製程工別名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'NextProcessTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'下一個製程順序', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'NextProcessSequence';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'下一個製程狀態', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'NextProcessStatusId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'相依零件總數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'DependentPartTotalCount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'相依零件完工數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'DependentPartCompletedCount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否為設計製程', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'IsDesignProcessType';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'已到站', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'IsArrived';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'到站時間 (ProcessExt.ArrivalTime)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ArrivalTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'相依零件ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'DependentPartId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'相依零件編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'DependentPartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'相依零件名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'DependentPartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工說明 (REMARK1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessingDescription';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新一筆報工 MODE (B=完工 / C=暫停 / 其他=開工中)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'LatestWorkMode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新一筆報工人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'LatestWorkerEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新一筆報工人員姓名', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'LatestWorkerEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新報工開工時間 (DATE_S+TIME_S，DATE_E IS NULL 時)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'LatestWorkStartedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新報工暫停時間 (DATE_E+TIME_E，MODE=C 時)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'LatestWorkPausedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最新報工完工時間 (DATE_E+TIME_E，MODE=B 時)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'LatestWorkCompletedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'建檔日期 (DATE5)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'CreatedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkOrderProcessRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO

-- ---------- Views/WorkRecordRowDataView.sql ----------
CREATE VIEW [Reporting].[WorkRecordRowDataView]
AS
SELECT
    WIP020.WIP02_NO                                  AS WorkRecordId,
    SAL041.SAL04_NO                                  AS SalesOrderId,
    WIP020.JOB_NO                                    AS SalesOrderNo,
    PCM010.PCM01_NO                                  AS MoldId,
    WIP020.DIE_NO                                    AS MoldNo,
    PCM010.DIE_NAME                                  AS MoldName,
    WIP020.PCM03_NO                                  AS PartId,
    WIP020.SUB_NO                                    AS PartNo,
    PCM030.[NAME]                                    AS PartName,
    WIP020.PSS02_NO                                  AS ProcessId,
    WIP020.SR_NO                                     AS ProcessSequence,
    WIP020.MD_NO                                     AS ProcessTypeId,
    PSS010.MD_NA                                     AS ProcessTypeName,
    WIP020.MODE                                      AS WorkStatusCode,
    CASE WIP020.MODE
        WHEN N'A' THEN N'開工中'
        WHEN N'B' THEN N'完工'
        WHEN N'C' THEN N'暫停'
        ELSE N''
    END                                              AS WorkStatusName,
    WIP020.PR_STATUS                                 AS ProcessStatusSnapshotCode,
    WIP020.PR_RATE                                   AS ProcessRateSnapshot,
    CASE WHEN LTRIM(RTRIM(WIP020.APP_NO)) = '' OR WIP020.APP_NO IS NULL THEN N'WIP020'
         ELSE WIP020.APP_NO END                      AS WorkReportSourceCode,
    WIP020.MODE1                                     AS WorkReportTypeCode,
    WIP020.TYP1                                      AS ShiftCode,
    CONVERT(BIT, CASE WHEN WIP020.MAIN_JOB = 'Y' THEN 1 ELSE 0 END) AS IsMainJob,
    CASE
        WHEN WIP020.DATE_S IS NULL THEN NULL
        WHEN LTRIM(RTRIM(WIP020.TIME_S)) = '' OR WIP020.TIME_S IS NULL THEN WIP020.DATE_S
        ELSE CAST(CAST(WIP020.DATE_S AS DATE) AS DATETIME) + CAST(LTRIM(RTRIM(WIP020.TIME_S)) AS DATETIME)
    END                                              AS WorkStartTime,
    CASE
        WHEN WIP020.DATE_E IS NULL THEN NULL
        WHEN LTRIM(RTRIM(WIP020.TIME_E)) = '' OR WIP020.TIME_E IS NULL THEN WIP020.DATE_E
        ELSE CAST(CAST(WIP020.DATE_E AS DATE) AS DATETIME) + CAST(LTRIM(RTRIM(WIP020.TIME_E)) AS DATETIME)
    END                                              AS WorkEndTime,
    WIP020.R_START                                   AS SystemStartTime,
    WIP020.R_END                                     AS SystemEndTime,
    WIP020.P_DATE_E                                  AS PlannedEndDate,
    WIP020.TIMES                                     AS ElapsedHours,
    WIP020.TIME2                                     AS MachineOccupiedHours,
    WIP020.TIME3                                     AS ManualEffectiveHours,
    WIP020.TIME_MA                                   AS MachineNetworkHours,
    WIP020.TIME2B                                    AS AdjustedHours,
    WIP020.T_WEIGHT                                  AS TimeWeight,
    WIP020.QTY2                                      AS CompletedQuantity,
    WIP020.RATE                                      AS CompletionRate,
    WIP020.T_WEIGHT                                  AS TotalWeight,
    WIP020.QC_MARK                                   AS QualityStatusCode,
    CASE WIP020.QC_MARK
        WHEN N'V' THEN N'良品'
        WHEN N'X' THEN N'不良'
        ELSE N''
    END                                              AS QualityStatusName,
    WIP020.QC_QTY1                                   AS QcGoodQuantity,
    WIP020.QC_QTY2                                   AS QcDefectQuantity,
    WIP020.QC_QTY3                                   AS QcReviewQuantity,
    CAST(WIP020.QCREMARK AS NVARCHAR(MAX))           AS QcRemark,
    WIP020.EMP_NO                                    AS WorkerEmployeeId,
    W_EMP.EmployeeName                               AS WorkerEmployeeName,
    WIP020.EMP_NO2                                   AS CoWorkerEmployeeIds,
    WIP020.ME_NO                                     AS MachineId,
    PSS050.DISCRIBE                                  AS MachineName,
    COALESCE(PSS055.AMT, PSS050.AMT1)                AS ProcessingRate,
    WIP020.APPROVE                                   AS ApproverEmployeeId,
    A_EMP.EmployeeName                               AS ApproverEmployeeName,
    WIP020.D_APPROVE                                 AS ApprovedTime,
    WIP020.HAS_TMA                                   AS IsMachineTimeComputed,
    WIP020.MA_ADDED                                  AS IsMachineTimeAccumulated,
    WIP020.REWORK                                    AS RepairReasonCode,
    CAST(WIP020.REMARK AS NVARCHAR(MAX))             AS Remark,
    ISNULL(CONVERT(BIT, CASE WHEN WIP020.DEL_MARK = 'Y' THEN 1 ELSE 0 END), 0) AS DeleteFlag,
    WIP020.[TIMESTAMP]                               AS RecordTimestamp,
    WIP020.UTIME                                     AS LastModifiedTime
FROM [<<MAINDB>>].dbo.WIP020
    INNER JOIN [<<MAINDB>>].dbo.SAL041                            ON WIP020.JOB_NO   = SAL041.ORDER_NO
                                                    AND SAL041.DEL_MARK = 'N'
                                                    AND SAL041.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].dbo.PCM030                             ON WIP020.PCM03_NO = PCM030.PCM03_NO    AND PCM030.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.PCM010                             ON WIP020.DIE_NO   = PCM010.DIE_NO      AND PCM010.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.PSS010                             ON WIP020.MD_NO    = PSS010.MD_NO       AND PSS010.DEL_MARK = 'N' AND PSS010.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee] W_EMP      ON WIP020.EMP_NO   = W_EMP.EmployeeId   AND W_EMP.DeleteFlag = 0
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee] A_EMP      ON WIP020.APPROVE  = A_EMP.EmployeeId   AND A_EMP.DeleteFlag = 0
    LEFT JOIN [<<MAINDB>>].dbo.PSS050                             ON WIP020.ME_NO    = PSS050.ME_NO       AND PSS050.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.PSS055                             ON WIP020.ME_NO    = PSS055.ME_NO       AND PSS055.DEL_MARK = 'N'
                                                    AND PSS055.YYMM    = CONVERT(CHAR(6), WIP020.DATE_S, 112)
WHERE WIP020.DEL_MARK = 'N';

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工記錄寬表 View（WIP020 + 維度展平）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工ID (WIP02_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'WorkRecordId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單編號 (JOB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'PartId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程順序 (SR_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessSequence';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別ID (MD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工狀態代碼 (MODE): A=開工中 / B=完工 / C=暫停', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'WorkStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'WorkStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程狀態快照 (PR_STATUS)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessStatusSnapshotCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程合格率快照 (PR_RATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessRateSnapshot';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工來源 (APP_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'WorkReportSourceCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工類型 (MODE1，WIP391)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'WorkReportTypeCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'班別 (TYP1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ShiftCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'主報工 (MAIN_JOB)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'IsMainJob';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工開始 (DATE_S+TIME_S 合併)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'WorkStartTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工結束 (DATE_E+TIME_E 合併)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'WorkEndTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'系統開工 (R_START)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'SystemStartTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'系統停工 (R_END)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'SystemEndTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預計結束 (P_DATE_E)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'PlannedEndDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'總經過時間 (TIMES)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ElapsedHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台佔用工時 (TIME2 × T_WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'MachineOccupiedHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'人工有效工時 (TIME3 × T_WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ManualEffectiveHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機聯網機台工時 (TIME_MA × T_WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'MachineNetworkHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'調整工時 (TIME2B)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'AdjustedHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'多工件工時權重 (T_WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'TimeWeight';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完成數量 (QTY2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'CompletedQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完成率 (RATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'CompletionRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'總重量', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'TotalWeight';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品檢狀態 (QC_MARK): V=良 / X=不良 / 空=不適用', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'QualityStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品檢狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'QualityStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'良品數 (QC_QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'QcGoodQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'不良數 (QC_QTY2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'QcDefectQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備查數 (QC_QTY3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'QcReviewQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品檢備註', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'QcRemark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工人員ID (EMP_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'WorkerEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工人員姓名', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'WorkerEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'協作人員ID列表 (EMP_NO2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'CoWorkerEmployeeIds';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台ID (ME_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'MachineId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台名稱 (PSS050.DISCRIBE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'MachineName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工費率：優先取 PSS055 當月費率，無則 fallback PSS050.AMT1', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessingRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核人員ID (APPROVE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ApproverEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核人員姓名', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ApproverEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核時間 (D_APPROVE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'ApprovedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台工時已計算 (HAS_TMA)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'IsMachineTimeComputed';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機台工時已累加 (MA_ADDED)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'IsMachineTimeAccumulated';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'重工原因 (REWORK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'RepairReasonCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報工備註 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'WorkRecordRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO

-- ---------- Views/MoldRowDataView.sql ----------
CREATE VIEW [Reporting].[MoldRowDataView]
AS
SELECT
    PCM010.PCM01_NO                                  AS MoldId,
    PCM010.DIE_NO                                    AS MoldNo,
    PCM010.DIE_NAME                                  AS MoldName,
    PCM010.YM_NAME                                   AS InternalMoldName,
    PCM010.DIETYPE                                   AS ProductType,
    PCM010.MODEL                                     AS ModelNumber,
    PCM010.PROD_NO                                   AS ProductId,
    PCM010.DIE_SOURCE                                AS MoldSourceTypeId,
    MoldSourceType.MoldSourceTypeName                AS MoldSourceTypeName,
    PCM010.PHOTO                                     AS PhotoPath,
    PCM010.EDITION                                   AS CustomVersion,
    PCM010.DATE1                                     AS MoldDate,
    PCM010.DATE2                                     AS MassProductionDate,
    PCM010.T1_DATE                                   AS T1TrialDate,
    PCM010.T_DATE                                    AS TrialDate,
    PCM010.POOP_DATE                                 AS ScrapDate,
    PCM010.CUST_NO                                   AS CustomerId,
    SAL010.SUBNAME                                   AS CustomerSubname,
    Designer.EmployeeId                              AS DesignerEmployeeId,
    PCM010.DESIGNER                                  AS DesignerEmployeeName,
    Assembler.EmployeeId                             AS AssemblerEmployeeId,
    PCM010.NAME2                                     AS AssemblerEmployeeName,
    MoldingOperator.EmployeeId                       AS MoldingOperatorEmployeeId,
    PCM010.BROKER                                    AS MoldingOperatorEmployeeName,
    ProductionPlanner.EmployeeId                     AS PlannerEmployeeId,
    PCM010.NAME3                                     AS PlannerEmployeeName,
    CONVERT(DECIMAL(18, 2), CASE WHEN ISNUMERIC(PCM010.TON)  = 0 THEN 0 ELSE PCM010.TON  END) AS MachineMinTon,
    CONVERT(DECIMAL(18, 2), CASE WHEN ISNUMERIC(PCM010.TON2) = 0 THEN 0 ELSE PCM010.TON2 END) AS MachineMaxTon,
    PCM010.C_CAV                                     AS CavityCount,
    PCM010.WEIGHT                                    AS MoldWeight,
    PCM010.SHRINK_X                                  AS ShrinkageRateX,
    PCM010.AMT1                                      AS AverageThickness,
    FixedCoreInsertMaterial.MaterialId               AS FixedCoreInsertMaterialId,
    PCM010.INSERT1                                   AS FixedCoreInsertMaterialName,
    MovableCoreInsertMaterial.MaterialId             AS MovableCoreInsertMaterialId,
    PCM010.INSERT2                                   AS MovableCoreInsertMaterialName,
    MoldBaseMaterial.MaterialId                      AS MoldBaseMaterialId,
    PCM010.BASE                                      AS MoldBaseMaterialName,
    PCM010.BASE_HD                                   AS MoldBaseHardness,
    ProductMaterial.MaterialId                       AS ProductMaterialId,
    PCM010.PROD_MTRL                                 AS ProductMaterialName,
    CAST(PCM010.REMARK AS NVARCHAR(MAX))             AS ProductNotes,
    MoldExt.IsBomRequired                            AS IsBomRequired,
    ISNULL(CONVERT(BIT, CASE WHEN OPENORD.DIE_NO IS NULL THEN 1 ELSE 0 END), 1) AS IsUnassigned,
    ISNULL(CONVERT(BIT, OPENORD.HasIncompleteOrder), 0)                          AS IsOrderIncomplete,
    ISNULL(CONVERT(BIT, CASE WHEN PCM010.DEL_MARK = 'Y' THEN 1 ELSE 0 END), 0)  AS DeleteFlag,
    PCM010.[TIMESTAMP]                               AS RecordTimestamp,
    PCM010.UTIME                                     AS LastModifiedTime
FROM [<<MAINDB>>].dbo.PCM010
    LEFT JOIN [<<MAINDB>>].dbo.SAL010                                          ON PCM010.CUST_NO    = SAL010.CUST_NO              AND SAL010.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].[Production].[MoldSourceType]    MoldSourceType     ON PCM010.DIE_SOURCE = MoldSourceType.MoldSourceTypeId
    LEFT JOIN [<<MAINDB>>].[Production].[MaterialType]      FixedCoreInsertMaterial   ON PCM010.INSERT1   = FixedCoreInsertMaterial.MaterialName
    LEFT JOIN [<<MAINDB>>].[Production].[MaterialType]      MovableCoreInsertMaterial ON PCM010.INSERT2   = MovableCoreInsertMaterial.MaterialName
    LEFT JOIN [<<MAINDB>>].[Production].[MaterialType]      MoldBaseMaterial          ON PCM010.BASE      = MoldBaseMaterial.MaterialName
    LEFT JOIN [<<MAINDB>>].[Production].[MaterialType]      ProductMaterial           ON PCM010.PROD_MTRL = ProductMaterial.MaterialName
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee]      Designer            ON PCM010.DESIGNER = Designer.EmployeeName            AND Designer.DeleteFlag          = 0
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee]      Assembler           ON PCM010.NAME2    = Assembler.EmployeeName           AND Assembler.DeleteFlag         = 0
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee]      MoldingOperator     ON PCM010.BROKER   = MoldingOperator.EmployeeName     AND MoldingOperator.DeleteFlag   = 0
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee]      ProductionPlanner   ON PCM010.NAME3    = ProductionPlanner.EmployeeName   AND ProductionPlanner.DeleteFlag = 0
    LEFT JOIN [<<MAINDB>>].[Design].[MoldExt]               MoldExt             ON PCM010.PCM01_NO = MoldExt.MoldId
    LEFT JOIN (
        SELECT SAL041.DIE_NO,
               MAX(CASE WHEN SAL041.OK_FLG IN ('', 'T') THEN 1 ELSE 0 END) AS HasIncompleteOrder
        FROM [<<MAINDB>>].dbo.SAL041
        WHERE SAL041.DEL_MARK = 'N'
          AND SAL041.OK_FLG IN ('Y', 'P', 'T', 'K', '', ' ')
        GROUP BY SAL041.DIE_NO
    )                                          OPENORD             ON PCM010.DIE_NO   = OPENORD.DIE_NO
WHERE PCM010.DEL_MARK = 'N';

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具寬表 View（PCM010 + 維度展平）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID (PCM01_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號 (DIE_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱 (DIE_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠內模名 (YM_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'InternalMoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品類型 (DIETYPE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'ProductType';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機種 (MODEL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'ModelNumber';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成品編號 (PROD_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'ProductId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具來源ID (DIE_SOURCE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldSourceTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具來源名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldSourceTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'圖檔位置 (PHOTO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'PhotoPath';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'自訂版本 (EDITION)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'CustomVersion';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'開模日期 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'量產日期 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MassProductionDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'T1 試模日期 (T1_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'T1TrialDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Tn 試模日期 (T_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'TrialDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報廢日期 (POOP_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'ScrapDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶ID (CUST_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'CustomerId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶簡稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'CustomerSubname';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'設計人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'DesignerEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'設計人員姓名 (DESIGNER)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'DesignerEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'組立人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'AssemblerEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'組立人員姓名 (NAME2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'AssemblerEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成型人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldingOperatorEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成型人員姓名 (BROKER)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldingOperatorEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生技人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'生技人員姓名 (NAME3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'PlannerEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機器噸數起 (TON)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MachineMinTon';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'機器噸數迄 (TON2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MachineMaxTon';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模穴數 (C_CAV)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'CavityCount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具重量 KG (WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldWeight';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'縮水率 % (SHRINK_X)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'ShrinkageRateX';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'平均肉厚 (AMT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'AverageThickness';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模仁固定材質ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'FixedCoreInsertMaterialId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模仁固定材質 (INSERT1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'FixedCoreInsertMaterialName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模仁移動材質ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MovableCoreInsertMaterialId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模仁移動材質 (INSERT2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MovableCoreInsertMaterialName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模座材質ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldBaseMaterialId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模座材質 (BASE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldBaseMaterialName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模座硬度 (BASE_HD)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'MoldBaseHardness';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品材質ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'ProductMaterialId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'產品材質 (PROD_MTRL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'ProductMaterialName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'成品備註 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'ProductNotes';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否需要 BOM', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'IsBomRequired';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具未被訂單引用', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'IsUnassigned';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具有未完成訂單 (OK_FLG IN (空,T))', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'IsOrderIncomplete';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO

-- ---------- Views/MoldPartRowDataView.sql ----------
CREATE VIEW [Reporting].[MoldPartRowDataView]
AS
SELECT
    PCM020.PCM02_SEQ                                 AS MoldPartId,
    PCM020.PCM01_NO                                  AS MoldId,
    PCM020.[NAME]                                    AS PartName,
    PCM020.ENG_NAME                                  AS PartNameEn,
    PCM020.SUB_NO                                    AS PartNo,
    PCM020.DWG_NO                                    AS DrawingNo,
    PCM020.EDITION                                   AS CustomVersion,
    PT.Id                                            AS PartTypeId,
    PT.PartTypeCode                                  AS PartTypeCode,
    PCM020.TYPE1                                     AS PartTypeName,
    CONVERT(BIT, CASE WHEN PCM020.TYPE2   = 'Y' THEN 1 ELSE 0 END) AS IsNeedProcessing,
    PR.ProductionReasonId                            AS ProductionReasonId,
    PCM020.TYPE3                                     AS ProductionReasonName,
    PCM020.SPECF1                                    AS MachiningSpec,
    PG.PartGroupId                                   AS PartGroupId,
    PCM020.TYPE9                                     AS PartGroupName,
    PCM020.SPECF2                                    AS MaterialSpec,
    S.Id                                             AS SourceTypeId,
    S.SourceTypeCode                                 AS SourceTypeCode,
    PCM020.PURCH_YN                                  AS SourceTypeName,
    M.MaterialId                                     AS MaterialId,
    PCM020.MTRL                                      AS MaterialName,
    PCM020.ACAD                                      AS CadFile,
    PCM020.PART_NO                                   AS InventoryItemId,
    PCM020.REMARK                                    AS Remark,
    PCM020.QTY1                                      AS Quantity,
    PCM020.[WEIGHT]                                  AS MaterialWeight,
    PCM020.SPARE                                     AS CustomerSpareQuantity,
    PCM020.SPARE2                                    AS InternalSpareQuantity,
    CONVERT(BIT, CASE WHEN PCM020.QC_MARK = 'Y' THEN 1 ELSE 0 END) AS IsMaterialInspectionNeeded,
    CONVERT(BIT, CASE WHEN PCM020.CAD_CHK = 'Y' THEN 1 ELSE 0 END) AS IsCadChecked,
    PCM020.DATE1                                     AS CreatedDate,
    PCM020.DATE2                                     AS PurchasedDate,
    PCM020.PRIORITY                                  AS Priority,
    PCM020.HARDNESS                                  AS HeatTreatmentHardness,
    V.VendorId                                       AS VendorId,
    PCM020.SUPPLIER                                  AS VendorName,
    MOD_EMP.EmployeeId                               AS LastModifiedEmployeeId,
    PCM020.MOD_NAME                                  AS LastModifiedEmployeeName,
    PCM020.MOD_DATE                                  AS ModifiedDate,
    ISNULL(CONVERT(BIT, CASE WHEN PCM020.DEL_MARK = 'Y' THEN 1 ELSE 0 END), 0) AS DeleteFlag,
    PCM020.[TIMESTAMP]                               AS RecordTimestamp,
    PCM020.UTIME                                     AS LastModifiedTime
FROM [<<MAINDB>>].dbo.PCM020
    LEFT JOIN [<<MAINDB>>].[Production].[MaterialType]     M                   ON PCM020.MTRL     = M.MaterialName
    LEFT JOIN [<<MAINDB>>].[Production].[PartGroup]        PG                  ON PCM020.TYPE9    = PG.PartGroupName
    LEFT JOIN [<<MAINDB>>].[Production].[PartType]         PT                  ON PCM020.TYPE1    = PT.PartTypeName        AND PT.DeleteFlag = 0
    LEFT JOIN [<<MAINDB>>].[Production].[ProductionReason] PR                  ON PCM020.TYPE3    = PR.ProductionReasonName
    LEFT JOIN [<<MAINDB>>].[Production].[SourceType]       S                   ON PCM020.PURCH_YN = S.SourceTypeName       AND S.DeleteFlag  = 0
    LEFT JOIN [<<MAINDB>>].[Purchasing].[Vendor]           V                   ON PCM020.SUPPLIER = V.VendorName
    LEFT JOIN [<<MAINDB>>].[HumanResources].[Employee]     MOD_EMP             ON PCM020.MOD_NAME = MOD_EMP.EmployeeName   AND MOD_EMP.DeleteFlag = 0
WHERE PCM020.DEL_MARK = 'N';

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具零件寬表 View（PCM020 + 維度展平，依 PCM010E 畫面欄位）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具零件ID (PCM02_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'MoldPartId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID (隱含 FK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品名 (NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'英文品名 (ENG_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartNameEn';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號 (SUB_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'圖號 (DWG_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'DrawingNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'版本 (EDITION)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'CustomVersion';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'類別ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'類別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartTypeCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'類別 (TYPE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'需加工 (TYPE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'IsNeedProcessing';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製作原因ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'ProductionReasonId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製作原因 (TYPE3)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'ProductionReasonName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工尺寸 (SPECF1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'MachiningSpec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件群組ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartGroupId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件群組名稱 (TYPE9)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'PartGroupName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'素材尺寸 (SPECF2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialSpec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料來源ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'SourceTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料來源代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'SourceTypeCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源 (PURCH_YN)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'SourceTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質 (MTRL)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'CAD檔名 (ACAD)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'CadFile';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'領用料號 (PART_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'InventoryItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註 (REMARK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 (QTY1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'Quantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'素材重量 (WEIGHT)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialWeight';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'客戶備品 (SPARE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'CustomerSpareQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠內備品 (SPARE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'InternalSpareQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'QC_MARK (進料檢驗)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'IsMaterialInspectionNeeded';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'資料確認 (CAD_CHK)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'IsCadChecked';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'建檔日期 (DATE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'CreatedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'採購日期 (DATE2)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'PurchasedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'優先等級', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'Priority';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理硬度 (HARDNESS)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'HeatTreatmentHardness';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'VendorId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商名稱 (SUPPLIER)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'VendorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'資料編修人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'資料編修 (MOD_NAME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'編修日期 (MOD_DATE)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'ModifiedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳 (TIMESTAMP)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後更新時間 (UTIME)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO

-- ---------- Views/PurchaseReceiveRowDataView.sql ----------
CREATE VIEW [Reporting].[PurchaseReceiveRowDataView]
AS
SELECT
    MTR022.MTR02_SEQ                                 AS PurchaseReceiveItemId,
    MTR021.MTR02_NO                                  AS PurchaseReceiveId,
    MTR021.NO                                        AS ReceiveNo,
    MTR022.PUR02_SEQ                                 AS PurchaseOrderItemId,
    MTR022.ITEM_NO                                   AS LineItemNo,

    MTR021.DATE1                                     AS ReceiveDate,
    MTR021.DLV_NO                                    AS DeliveryNo,
    MTR021.YM                                        AS AccountingMonth,
    MTR021.BIL_NO                                    AS CurrencyCode,
    MTR021.EXCHANGE                                  AS ExchangeRate,
    MTR021.INVOICE                                   AS InvoiceNo,
    MTR021.AMT1                                      AS HeaderSubtotal,
    MTR021.TAX                                       AS HeaderTax,
    MTR021.AMT2                                      AS HeaderTotalAmount,
    MTR021.R_TAX                                     AS TaxRate,
    MTR021.QC                                        AS ReceiverName,
    MTR021.APPROVE                                   AS ApproverEmployeeId,
    MTR021.APPRO_DATE                                AS ApprovedTime,

    MTR021.CUST_NO                                   AS VendorRawId,
    V.VendorId                                       AS VendorId,
    V.VendorName                                     AS VendorName,

    MTR022.JOB_NO                                    AS SalesOrderNo,
    SAL041.SAL04_NO                                  AS SalesOrderId,
    MTR022.DIE_NO                                    AS MoldNo,
    PCM010.PCM01_NO                                  AS MoldId,
    PCM010.DIE_NAME                                  AS MoldName,

    MTR022.PART_NO                                   AS InventoryItemId,
    MTR022.[NAME]                                    AS PartName,
    MTR022.SPECF                                     AS Spec,
    MTR022.MTRL                                      AS Material,
    MTR022.UNIT                                      AS Unit,
    MTR022.WEIGHT                                    AS Weight,

    MTR022.QTY1                                      AS Quantity,
    MTR022.AMT1                                      AS UnitPrice,
    MTR022.AMT2                                      AS Amount,
    MTR022.AMT_HR                                    AS ProcessingFee,
    MTR022.DISCOUNT                                  AS DiscountPercent,
    CONVERT(BIT, MTR022.AMT_N)                       AS IsFree,

    MTR022.MISTAKE                                   AS PurchaseReason,
    MTR022.QC_REMARK                                 AS Remark,

    MTR022.S_DELIVER                                 AS DeliveryStatusCode,
    CASE MTR022.S_DELIVER WHEN N'Y' THEN N'合格如期' WHEN N'N' THEN N'逾期' ELSE N'' END AS DeliveryStatusName,
    MTR022.S_QUALITY                                 AS QualityStatusCode,
    CASE MTR022.S_QUALITY WHEN N'Y' THEN N'合格' WHEN N'A' THEN N'特採' WHEN N'N' THEN N'不合格' ELSE N'' END AS QualityStatusName,
    MTR022.REPORT                                    AS HasQcReport,
    MTR022.OK_FLG                                    AS IsClosed,
    MTR022.ACC_NO                                    AS AccountSubject,
    MTR022.QC_MARK                                   AS IncomingQcCode,
    MTR022.CHK_YN                                    AS InspectionCheckedCode,
    MTR022.D_CHK1                                    AS DeliveryConfirmedCode,
    MTR022.Q_CHK1                                    AS QualityConfirmedCode,

    MTR022.DAT1                                      AS InspectionDate,
    MTR022.DAT2                                      AS AcceptanceDate,
    MTR022.EMP1                                      AS InspectorEmployeeId,
    MTR022.STOR1                                     AS QualifiedQuantity,
    MTR022.STOR2                                     AS SpecialAcceptanceQuantity,
    MTR022.NG_QTY                                    AS NgQuantity,
    MTR022.SP_QTY                                    AS StockedQuantity,
    MTR022.QTY3                                      AS Quantity3,
    MTR022.QTY5                                      AS Quantity5,

    MTR022.DATE2                                     AS PickedDate,
    MTR022.EMP2                                      AS PickerEmployeeId,
    MTR022.EMP_NAME                                  AS PickerEmployeeName,

    MTR022.WIP05_NO                                  AS WorkOrderItemNo,

    MTR022.MOD_NAME                                  AS LastModifiedEmployeeName,
    MTR022.MOD_DATE                                  AS ModifiedDate,

    ISNULL(CONVERT(BIT, CASE WHEN MTR022.DEL_MARK = 'Y' THEN 1 ELSE 0 END), 0) AS DeleteFlag,
    MTR022.[TIMESTAMP]                               AS RecordTimestamp,
    MTR022.UTIME                                     AS LastModifiedTime
FROM [<<MAINDB>>].dbo.MTR022
    INNER JOIN [<<MAINDB>>].dbo.MTR021                           ON MTR022.MTR02_NO = MTR021.MTR02_NO        AND MTR021.DEL_MARK = 'N'
                                                   AND MTR021.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].dbo.SAL041                            ON MTR022.JOB_NO   = SAL041.ORDER_NO        AND SAL041.DEL_MARK = 'N'
                                                   AND SAL041.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].dbo.PCM010                            ON MTR022.DIE_NO   = PCM010.DIE_NO          AND PCM010.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].[Purchasing].[Vendor]            V    ON MTR021.CUST_NO  = V.VendorId
WHERE MTR022.DEL_MARK = 'N';

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'採購收料寬表 View（MTR021+MTR022 展平，料費 base）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'明細 PK (MTR02_SEQ)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PurchaseReceiveItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料單 PK', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PurchaseReceiveId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ReceiveNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源 PUR022 明細', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PurchaseOrderItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'項次', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'LineItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料日期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ReceiveDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'送貨單號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'帳款月份', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'AccountingMonth';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'幣別', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'CurrencyCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'匯率', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ExchangeRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'發票號碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'InvoiceNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'表頭小計', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeaderSubtotal';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'表頭營業稅', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeaderTax';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'含稅總額', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeaderTotalAmount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'增值稅率', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'TaxRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料人姓名 (MTR021.QC)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ReceiverName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ApproverEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ApprovedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商編號原始值', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'VendorRawId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'VendorId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'VendorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'物料編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'InventoryItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品名', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'規格', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Spec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質 (free text)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Material';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Unit';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'重量', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Weight';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Quantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單價', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'UnitPrice';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'金額（料費 base）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Amount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessingFee';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'折數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DiscountPercent';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'免費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'IsFree';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'採購原因 (MISTAKE，多用途：採購原因文字 / ''退貨'' 旗標 / 東易客戶覆寫為 PUR_NO)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PurchaseReason';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期狀態: Y=合格如期 / N=逾期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質狀態: Y=合格 / A=特採 / N=不合格', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QualityStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QualityStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'附報告', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HasQcReport';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'結案', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'IsClosed';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'會計科目', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'AccountSubject';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'進料檢驗', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'IncomingQcCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'檢驗確認', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'InspectionCheckedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'交期確認', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質確認', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QualityConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'驗收日', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'InspectionDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'驗收完成日', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'AcceptanceDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'檢驗人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'InspectorEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'合格數量', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QualifiedQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'特採數量', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'SpecialAcceptanceQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'NG 數量', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'NgQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'入庫數量', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'StockedQuantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 3', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Quantity3';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量 5', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Quantity5';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'領料日', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PickedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'領料人ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PickerEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'經手人姓名', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PickerEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令連線單號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'WorkOrderItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'編修人員姓名 (含工號)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'編修日期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ModifiedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'PurchaseReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO

-- ---------- Views/OutsourceReceiveRowDataView.sql ----------
CREATE VIEW [Reporting].[OutsourceReceiveRowDataView]
AS
SELECT
    PUR042.PUR04_SEQ                                 AS OutsourceReceiveItemId,
    PUR041.PUR04_NO                                  AS OutsourceReceiveId,
    PUR041.NO                                        AS ReceiveNo,
    PUR042.PUR03_SEQ                                 AS OutsourceOrderItemId,
    PUR042.ITEM_NO                                   AS LineItemNo,

    PUR041.DATE1                                     AS ReceiveDate,
    ''                                               AS DeliveryNo,
    ''                                               AS DeliveryDate,
    PUR041.YYMM                                      AS AccountingMonth,
    PUR041.BIL_NO                                    AS CurrencyCode,
    PUR041.EXCHANGE                                  AS ExchangeRate,
    PUR041.INVOICE                                   AS InvoiceNo,
    PUR041.TAX                                       AS HeaderTax,
    PUR041.AMT2                                      AS HeaderSubtotal,
    PUR041.AMT3                                      AS HeaderTotalAmount,
    PUR041.R_TAX                                     AS TaxRate,
    PUR041.EMP_NAME                                  AS ReceiverName,
    PUR041.TYPE1                                     AS OutsourceCategoryName,
    PUR041.PRINT_DT                                  AS PrintedTime,
    PUR041.APPROVE                                   AS ApproverEmployeeId,
    PUR041.APPRO_DATE                                AS ApprovedTime,

    PUR041.CUST_NO                                   AS VendorRawId,
    V.VendorId                                       AS VendorId,
    V.VendorName                                     AS VendorName,

    PUR042.JOB_NO                                    AS SalesOrderNo,
    SAL041.SAL04_NO                                  AS SalesOrderId,
    PUR042.DIE_NO                                    AS MoldNo,
    PCM010.PCM01_NO                                  AS MoldId,
    PCM010.DIE_NAME                                  AS MoldName,

    PUR042.SUB_NO                                    AS PartNo,
    PUR042.[NAME]                                    AS PartName,
    PUR042.SPECF                                     AS Spec,
    PUR042.MTRL                                      AS Material,

    PUR042.MD_NO                                     AS ProcessTypeId,
    PUR042.MD_NA                                     AS ProcessTypeName,
    PSS010.MD_NA                                     AS ProcessTypeNameFromMaster,

    PUR042.QTY1                                      AS Quantity,
    PUR042.TIME1                                     AS EstimatedHours,
    PUR042.AMT1                                      AS UnitPrice,
    PUR042.AMT_HR                                    AS ProcessingFee,
    PUR042.AMT_MTR                                   AS MaterialFee,
    PUR042.AMT2                                      AS Amount,
    PUR042.DISCOUNT                                  AS DiscountPercent,
    CONVERT(BIT, PUR042.AMT_N)                       AS IsFree,

    PUR042.REMARK                                    AS ProcessingDescription,
    PUR042.QC_REMARK                                 AS Remark,

    PUR042.OK_FLG                                    AS IsClosed,
    PUR042.S_DELIVER                                 AS DeliveryStatusCode,
    CASE PUR042.S_DELIVER WHEN N'Y' THEN N'合格如期' WHEN N'N' THEN N'逾期' ELSE N'' END AS DeliveryStatusName,
    PUR042.S_QUALITY                                 AS QualityStatusCode,
    CASE PUR042.S_QUALITY WHEN N'Y' THEN N'合格' WHEN N'N' THEN N'曾退貨' ELSE N'' END AS QualityStatusName,
    PUR042.D_CHK1                                    AS DeliveryConfirmedCode,
    PUR042.Q_CHK1                                    AS QualityConfirmedCode,

    PUR042.DATE2                                     AS PromisedDeliveryDate,

    PUR042.WIP05_NO                                  AS WorkOrderItemNo,
    PUR042.SR_NO                                     AS ProcessSequence,

    PUR042.MOD_NAME                                  AS LastModifiedEmployeeName,
    PUR042.MOD_DATE                                  AS ModifiedDate,

    ISNULL(CONVERT(BIT, CASE WHEN PUR042.DEL_MARK = 'Y' THEN 1 ELSE 0 END), 0) AS DeleteFlag,
    PUR042.[TIMESTAMP]                               AS RecordTimestamp,
    PUR042.UTIME                                     AS LastModifiedTime
FROM [<<MAINDB>>].dbo.PUR042
    INNER JOIN [<<MAINDB>>].dbo.PUR041                           ON PUR042.PUR04_NO = PUR041.PUR04_NO        AND PUR041.DEL_MARK = 'N'
                                                   AND PUR041.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].dbo.SAL041                            ON PUR042.JOB_NO   = SAL041.ORDER_NO        AND SAL041.DEL_MARK = 'N'
                                                   AND SAL041.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].dbo.PCM010                            ON PUR042.DIE_NO   = PCM010.DIE_NO          AND PCM010.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.PSS010                            ON PUR042.MD_NO    = PSS010.MD_NO           AND PSS010.DEL_MARK = 'N'
                                                   AND PSS010.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].[Purchasing].[Vendor]            V    ON PUR041.CUST_NO  = V.VendorId
WHERE PUR042.DEL_MARK = 'N';

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包收料寬表 View（PUR041+PUR042 展平，含 MD_NO 製程歸因）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'明細 PK', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'OutsourceReceiveItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料單 PK', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'OutsourceReceiveId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ReceiveNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源 PUR032 明細', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'OutsourceOrderItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'項次', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'LineItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'日期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ReceiveDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'送貨單號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'送貨日期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'帳款月份', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'AccountingMonth';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'幣別', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'CurrencyCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'匯率', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ExchangeRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'發票號碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'InvoiceNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'增值稅', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeaderTax';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'合計金額', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeaderSubtotal';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'含稅總額', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeaderTotalAmount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'增值稅率', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'TaxRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料者姓名 (含工號)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ReceiverName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'類別（訂單外包等）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'OutsourceCategoryName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'列印日期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PrintedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ApproverEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ApprovedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商編號原始值', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'VendorRawId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'VendorId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'VendorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品名', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'規格', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Spec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Material';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱（明細登錄）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱（主檔 PSS010）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessTypeNameFromMaster';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Quantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預估工時', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'EstimatedHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單價', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'UnitPrice';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessingFee';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'料價', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MaterialFee';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'金額（外包費 base）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Amount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'折數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DiscountPercent';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'免費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'IsFree';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工說明', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessingDescription';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品管備註欄', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完工代號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'IsClosed';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期狀態: Y=合格如期 / N=逾期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質狀態: Y=合格 / N=曾退貨', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QualityStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QualityStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'交期確認', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質確認', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QualityConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'預交貨日（品檢退回必填，預設+3天）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PromisedDeliveryDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令連線單號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'WorkOrderItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程順序', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessSequence';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'編修人員姓名 (含工號)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedEmployeeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'編修日期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ModifiedDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'OutsourceReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO

-- ---------- Views/HeatTreatmentReceiveRowDataView.sql ----------
CREATE VIEW [Reporting].[HeatTreatmentReceiveRowDataView]
AS
SELECT
    PUR062.PUR06_SEQ                                 AS HeatTreatmentReceiveItemId,
    PUR061.PUR06_NO                                  AS HeatTreatmentReceiveId,
    PUR061.NO                                        AS ReceiveNo,
    PUR062.PUR05_SEQ                                 AS HeatTreatmentOrderItemId,
    PUR062.ITEM_NO                                   AS LineItemNo,

    PUR061.DATE1                                     AS ReceiveDate,
    PUR061.YYMM                                      AS AccountingMonth,
    PUR061.BIL_NO                                    AS CurrencyCode,
    PUR061.EXCHANGE                                  AS ExchangeRate,
    PUR061.INVOICE                                   AS InvoiceNo,
    PUR061.TAX                                       AS HeaderTax,
    PUR061.AMT2                                      AS HeaderSubtotal,
    PUR061.AMT3                                      AS HeaderTotalAmount,
    PUR061.R_TAX                                     AS TaxRate,
    PUR061.QC                                        AS QcInspectorName,
    PUR061.EMP_NAME                                  AS ReceiverName,
    PUR061.PAY_TYPE1                                 AS PaymentTermsCode,
    PUR061.TYPE1                                     AS HeaderCategoryCode,
    PUR061.APPROVE                                   AS ApproverEmployeeId,
    PUR061.APPRO_DATE                                AS ApprovedTime,

    PUR061.CUST_NO                                   AS VendorRawId,
    V.VendorId                                       AS VendorId,
    V.VendorName                                     AS VendorName,

    PUR062.JOB_NO                                    AS SalesOrderNo,
    SAL041.SAL04_NO                                  AS SalesOrderId,
    PUR062.DIE_NO                                    AS MoldNo,
    PCM010.PCM01_NO                                  AS MoldId,
    PCM010.DIE_NAME                                  AS MoldName,

    PUR062.SUB_NO                                    AS PartNo,
    PUR062.[NAME]                                    AS PartName,
    PUR062.SPECF                                     AS Spec,
    PUR062.MTRL                                      AS Material,
    PUR062.UNIT                                      AS Unit,
    PUR062.WEIGHT                                    AS Weight,

    PUR062.MD_NO                                     AS ProcessTypeId,
    PUR062.MD_NA                                     AS ProcessTypeName,
    PSS010.MD_NA                                     AS ProcessTypeNameFromMaster,
    PUR062.TYPE1                                     AS HeatTreatmentTypeCode,
    PUR062.TYPE6                                     AS HeatTreatmentTypeCodeAlt,

    PUR062.HARDNESS                                  AS HardnessRequirement,
    PUR062.REALHARD                                  AS MeasuredHardness,

    PUR062.QTY1                                      AS Quantity,
    PUR062.AMT1                                      AS UnitPrice,
    PUR062.AMT2                                      AS Amount,
    CONVERT(BIT, PUR062.AMT_N)                       AS IsFree,

    PUR062.REMARK                                    AS Remark,

    PUR062.OK_FLG                                    AS IsClosed,
    PUR062.S_DELIVER                                 AS DeliveryStatusCode,
    CASE PUR062.S_DELIVER WHEN N'Y' THEN N'合格如期' WHEN N'N' THEN N'逾期' ELSE N'' END AS DeliveryStatusName,
    PUR062.S_QUALITY                                 AS QualityStatusCode,
    CASE PUR062.S_QUALITY WHEN N'Y' THEN N'合格' WHEN N'N' THEN N'曾退貨' ELSE N'' END AS QualityStatusName,
    PUR062.D_CHK1                                    AS DeliveryConfirmedCode,
    PUR062.Q_CHK1                                    AS QualityConfirmedCode,
    PUR062.REPORT                                    AS HasReport,
    CONVERT(BIT, PUR062.R_REPORT)                    AS RequiresReport,

    PUR062.WIP05_NO                                  AS WorkOrderItemNo,
    PUR062.SR_NO                                     AS ProcessSequence,

    ISNULL(CONVERT(BIT, CASE WHEN PUR062.DEL_MARK = 'Y' THEN 1 ELSE 0 END), 0) AS DeleteFlag,
    PUR062.[TIMESTAMP]                               AS RecordTimestamp,
    PUR062.UTIME                                     AS LastModifiedTime
FROM [<<MAINDB>>].dbo.PUR062
    INNER JOIN [<<MAINDB>>].dbo.PUR061                           ON PUR062.PUR06_NO = PUR061.PUR06_NO        AND PUR061.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.SAL041                            ON PUR062.JOB_NO   = SAL041.ORDER_NO        AND SAL041.DEL_MARK = 'N'
                                                   AND SAL041.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].dbo.PCM010                            ON PUR062.DIE_NO   = PCM010.DIE_NO          AND PCM010.DEL_MARK = 'N'
    LEFT JOIN [<<MAINDB>>].dbo.PSS010                            ON PUR062.MD_NO    = PSS010.MD_NO           AND PSS010.DEL_MARK = 'N'
                                                   AND PSS010.SYS_TYPE IN ('MOLDPLAN', '')
    LEFT JOIN [<<MAINDB>>].[Purchasing].[Vendor]            V    ON PUR061.CUST_NO  = V.VendorId
WHERE PUR062.DEL_MARK = 'N';

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理外包收料寬表 View（PUR061+PUR062 展平，含 MD_NO 製程歸因與硬度需求/實測）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'明細 PK', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeatTreatmentReceiveItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料單 PK', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeatTreatmentReceiveId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ReceiveNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'來源 PUR052 明細', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeatTreatmentOrderItemId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'項次', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'LineItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'日期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ReceiveDate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'帳款月份', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'AccountingMonth';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'幣別', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'CurrencyCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'匯率', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ExchangeRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'發票號碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'InvoiceNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'增值稅', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeaderTax';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'合計金額', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeaderSubtotal';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'含稅總額', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeaderTotalAmount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'增值稅率', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'TaxRate';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品管者姓名 (含工號)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QcInspectorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'收料者姓名', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ReceiverName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'付款方式 (PAY_TYPE1)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PaymentTermsCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'表頭類別', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeaderCategoryCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核人員ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ApproverEmployeeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'簽核時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ApprovedTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商編號原始值', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'VendorRawId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'VendorId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'廠商名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'VendorName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'訂單ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'SalesOrderId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品名', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'規格', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Spec';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'材質', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Material';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單位', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Unit';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'重量@', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Weight';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別/熱處理名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱（主檔 PSS010）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessTypeNameFromMaster';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理別 (TYPE1，一般客戶)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeatTreatmentTypeCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理別替代欄 (TYPE6，明基客戶)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HeatTreatmentTypeCodeAlt';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'硬度要求 (從 PUR052 帶下)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HardnessRequirement';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'實際/實測硬度 (REALHARD，完工時寫回 PCM010.HD4)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'MeasuredHardness';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'數量', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Quantity';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'單價', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'UnitPrice';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'金額（熱處理外包費 base）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Amount';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'免費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'IsFree';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'備註欄', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'Remark';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'完工代號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'IsClosed';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期: Y=合格如期 / N=逾期', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'如期狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質: Y=合格 / N=曾退貨', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QualityStatusCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質狀態名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QualityStatusName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'交期確認', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeliveryConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'品質確認', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'QualityConfirmedCode';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'報告', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'HasReport';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'需報告', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'RequiresReport';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工令連線單號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'WorkOrderItemNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'製程順序', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'ProcessSequence';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'刪除標記', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'DeleteFlag';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'時間戳', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'RecordTimestamp';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最後修改時間', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'HeatTreatmentReceiveRowDataView', @level2type = N'COLUMN', @level2name = N'LastModifiedTime';
GO

-- ---------- Views/MoldCostSummaryView.sql ----------
CREATE VIEW [Reporting].[MoldCostSummaryView]
AS
WITH WorkAgg AS (
    SELECT MoldNo,
           SUM(ISNULL(MachineOccupiedHours, 0))                                AS TotalProcessingHours,
           SUM(ISNULL(MachineOccupiedHours, 0) * ISNULL(ProcessingRate, 0))     AS LaborCost,
           MIN(WorkStartTime)                                                  AS FirstWorkStart,
           MAX(WorkEndTime)                                                    AS LastWorkEnd
    FROM [Reporting].[WorkRecordRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
    GROUP BY MoldNo
),
PurchaseAgg AS (
    SELECT MoldNo, SUM(ISNULL(Amount, 0)) AS MaterialCost
    FROM [Reporting].[PurchaseReceiveRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
    GROUP BY MoldNo
),
OutsourceAgg AS (
    SELECT MoldNo, SUM(ISNULL(Amount, 0)) AS OutsourceAmount
    FROM [Reporting].[OutsourceReceiveRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
    GROUP BY MoldNo
),
HeatTreatmentAgg AS (
    SELECT MoldNo, SUM(ISNULL(Amount, 0)) AS HeatTreatmentAmount
    FROM [Reporting].[HeatTreatmentReceiveRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
    GROUP BY MoldNo
)
SELECT
    M.MoldId                                              AS MoldId,
    M.MoldNo                                              AS MoldNo,
    M.MoldName                                            AS MoldName,

    ISNULL(W.TotalProcessingHours, 0)                     AS TotalProcessingHours,
    W.FirstWorkStart                                      AS FirstWorkStartTime,
    W.LastWorkEnd                                         AS LastWorkEndTime,
    CASE
        WHEN W.FirstWorkStart IS NOT NULL AND W.LastWorkEnd IS NOT NULL
        THEN DATEDIFF(DAY, W.FirstWorkStart, W.LastWorkEnd)
        ELSE NULL
    END                                                   AS WorkPeriodDays,

    ISNULL(W.LaborCost, 0)                                AS LaborCost,
    ISNULL(P.MaterialCost, 0)                             AS MaterialCost,
    ISNULL(O.OutsourceAmount, 0)                          AS GeneralOutsourceCost,
    ISNULL(H.HeatTreatmentAmount, 0)                      AS HeatTreatmentCost,
    ISNULL(O.OutsourceAmount, 0) + ISNULL(H.HeatTreatmentAmount, 0) AS OutsourceCost,
    ISNULL(W.LaborCost, 0)
        + ISNULL(P.MaterialCost, 0)
        + ISNULL(O.OutsourceAmount, 0)
        + ISNULL(H.HeatTreatmentAmount, 0)                AS TotalCost,

    CASE WHEN W.MoldNo IS NOT NULL THEN 1 ELSE 0 END      AS HasWorkRecord,
    CASE WHEN P.MoldNo IS NOT NULL THEN 1 ELSE 0 END      AS HasPurchase,
    CASE WHEN O.MoldNo IS NOT NULL THEN 1 ELSE 0 END      AS HasOutsource,
    CASE WHEN H.MoldNo IS NOT NULL THEN 1 ELSE 0 END      AS HasHeatTreatment
FROM [Reporting].[MoldRowData] M
    LEFT JOIN WorkAgg          W ON M.MoldNo = W.MoldNo
    LEFT JOIN PurchaseAgg      P ON M.MoldNo = P.MoldNo
    LEFT JOIN OutsourceAgg     O ON M.MoldNo = O.MoldNo
    LEFT JOIN HeatTreatmentAgg H ON M.MoldNo = H.MoldNo
WHERE M.DeleteFlag = 0;

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具成本總表彙總 View（每模具一行）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號（彙總歸因鍵）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工總工時', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'TotalProcessingHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最早開工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'FirstWorkStartTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最晚完工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'LastWorkEndTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工期天數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'WorkPeriodDays';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工費 = Σ (機工時 × 加工費率)', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'LaborCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'料費 = Σ 採購收料金額', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'MaterialCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'一般外包費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'GeneralOutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理外包費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'HeatTreatmentCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包費合計', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'OutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'總金額', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'TotalCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有報工記錄', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasWorkRecord';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有採購收料', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasPurchase';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有外包收料', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasOutsource';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有熱處理外包', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasHeatTreatment';
GO

-- ---------- Views/MoldPartCostSummaryView.sql ----------
CREATE VIEW [Reporting].[MoldPartCostSummaryView]
AS
WITH WorkAgg AS (
    SELECT MoldNo, PartNo,
           SUM(ISNULL(MachineOccupiedHours, 0))                              AS TotalProcessingHours,
           SUM(ISNULL(MachineOccupiedHours, 0) * ISNULL(ProcessingRate, 0))   AS LaborCost,
           MIN(WorkStartTime)                                                AS FirstWorkStart,
           MAX(WorkEndTime)                                                  AS LastWorkEnd
    FROM [Reporting].[WorkRecordRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
      AND PartNo IS NOT NULL AND LTRIM(RTRIM(PartNo)) <> ''
    GROUP BY MoldNo, PartNo
),
PurchaseAgg AS (
    -- 料費歸因：MTR022.PART_NO (InventoryItemId) 對齊零件號
    SELECT MoldNo, InventoryItemId AS PartNo, SUM(ISNULL(Amount, 0)) AS MaterialCost
    FROM [Reporting].[PurchaseReceiveRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
      AND InventoryItemId IS NOT NULL AND LTRIM(RTRIM(InventoryItemId)) <> ''
    GROUP BY MoldNo, InventoryItemId
),
OutsourceAgg AS (
    SELECT MoldNo, PartNo, SUM(ISNULL(Amount, 0)) AS OutsourceAmount
    FROM [Reporting].[OutsourceReceiveRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
      AND PartNo IS NOT NULL AND LTRIM(RTRIM(PartNo)) <> ''
    GROUP BY MoldNo, PartNo
),
HeatTreatmentAgg AS (
    SELECT MoldNo, PartNo, SUM(ISNULL(Amount, 0)) AS HeatTreatmentAmount
    FROM [Reporting].[HeatTreatmentReceiveRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
      AND PartNo IS NOT NULL AND LTRIM(RTRIM(PartNo)) <> ''
    GROUP BY MoldNo, PartNo
)
SELECT
    P.Id                                                  AS PartId,
    P.MoldId                                              AS MoldId,
    P.MoldNo                                              AS MoldNo,
    P.MoldName                                            AS MoldName,
    P.PartNo                                              AS PartNo,
    P.PartName                                            AS PartName,

    ISNULL(W.TotalProcessingHours, 0)                     AS TotalProcessingHours,
    W.FirstWorkStart                                      AS FirstWorkStartTime,
    W.LastWorkEnd                                         AS LastWorkEndTime,
    CASE
        WHEN W.FirstWorkStart IS NOT NULL AND W.LastWorkEnd IS NOT NULL
        THEN DATEDIFF(DAY, W.FirstWorkStart, W.LastWorkEnd)
        ELSE NULL
    END                                                   AS WorkPeriodDays,

    ISNULL(W.LaborCost, 0)                                AS LaborCost,
    ISNULL(Pu.MaterialCost, 0)                            AS MaterialCost,
    ISNULL(O.OutsourceAmount, 0)                          AS GeneralOutsourceCost,
    ISNULL(H.HeatTreatmentAmount, 0)                      AS HeatTreatmentCost,
    ISNULL(O.OutsourceAmount, 0) + ISNULL(H.HeatTreatmentAmount, 0) AS OutsourceCost,
    ISNULL(W.LaborCost, 0)
        + ISNULL(Pu.MaterialCost, 0)
        + ISNULL(O.OutsourceAmount, 0)
        + ISNULL(H.HeatTreatmentAmount, 0)                AS TotalCost,

    CASE WHEN W.MoldNo  IS NOT NULL THEN 1 ELSE 0 END     AS HasWorkRecord,
    CASE WHEN Pu.MoldNo IS NOT NULL THEN 1 ELSE 0 END     AS HasPurchase,
    CASE WHEN O.MoldNo  IS NOT NULL THEN 1 ELSE 0 END     AS HasOutsource,
    CASE WHEN H.MoldNo  IS NOT NULL THEN 1 ELSE 0 END     AS HasHeatTreatment
FROM [Reporting].[WorkOrderPartRowData] P
    LEFT JOIN WorkAgg          W  ON P.MoldNo = W.MoldNo  AND P.PartNo = W.PartNo
    LEFT JOIN PurchaseAgg      Pu ON P.MoldNo = Pu.MoldNo AND P.PartNo = Pu.PartNo
    LEFT JOIN OutsourceAgg     O  ON P.MoldNo = O.MoldNo  AND P.PartNo = O.PartNo
    LEFT JOIN HeatTreatmentAgg H  ON P.MoldNo = H.MoldNo  AND P.PartNo = H.PartNo
WHERE P.DeleteFlag = 0
  AND P.MoldNo IS NOT NULL AND LTRIM(RTRIM(P.MoldNo)) <> ''
  AND P.PartNo IS NOT NULL AND LTRIM(RTRIM(P.PartNo)) <> '';

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具零件成本彙總 View（每模具+零件一行）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'PartId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工總工時', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'TotalProcessingHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最早開工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'FirstWorkStartTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最晚完工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'LastWorkEndTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工期天數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'WorkPeriodDays';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'LaborCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'料費（InventoryItemId 對齊 PartNo）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'MaterialCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'一般外包費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'GeneralOutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理外包費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'HeatTreatmentCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包費合計', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'OutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'總金額', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'TotalCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有報工記錄', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasWorkRecord';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有採購收料', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasPurchase';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有外包收料', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasOutsource';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有熱處理外包', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasHeatTreatment';
GO

-- ---------- Views/MoldPartProcessCostSummaryView.sql ----------
CREATE VIEW [Reporting].[MoldPartProcessCostSummaryView]
AS
WITH WorkAgg AS (
    SELECT MoldNo, PartNo, ProcessTypeId,
           MAX(ProcessTypeName)                                              AS ProcessTypeName,
           SUM(ISNULL(MachineOccupiedHours, 0))                              AS TotalProcessingHours,
           SUM(ISNULL(MachineOccupiedHours, 0) * ISNULL(ProcessingRate, 0))   AS LaborCost,
           MIN(WorkStartTime)                                                AS FirstWorkStart,
           MAX(WorkEndTime)                                                  AS LastWorkEnd
    FROM [Reporting].[WorkRecordRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
      AND PartNo IS NOT NULL AND LTRIM(RTRIM(PartNo)) <> ''
      AND ProcessTypeId IS NOT NULL AND LTRIM(RTRIM(ProcessTypeId)) <> ''
    GROUP BY MoldNo, PartNo, ProcessTypeId
),
OutsourceAgg AS (
    SELECT MoldNo, PartNo, ProcessTypeId,
           MAX(ProcessTypeName)               AS ProcessTypeName,
           SUM(ISNULL(Amount, 0))             AS OutsourceAmount
    FROM [Reporting].[OutsourceReceiveRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
      AND PartNo IS NOT NULL AND LTRIM(RTRIM(PartNo)) <> ''
      AND ProcessTypeId IS NOT NULL AND LTRIM(RTRIM(ProcessTypeId)) <> ''
    GROUP BY MoldNo, PartNo, ProcessTypeId
),
HeatTreatmentAgg AS (
    SELECT MoldNo, PartNo, ProcessTypeId,
           MAX(ProcessTypeName)               AS ProcessTypeName,
           SUM(ISNULL(Amount, 0))             AS HeatTreatmentAmount
    FROM [Reporting].[HeatTreatmentReceiveRowData]
    WHERE DeleteFlag = 0
      AND MoldNo IS NOT NULL AND LTRIM(RTRIM(MoldNo)) <> ''
      AND PartNo IS NOT NULL AND LTRIM(RTRIM(PartNo)) <> ''
      AND ProcessTypeId IS NOT NULL AND LTRIM(RTRIM(ProcessTypeId)) <> ''
    GROUP BY MoldNo, PartNo, ProcessTypeId
),
BaseScope AS (
    -- UNION 三個來源的 distinct key，確保涵蓋所有有成本記錄的製程
    SELECT MoldNo, PartNo, ProcessTypeId FROM WorkAgg
    UNION
    SELECT MoldNo, PartNo, ProcessTypeId FROM OutsourceAgg
    UNION
    SELECT MoldNo, PartNo, ProcessTypeId FROM HeatTreatmentAgg
)
SELECT
    -- 由 WorkOrderProcessRowData 帶 Mold/Part 描述（用任一筆 max 取代 distinct）
    MAX(PR.MoldId)        AS MoldId,
    B.MoldNo              AS MoldNo,
    MAX(PR.MoldName)      AS MoldName,
    MAX(PR.PartId)        AS PartId,
    B.PartNo              AS PartNo,
    MAX(PR.PartName)      AS PartName,
    B.ProcessTypeId       AS ProcessTypeId,
    COALESCE(MAX(W.ProcessTypeName), MAX(O.ProcessTypeName), MAX(H.ProcessTypeName), MAX(PR.ProcessTypeName)) AS ProcessTypeName,

    ISNULL(MAX(W.TotalProcessingHours), 0)                AS TotalProcessingHours,
    MAX(W.FirstWorkStart)                                 AS FirstWorkStartTime,
    MAX(W.LastWorkEnd)                                    AS LastWorkEndTime,
    CASE
        WHEN MAX(W.FirstWorkStart) IS NOT NULL AND MAX(W.LastWorkEnd) IS NOT NULL
        THEN DATEDIFF(DAY, MAX(W.FirstWorkStart), MAX(W.LastWorkEnd))
        ELSE NULL
    END                                                   AS WorkPeriodDays,

    ISNULL(MAX(W.LaborCost), 0)                           AS LaborCost,
    ISNULL(MAX(O.OutsourceAmount), 0)                     AS GeneralOutsourceCost,
    ISNULL(MAX(H.HeatTreatmentAmount), 0)                 AS HeatTreatmentCost,
    ISNULL(MAX(O.OutsourceAmount), 0) + ISNULL(MAX(H.HeatTreatmentAmount), 0) AS OutsourceCost,
    ISNULL(MAX(W.LaborCost), 0)
        + ISNULL(MAX(O.OutsourceAmount), 0)
        + ISNULL(MAX(H.HeatTreatmentAmount), 0)           AS TotalCost,

    CASE WHEN MAX(W.MoldNo) IS NOT NULL THEN 1 ELSE 0 END AS HasWorkRecord,
    CASE WHEN MAX(O.MoldNo) IS NOT NULL THEN 1 ELSE 0 END AS HasOutsource,
    CASE WHEN MAX(H.MoldNo) IS NOT NULL THEN 1 ELSE 0 END AS HasHeatTreatment,
    CASE WHEN MAX(O.MoldNo) IS NOT NULL OR MAX(H.MoldNo) IS NOT NULL THEN 1 ELSE 0 END AS IsOutsourced
FROM BaseScope B
    LEFT JOIN WorkAgg          W ON B.MoldNo = W.MoldNo AND B.PartNo = W.PartNo AND B.ProcessTypeId = W.ProcessTypeId
    LEFT JOIN OutsourceAgg     O ON B.MoldNo = O.MoldNo AND B.PartNo = O.PartNo AND B.ProcessTypeId = O.ProcessTypeId
    LEFT JOIN HeatTreatmentAgg H ON B.MoldNo = H.MoldNo AND B.PartNo = H.PartNo AND B.ProcessTypeId = H.ProcessTypeId
    LEFT JOIN [Reporting].[WorkOrderProcessRowData] PR ON B.MoldNo = PR.MoldNo AND B.PartNo = PR.PartNo AND B.ProcessTypeId = PR.ProcessTypeId AND PR.DeleteFlag = 0
GROUP BY B.MoldNo, B.PartNo, B.ProcessTypeId;

GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具零件製程成本彙總 View（每模具+零件+工別一行）', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'MoldId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具編號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'MoldNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'模具名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'MoldName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件ID', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'PartId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件號', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'PartNo';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'零件名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'PartName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別代碼', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'ProcessTypeId';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工別名稱', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'ProcessTypeName';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'加工總工時', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'TotalProcessingHours';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最早開工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'FirstWorkStartTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'最晚完工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'LastWorkEndTime';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工期天數', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'WorkPeriodDays';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'工費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'LaborCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'一般外包費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'GeneralOutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'熱處理外包費', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'HeatTreatmentCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'外包費合計', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'OutsourceCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'總金額', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'TotalCost';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有廠內報工', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasWorkRecord';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有一般外包', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasOutsource';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'有熱處理外包', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'HasHeatTreatment';
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'是否外發製程', @level0type = N'SCHEMA', @level0name = N'Reporting', @level1type = N'VIEW', @level1name = N'MoldPartProcessCostSummaryView', @level2type = N'COLUMN', @level2name = N'IsOutsourced';
GO
