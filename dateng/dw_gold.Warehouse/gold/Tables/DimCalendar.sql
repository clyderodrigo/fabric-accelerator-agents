CREATE TABLE [gold].[DimCalendar] (

	[DateKey]           int         NOT NULL,
	[Date]              date        NOT NULL,
	[Year]              smallint    NULL,
	[YearMonth]         int         NULL,
	[MonthNumber]       smallint    NULL,
	[MonthName]         varchar(20) NULL,
	[MonthShortName]    char(3)     NULL,
	[QuarterNumber]     smallint    NULL,
	[QuarterName]       char(2)     NULL,
	[DayOfMonth]        smallint    NULL,
	[DayOfWeekNumber]   smallint    NULL,
	[DayName]           varchar(20) NULL,
	[DayOfYear]         smallint    NULL,
	[WeekOfYear]        smallint    NULL,
	[IsWeekend]         bit         NULL
);
