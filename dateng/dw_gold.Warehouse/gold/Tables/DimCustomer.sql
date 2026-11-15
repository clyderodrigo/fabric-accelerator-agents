CREATE TABLE [gold].[DimCustomer] (

	[CustomerKey]       int             NOT NULL,
	[CustomerID]        int             NULL,
	[FullName]          varchar(200)    NULL,
	[Title]             varchar(8)      NULL,
	[FirstName]         varchar(50)     NULL,
	[MiddleName]        varchar(50)     NULL,
	[LastName]          varchar(50)     NULL,
	[Suffix]            varchar(10)     NULL,
	[CompanyName]       varchar(128)    NULL,
	[SalesPerson]       varchar(256)    NULL,
	[EmailAddress]      varchar(50)     NULL,
	[Phone]             varchar(25)     NULL,
	[AddressType]       varchar(50)     NULL,
	[AddressLine1]      varchar(60)     NULL,
	[AddressLine2]      varchar(60)     NULL,
	[City]              varchar(30)     NULL,
	[StateProvince]     varchar(50)     NULL,
	[CountryRegion]     varchar(50)     NULL,
	[PostalCode]        varchar(15)     NULL,
	[ModifiedDate]      datetime2(6)    NULL
);
