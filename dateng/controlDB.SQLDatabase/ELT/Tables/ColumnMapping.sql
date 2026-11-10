CREATE TABLE [ELT].[ColumnMapping] (
    [MappingID]             INT            IDENTITY (1, 1) NOT NULL,
    [IngestID]              INT            NULL,
    [L1TransformID]         INT            NULL,
    [L2TransformID]         INT            NULL,
    [SourceName]            NVARCHAR (150) NOT NULL,
    [TargetName]            NVARCHAR (150) NOT NULL,
    [Description]           NVARCHAR (250) NULL,
    [TargetOrdinalPosition] INT            NOT NULL,
    [ActiveFlag]            BIT            NULL,
    [CreatedBy]             VARCHAR (128)  CONSTRAINT [DC_Attribute_CreatedBy] DEFAULT (suser_sname()) NOT NULL,
    [CreatedTimestamp]      DATETIME       CONSTRAINT [DC_Attribute_CreatedTimestamp] DEFAULT (CONVERT([datetime],(CONVERT([datetimeoffset],getdate()) AT TIME ZONE 'AUS Eastern Standard Time'))) NOT NULL,
    [ModifiedBy]            VARCHAR (128)  CONSTRAINT [DC_Attribute_ModifiedBy] DEFAULT (suser_sname()) NULL,
    [ModifiedTimestamp]     DATETIME       CONSTRAINT [DC_Attribute_ModifiedTimestamp] DEFAULT (CONVERT([datetime],(CONVERT([datetimeoffset],getdate()) AT TIME ZONE 'AUS Eastern Standard Time'))) NULL,
    CONSTRAINT [PK_Attribute] PRIMARY KEY CLUSTERED ([MappingID] ASC),
    CONSTRAINT [FK_Attribute_IngestID] FOREIGN KEY ([IngestID]) REFERENCES [ELT].[IngestDefinition] ([IngestID]),
    CONSTRAINT [FK_Attribute_L1TransformID] FOREIGN KEY ([L1TransformID]) REFERENCES [ELT].[L1TransformDefinition] ([L1TransformID]),
    CONSTRAINT [FK_Attribute_L2TransformID] FOREIGN KEY ([L2TransformID]) REFERENCES [ELT].[L2TransformDefinition] ([L2TransformID])
);


GO

