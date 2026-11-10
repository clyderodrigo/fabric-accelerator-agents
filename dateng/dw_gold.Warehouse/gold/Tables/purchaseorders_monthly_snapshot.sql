CREATE TABLE [gold].[purchaseorders_monthly_snapshot] (

	[SupplierID] int NULL, 
	[POMonth] date NULL, 
	[POAmount] decimal(38,2) NULL, 
	[TaxAmount] decimal(38,2) NULL, 
	[POCount] int NULL
);