CREATE PROC [gold].[create_dimproduct]
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
    -- Gold dimension: product flattened with category (self-join for parent),
    -- model, and the English product description.
    -- AdventureWorksLT carries Culture on ProductModelProductDescription, not on
    -- ProductDescription, so the culture filter belongs on that bridge table.
    IF EXISTS (select 1 from [INFORMATION_SCHEMA].[TABLES] WHERE TABLE_TYPE ='BASE TABLE' AND TABLE_SCHEMA ='gold' AND TABLE_NAME ='DimProduct')
        DROP TABLE gold.DimProduct

    create table gold.DimProduct
    as
    WITH en_description AS
    (
        SELECT pmd.[ProductModelID]
            , pd.[Description]
            , ROW_NUMBER() OVER (PARTITION BY pmd.[ProductModelID] ORDER BY pd.[ProductDescriptionID]) AS rn
        FROM [lh_silver].[dbo].[silver_saleslt_productmodelproductdescription] AS pmd
        INNER JOIN [lh_silver].[dbo].[silver_saleslt_productdescription] AS pd
            ON pd.[ProductDescriptionID] = pmd.[ProductDescriptionID]
        WHERE UPPER(LTRIM(RTRIM(pmd.[Culture]))) LIKE 'EN%'
    )
    SELECT CAST(p.[ProductID] AS int)               AS ProductKey
        , CAST(p.[ProductID] AS int)                AS ProductID
        , CAST(p.[Name] AS varchar(50))             AS ProductName
        , CAST(p.[ProductNumber] AS varchar(25))    AS ProductNumber
        , CAST(p.[Color] AS varchar(15))            AS Color
        , CAST(p.[Size] AS varchar(5))              AS Size
        , CAST(p.[Weight] AS decimal(8,2))          AS Weight
        , CAST(p.[StandardCost] AS decimal(19,4))   AS StandardCost
        , CAST(p.[ListPrice] AS decimal(19,4))      AS ListPrice
        , CAST(p.[SellStartDate] AS date)           AS SellStartDate
        , CAST(p.[SellEndDate] AS date)             AS SellEndDate
        , CAST(p.[DiscontinuedDate] AS date)        AS DiscontinuedDate
        , CAST(p.[ProductCategoryID] AS int)        AS ProductCategoryID
        , CAST(pc.[Name] AS varchar(50))            AS CategoryName
        , CAST(pc.[ParentProductCategoryID] AS int) AS ParentCategoryID
        , CAST(parent_pc.[Name] AS varchar(50))     AS ParentCategoryName
        , CAST(p.[ProductModelID] AS int)           AS ProductModelID
        , CAST(pm.[Name] AS varchar(50))            AS ProductModelName
        , CAST(d.[Description] AS varchar(400))     AS ProductDescription
        , CAST(p.[ModifiedDate] AS datetime2(6))    AS ModifiedDate
    FROM [lh_silver].[dbo].[silver_saleslt_product] AS p
    LEFT JOIN [lh_silver].[dbo].[silver_saleslt_productcategory] AS pc
        ON pc.[ProductCategoryID] = p.[ProductCategoryID]
    LEFT JOIN [lh_silver].[dbo].[silver_saleslt_productcategory] AS parent_pc
        ON parent_pc.[ProductCategoryID] = pc.[ParentProductCategoryID]
    LEFT JOIN [lh_silver].[dbo].[silver_saleslt_productmodel] AS pm
        ON pm.[ProductModelID] = p.[ProductModelID]
    LEFT JOIN en_description AS d
        ON d.[ProductModelID] = p.[ProductModelID]
        AND d.rn = 1
END
