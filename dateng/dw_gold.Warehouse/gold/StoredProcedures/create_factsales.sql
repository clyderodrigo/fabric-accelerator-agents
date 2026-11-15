CREATE PROC [gold].[create_factsales]
	(@L2TransformInstanceID INT NULL = NULL
	, @L2TransformID INT NULL = NULL
	, @IngestID INT NULL = NULL
	, @L1TransformID INT NULL = NULL
	, @CustomParameters VARCHAR(max) NULL = NULL
	, @InputType VARCHAR(15) NULL = NULL
	, @InputFileSystem VARCHAR(50) NULL = NULL
	, @InputFileFolder VARCHAR(200) NULL = NULL
	, @InputFile VARCHAR(200) NULL = NULL
	, @InputFileDelimiter CHAR(1)  NULL = NULL
	, @InputFileHeaderFlag BIT NULL = NULL
	, @InputDWTable VARCHAR(200) NULL = NULL
	, @WatermarkColName VARCHAR(50) NULL = NULL
	, @DataFromTimestamp DATETIME NULL = NULL
	, @DataToTimestamp DATETIME NULL = NULL
	, @DataFromNumber INT NULL = NULL
	, @DataToNumber INT NULL = NULL
	, @OutputL2CurateFileSystem VARCHAR(50) NULL = NULL
	, @OutputL2CuratedFolder VARCHAR(200) NULL = NULL
	, @OutputL2CuratedFile VARCHAR(200) NULL = NULL
	, @OutputL2CuratedFileDelimiter CHAR(1) NULL = NULL
	, @OutputL2CuratedFileFormat VARCHAR(10) NULL = NULL
	, @OutputL2CuratedFileWriteMode VARCHAR(20) NULL = NULL
	, @OutputDWStagingTable VARCHAR(200) NULL = NULL
	, @LookupColumns VARCHAR(20) NULL = NULL
	, @OutputDWTable VARCHAR(200) NULL = NULL
	, @OutputDWTableWriteMode VARCHAR(20) NULL = NULL
)
AS
BEGIN
    -- Gold fact: sales order header + detail, grain = one row per SalesOrderDetail.
    -- AdventureWorksLT.SalesLT.SalesOrderDetail has no LineTotal column, so the line
    -- extension is computed: OrderQty * UnitPrice * (1 - UnitPriceDiscount).
    -- Header-level money (TaxAmt / Freight / TotalDue) is apportioned across the order's
    -- lines by line-value share so every measure stays additive at line grain. Orders
    -- whose lines all net to zero fall back to an even split.
    -- Calendar keys are role-played: OrderDateKey, DueDateKey, ShipDateKey -> gold.DimCalendar.
    -- Address keys are role-played: ShipToAddressKey, BillToAddressKey -> gold.DimAddress.
    IF EXISTS (select 1 from [INFORMATION_SCHEMA].[TABLES] WHERE TABLE_TYPE ='BASE TABLE' AND TABLE_SCHEMA ='gold' AND TABLE_NAME ='FactSales')
        DROP TABLE gold.FactSales

    create table gold.FactSales
    as
    WITH order_line AS
    (
        SELECT d.[SalesOrderID]
            , d.[SalesOrderDetailID]
            , d.[ProductID]
            , d.[OrderQty]
            , d.[UnitPrice]
            , d.[UnitPriceDiscount]
            , CAST(d.[OrderQty] * d.[UnitPrice] * (1 - d.[UnitPriceDiscount]) AS decimal(19,4)) AS LineTotal
            , d.[ModifiedDate]
        FROM [lh_silver].[dbo].[silver_saleslt_salesorderdetail] AS d
    )
    , order_header AS
    (
        SELECT h.[SalesOrderID]
            , h.[SalesOrderNumber]
            , h.[OrderDate]
            , h.[DueDate]
            , h.[ShipDate]
            , h.[Status]
            , h.[OnlineOrderFlag]
            , h.[CustomerID]
            , h.[ShipToAddressID]
            , h.[BillToAddressID]
            , h.[ShipMethod]
            , CAST(h.[TaxAmt] AS decimal(19,4))   AS TaxAmt
            , CAST(h.[Freight] AS decimal(19,4))  AS Freight
            , CAST(h.[TotalDue] AS decimal(19,4)) AS TotalDue
        FROM [lh_silver].[dbo].[silver_saleslt_salesorderheader] AS h
    )
    , allocated AS
    (
        SELECT l.*
            , SUM(l.[LineTotal]) OVER (PARTITION BY l.[SalesOrderID]) AS OrderLineTotal
            , COUNT(*)           OVER (PARTITION BY l.[SalesOrderID]) AS OrderLineCount
        FROM order_line AS l
    )
    , share AS
    (
        SELECT a.*
            , CAST(CASE WHEN a.[OrderLineTotal] = 0 OR a.[OrderLineTotal] IS NULL
                        THEN 1.0 / NULLIF(a.[OrderLineCount], 0)
                        ELSE a.[LineTotal] / a.[OrderLineTotal]
                   END AS decimal(19,8)) AS LineShare
        FROM allocated AS a
    )
    SELECT CAST(s.[SalesOrderID] AS int)                AS SalesOrderID
        , CAST(s.[SalesOrderDetailID] AS int)           AS SalesOrderDetailID
        , CAST(o.[SalesOrderNumber] AS varchar(25))     AS SalesOrderNumber
        , CAST(o.[CustomerID] AS int)                   AS CustomerKey
        , CAST(s.[ProductID] AS int)                    AS ProductKey
        , CAST(o.[ShipToAddressID] AS int)              AS ShipToAddressKey
        , CAST(o.[BillToAddressID] AS int)              AS BillToAddressKey
        , CAST(CONVERT(varchar(8), o.[OrderDate], 112) AS int) AS OrderDateKey
        , CAST(CONVERT(varchar(8), o.[DueDate],   112) AS int) AS DueDateKey
        , CAST(CONVERT(varchar(8), o.[ShipDate],  112) AS int) AS ShipDateKey
        , CAST(o.[OrderDate] AS date)                   AS OrderDate
        , CAST(o.[DueDate] AS date)                     AS DueDate
        , CAST(o.[ShipDate] AS date)                    AS ShipDate
        , CAST(o.[Status] AS smallint)                   AS Status
        , CAST(o.[OnlineOrderFlag] AS bit)              AS OnlineOrderFlag
        , CAST(o.[ShipMethod] AS varchar(50))           AS ShipMethod
        , CAST(s.[OrderQty] AS smallint)                AS OrderQty
        , CAST(s.[UnitPrice] AS decimal(19,4))          AS UnitPrice
        , CAST(s.[UnitPriceDiscount] AS decimal(19,4))  AS UnitPriceDiscount
        , s.[LineTotal]                                 AS LineTotal
        , CAST(o.[TaxAmt]   * s.[LineShare] AS decimal(19,4)) AS AllocatedTaxAmt
        , CAST(o.[Freight]  * s.[LineShare] AS decimal(19,4)) AS AllocatedFreight
        , CAST(o.[TotalDue] * s.[LineShare] AS decimal(19,4)) AS AllocatedTotalDue
        , CAST(s.[ModifiedDate] AS datetime2(6))        AS ModifiedDate
    FROM share AS s
    INNER JOIN order_header AS o
        ON o.[SalesOrderID] = s.[SalesOrderID]
END
