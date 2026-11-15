CREATE PROC [gold].[create_dimcustomer]
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
    -- Gold dimension: customer, enriched with its primary (Main Office first) address.
    -- PasswordHash / PasswordSalt are deliberately NOT carried into gold.
    IF EXISTS (select 1 from [INFORMATION_SCHEMA].[TABLES] WHERE TABLE_TYPE ='BASE TABLE' AND TABLE_SCHEMA ='gold' AND TABLE_NAME ='DimCustomer')
        DROP TABLE gold.DimCustomer

    create table gold.DimCustomer
    as
    WITH primary_address AS
    (
        SELECT ca.[CustomerID]
            , ca.[AddressID]
            , ca.[AddressType]
            , ROW_NUMBER() OVER (PARTITION BY ca.[CustomerID]
                                 ORDER BY CASE WHEN ca.[AddressType] = 'Main Office' THEN 0 ELSE 1 END, ca.[AddressID]) AS rn
        FROM [lh_silver].[dbo].[silver_saleslt_customeraddress] AS ca
    )
    SELECT CAST(c.[CustomerID] AS int)          AS CustomerKey
        , CAST(c.[CustomerID] AS int)           AS CustomerID
        , CAST(LTRIM(RTRIM(CONCAT(c.[FirstName], ' ', c.[LastName]))) AS varchar(200)) AS FullName
        , CAST(c.[Title] AS varchar(8))         AS Title
        , CAST(c.[FirstName] AS varchar(50))    AS FirstName
        , CAST(c.[MiddleName] AS varchar(50))   AS MiddleName
        , CAST(c.[LastName] AS varchar(50))     AS LastName
        , CAST(c.[Suffix] AS varchar(10))       AS Suffix
        , CAST(c.[CompanyName] AS varchar(128)) AS CompanyName
        , CAST(c.[SalesPerson] AS varchar(256)) AS SalesPerson
        , CAST(c.[EmailAddress] AS varchar(50)) AS EmailAddress
        , CAST(c.[Phone] AS varchar(25))        AS Phone
        , CAST(pa.[AddressType] AS varchar(50)) AS AddressType
        , CAST(a.[AddressLine1] AS varchar(60)) AS AddressLine1
        , CAST(a.[AddressLine2] AS varchar(60)) AS AddressLine2
        , CAST(a.[City] AS varchar(30))         AS City
        , CAST(a.[StateProvince] AS varchar(50)) AS StateProvince
        , CAST(a.[CountryRegion] AS varchar(50)) AS CountryRegion
        , CAST(a.[PostalCode] AS varchar(15))   AS PostalCode
        , CAST(c.[ModifiedDate] AS datetime2(6)) AS ModifiedDate
    FROM [lh_silver].[dbo].[silver_saleslt_customer] AS c
    LEFT JOIN primary_address AS pa
        ON pa.[CustomerID] = c.[CustomerID]
        AND pa.rn = 1
    LEFT JOIN [lh_silver].[dbo].[silver_saleslt_address] AS a
        ON a.[AddressID] = pa.[AddressID]
END
