-- Change the data type from tinyint to smallint
ALTER TABLE dbo.FactInternetSales ALTER COLUMN RevisionNumber smallint NOT NULL;
GO

-- Rebuild the clustered index in order to use page compression
ALTER INDEX PK_FactInternetSales_SalesOrderNumber_SalesOrderLineNumber ON dbo.FactInternetSales REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
GO
