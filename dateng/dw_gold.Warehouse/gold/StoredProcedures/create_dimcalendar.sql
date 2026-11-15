CREATE PROC [gold].[create_dimcalendar]
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
    -- Gold dimension: generated calendar spine.
    -- No silver dependency - this proc is the smoke test for the gold layer.
    -- Range is intentionally fixed here; widen it in this block when the estate moves on.
    DECLARE @DateFrom DATE = '2018-01-01';
    DECLARE @DateTo   DATE = '2026-12-31';

    IF EXISTS (select 1 from [INFORMATION_SCHEMA].[TABLES] WHERE TABLE_TYPE ='BASE TABLE' AND TABLE_SCHEMA ='gold' AND TABLE_NAME ='DimCalendar')
        DROP TABLE gold.DimCalendar

    create table gold.DimCalendar
    as
    WITH spine AS
    (
        SELECT DATEADD(day, value, @DateFrom) AS [d]
        FROM GENERATE_SERIES(0, DATEDIFF(day, @DateFrom, @DateTo))
    )
    , calc AS
    (
        SELECT [d]
            -- 1900-01-01 was a Monday, so day offset mod 7 gives 0=Monday..6=Sunday
            , CAST((DATEDIFF(day, CAST('1900-01-01' AS date), [d]) % 7) + 1 AS smallint) AS DayOfWeekNumber
        FROM spine
    )
    SELECT CAST(CONVERT(varchar(8), c.[d], 112) AS int)                                AS DateKey
        , CAST(c.[d] AS date)                                                          AS [Date]
        , CAST(YEAR(c.[d]) AS smallint)                                                AS [Year]
        , CAST(YEAR(c.[d]) * 100 + MONTH(c.[d]) AS int)                                AS YearMonth
        , CAST(MONTH(c.[d]) AS smallint)                                               AS MonthNumber
        , CAST(DATENAME(month, c.[d]) AS varchar(20))                                  AS MonthName
        , CAST(LEFT(DATENAME(month, c.[d]), 3) AS char(3))                             AS MonthShortName
        , CAST(DATEPART(quarter, c.[d]) AS smallint)                                   AS QuarterNumber
        , CAST('Q' + CAST(DATEPART(quarter, c.[d]) AS char(1)) AS char(2))             AS QuarterName
        , CAST(DAY(c.[d]) AS smallint)                                                 AS DayOfMonth
        , c.DayOfWeekNumber                                                            AS DayOfWeekNumber
        , CAST(CHOOSE(c.DayOfWeekNumber, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday') AS varchar(20)) AS DayName
        , CAST(DATEDIFF(day, DATEFROMPARTS(YEAR(c.[d]), 1, 1), c.[d]) + 1 AS smallint) AS DayOfYear
        , CAST((DATEDIFF(day, DATEFROMPARTS(YEAR(c.[d]), 1, 1), c.[d]) / 7) + 1 AS smallint) AS WeekOfYear
        , CAST(CASE WHEN c.DayOfWeekNumber IN (6, 7) THEN 1 ELSE 0 END AS bit)         AS IsWeekend
    FROM calc AS c
END
