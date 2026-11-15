CREATE PROC [gold].[create_dimaddress]
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
    -- Gold dimension: address, role-played by FactSales as both ShipTo and BillTo.
    IF EXISTS (select 1 from [INFORMATION_SCHEMA].[TABLES] WHERE TABLE_TYPE ='BASE TABLE' AND TABLE_SCHEMA ='gold' AND TABLE_NAME ='DimAddress')
        DROP TABLE gold.DimAddress

    create table gold.DimAddress
    as
    SELECT CAST(a.[AddressID] AS int)   AS AddressKey
        , CAST(a.[AddressID] AS int)    AS AddressID
        , CAST(a.[AddressLine1] AS varchar(60)) AS AddressLine1
        , CAST(a.[AddressLine2] AS varchar(60)) AS AddressLine2
        , CAST(a.[City] AS varchar(30))         AS City
        , CAST(a.[StateProvince] AS varchar(50)) AS StateProvince
        , CAST(a.[CountryRegion] AS varchar(50)) AS CountryRegion
        , CAST(a.[PostalCode] AS varchar(15))   AS PostalCode
        , CAST(CONCAT(a.[AddressLine1]
                    , CASE WHEN a.[AddressLine2] IS NULL THEN '' ELSE ', ' + a.[AddressLine2] END
                    , ', ', a.[City]
                    , CASE WHEN a.[StateProvince] IS NULL THEN '' ELSE ', ' + a.[StateProvince] END
                    , CASE WHEN a.[CountryRegion] IS NULL THEN '' ELSE ', ' + a.[CountryRegion] END
                    , ' ', a.[PostalCode]) AS varchar(200)) AS FullAddress
        , CAST(a.[ModifiedDate] AS datetime2(6)) AS ModifiedDate
    FROM [lh_silver].[dbo].[silver_saleslt_address] AS a
END
