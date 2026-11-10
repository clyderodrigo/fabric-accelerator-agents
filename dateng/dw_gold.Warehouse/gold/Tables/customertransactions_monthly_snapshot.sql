CREATE TABLE [gold].[customertransactions_monthly_snapshot] (

	[TransactionTypeID] int NULL, 
	[TransactionTypeName] varchar(8000) NULL, 
	[PaymentMethodID] int NULL, 
	[PaymentMethodName] varchar(8000) NULL, 
	[TransactionMonth] date NULL, 
	[AmountExcludingTax] decimal(38,2) NULL, 
	[TaxAmount] decimal(38,2) NULL, 
	[TransactionAmount] decimal(38,2) NULL, 
	[OutstandingBalance] decimal(38,2) NULL
);