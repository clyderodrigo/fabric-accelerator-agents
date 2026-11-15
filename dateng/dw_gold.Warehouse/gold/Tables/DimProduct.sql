CREATE TABLE [gold].[DimProduct] (

	[ProductKey]            int             NOT NULL,
	[ProductID]             int             NULL,
	[ProductName]           varchar(50)     NULL,
	[ProductNumber]         varchar(25)     NULL,
	[Color]                 varchar(15)     NULL,
	[Size]                  varchar(5)      NULL,
	[Weight]                decimal(8,2)    NULL,
	[StandardCost]          decimal(19,4)   NULL,
	[ListPrice]             decimal(19,4)   NULL,
	[SellStartDate]         date            NULL,
	[SellEndDate]           date            NULL,
	[DiscontinuedDate]      date            NULL,
	[ProductCategoryID]     int             NULL,
	[CategoryName]          varchar(50)     NULL,
	[ParentCategoryID]      int             NULL,
	[ParentCategoryName]    varchar(50)     NULL,
	[ProductModelID]        int             NULL,
	[ProductModelName]      varchar(50)     NULL,
	[ProductDescription]    varchar(400)    NULL,
	[ModifiedDate]          datetime2(6)    NULL
);
