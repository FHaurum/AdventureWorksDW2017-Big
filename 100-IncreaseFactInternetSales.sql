SET NOCOUNT ON;

DECLARE @backupFilename nvarchar(128);
DECLARE @numberOfRecords int;

-- Default backup path for SQL2017 installation on C: drive
SET @backupFilename = 'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\Backup\';

--SET @numberOfRecords =    1 * 1000 * 1000;
--SET @numberOfRecords =   10 * 1000 * 1000;
--SET @numberOfRecords =   25 * 1000 * 1000;
--SET @numberOfRecords =   50 * 1000 * 1000;
--SET @numberOfRecords =  100 * 1000 * 1000;
--SET @numberOfRecords =  250 * 1000 * 1000;

--------------------------------------
--                                  --
-- No more parameters to be changed --
--                                  --
--------------------------------------

DECLARE @backupName nvarchar(128);
DECLARE @currentNumberOfRecords int;
DECLARE @databaseLogFilename nvarchar(128);
DECLARE @databaseName nvarchar(128);
DECLARE @factInternetSalesTable TABLE(
	ProductKey int NOT NULL,
	CustomerKey int NOT NULL,
	PromotionKey int NOT NULL,
	CurrencyKey int NOT NULL,
	SalesTerritoryKey int NOT NULL,
	SalesOrderNumber nvarchar(20) NOT NULL,
	SalesOrderLineNumber tinyint NOT NULL,
	OrderQuantity smallint NOT NULL,
	UnitPrice money NOT NULL,
	ExtendedAmount money NOT NULL,
	UnitPriceDiscountPct float NOT NULL,
	DiscountAmount float NOT NULL,
	ProductStandardCost money NOT NULL,
	TotalProductCost money NOT NULL,
	SalesAmount money NOT NULL,
	TaxAmt money NOT NULL,
	Freight money NOT NULL,
	CarrierTrackingNumber nvarchar(25) NULL,
	CustomerPONumber nvarchar(25) NULL,
	OrderDate datetime NULL,
	DueDate datetime NULL,
	ShipDate datetime NULL
);
DECLARE @maxDate date;
DECLARE @maxDueDate date;
DECLARE @maxRevisionNumber smallint;
DECLARE @message nvarchar(max);
DECLARE @runFlag bit;
DECLARE @salesOrderNumberPart  nvarchar(10);
DECLARE @stmt nvarchar(max);
DECLARE @year int;

SET @runFlag = 1;

-- Check if RevisionNumber in dbo.FactInternetSales has the data type smallint
IF NOT EXISTS(
	SELECT *
	FROM sys.schemas AS sch
	INNER JOIN sys.objects AS o ON (o.schema_id = sch.schema_id)
	INNER JOIN sys.columns AS c ON (c.object_id = o.object_id)
	INNER JOIN sys.systypes AS st ON (st.xtype = c.system_type_id)
	WHERE (sch.name = 'dbo') AND (o.name = 'FactInternetSales') AND (c.name = 'RevisionNumber') AND (st.name = 'smallint')
)
BEGIN
	SET @runFlag = 0;
	SET @message = 'STOP - Remember to run the script ''001-ModifyDatabase'' to change the data type for RevisionNumber';
	RAISERROR ('%s', 10, 1, @message) WITH NOWAIT;
END;

IF (OBJECT_ID('dbo.spGenerateCalendar', 'P') IS NULL)
BEGIN
	SET @runFlag = 0;
	SET @message = 'STOP - Remember to run the script ''002-spGenerateCalendar''';
	RAISERROR ('%s', 10, 1, @message) WITH NOWAIT;
END;

IF (@numberOfRecords IS NULL) OR (@numberOfRecords <= 0)
BEGIN
	SET @runFlag = 0;
	SET @message = 'STOP - The parameter @numberOfRecords must be set to a postive number';
	RAISERROR ('%s', 10, 1, @message) WITH NOWAIT;
END
ELSE BEGIN
	-- Get number of records in dbo.FactInternetSales
	SET @currentNumberOfRecords = (SELECT COUNT(*) FROM dbo.FactInternetSales);
	IF (@currentNumberOfRecords >= @numberOfRecords)
	BEGIN
		SET @runFlag = 0;
		SET @message = 'STOP - There are already ' + FORMAT(@currentNumberOfRecords, '0,0') + ' records in dbo.FactInternetSales';
		RAISERROR ('%s', 10, 1, @message) WITH NOWAIT;
	END;
END;
 
IF (@runFlag = 1)
BEGIN
	-- Load table with the original FactInternetSales data where RevisionNumber = 1
	INSERT INTO @factInternetSalesTable(
		ProductKey, CustomerKey, PromotionKey, CurrencyKey, SalesTerritoryKey
		,SalesOrderNumber, SalesOrderLineNumber
		,OrderQuantity
		,UnitPrice, ExtendedAmount
		,UnitPriceDiscountPct, DiscountAmount
		,ProductStandardCost, TotalProductCost, SalesAmount, TaxAmt
		,Freight
		,CarrierTrackingNumber, CustomerPONumber
		,OrderDate, DueDate, ShipDate
	)
	SELECT
		fis.ProductKey, fis.CustomerKey, fis.PromotionKey, fis.CurrencyKey, fis.SalesTerritoryKey
		,fis.SalesOrderNumber, fis.SalesOrderLineNumber
		,fis.OrderQuantity
		,fis.UnitPrice, fis.ExtendedAmount
		,fis.UnitPriceDiscountPct, fis.DiscountAmount
		,fis.ProductStandardCost, fis.TotalProductCost, fis.SalesAmount, fis.TaxAmt
		,fis.Freight
		,fis.CarrierTrackingNumber, fis.CustomerPONumber
		,fis.OrderDate, fis.DueDate, fis.ShipDate
	FROM dbo.FactInternetSales AS fis
	WHERE (fis.RevisionNumber = 1)

	-- Get the highest revision number
	SET @maxRevisionNumber = (
		SELECT MAX(fis.RevisionNumber)
		FROM dbo.FactInternetSales AS fis
	);

	-- Get the latest DueDate in FactInternetSales
	SET @maxDueDate = (
		SELECT MAX(fis.DueDate)
		FROM dbo.FactInternetSales AS fis
	);

	-- Get the latest date in our calendar dimension
	SET @maxDate = (
		SELECT MAX(dd.FullDateAlternateKey)
		FROM dbo.DimDate AS dd
	);

	WHILE (1 = 1)
	BEGIN
		-- A quick check for number of rows in table. This number must not be expected to be 100% correct
		SET @currentNumberOfRecords = (
			SELECT SUM(p.rows)
			FROM sys.schemas AS sch
			INNER JOIN sys.objects AS o ON (o.schema_id = sch.schema_id)
			INNER JOIN sys.partitions AS p ON (p.object_id = o.object_id)
			WHERE (sch.name = 'dbo') AND (o.name = 'FactInternetSales') AND (p.index_id IN (0, 1))
		);

		-- Have we reached the target?
		IF (@currentNumberOfRecords >= @numberOfRecords)
		BEGIN
			-- OK - but lets us check the hard way using COUNT(*)
			IF ((SELECT COUNT(*) FROM dbo.FactInternetSales) >= @numberOfRecords)
			BEGIN
				-- We have reached the target - let us stop
				BREAK;
			END;
		END;

		-- Generate another year in the calendar dimension if latest DueDate is in the same year as the latest calendar date
		IF (YEAR(@maxDueDate) = YEAR(@maxDate))
		BEGIN
			-- Create calendar for next year
			SET @year = YEAR(@maxDate) + 1;
			EXEC dbo.spGenerateCalendar @year = @year;

			-- Get the latest date in our calendar dimension
			SET @maxDate = (
				SELECT MAX(dd.FullDateAlternateKey)
				FROM dbo.DimDate AS dd
			);
		END;

		-- Increase the max revision number
		SET @maxRevisionNumber += 1;

		-- Construct the part to be added to the sales order number
		SET @salesOrderNumberPart  = '-' + RIGHT(REPLICATE('0', 4) + CAST(@maxRevisionNumber AS nvarchar), 4);

		-- Inset a new set of records into FactInternetSales by:
		--   a) SalesOrderNumber is added the suffix '-<4 digit revison number>'
		--      For revision number 123 the original sales order number SO43697 will be SO43697-0123
		--   b) Set RevisionNumber to @maxRevisionNumber
		--   c) Increase all the money values with 0,1% * @maxRevisionNumber
		--      For revision number 123 the money values are increased by 12,3%
		--   d) For all dates add @maxRevisionNumber
		INSERT INTO dbo.FactInternetSales(
			ProductKey
			,OrderDateKey, DueDateKey, ShipDateKey
			,CustomerKey, PromotionKey, CurrencyKey, SalesTerritoryKey
			,SalesOrderNumber, SalesOrderLineNumber, RevisionNumber
			,OrderQuantity, UnitPrice, ExtendedAmount, UnitPriceDiscountPct, DiscountAmount, ProductStandardCost, TotalProductCost, SalesAmount, TaxAmt, Freight
			,CarrierTrackingNumber, CustomerPONumber
			,OrderDate, DueDate, ShipDate)
		SELECT
			a.ProductKey
			,(YEAR(a.OrderDate) * 100 * 100) + (MONTH(a.OrderDate) * 100) + DAY(a.OrderDate) AS OrderDateKey
			,(YEAR(a.DueDate)   * 100 * 100) + (MONTH(a.DueDate)   * 100) + DAY(a.DueDate)   AS DueDateKey
			,(YEAR(a.ShipDate)  * 100 * 100) + (MONTH(a.ShipDate)  * 100) + DAY(a.ShipDate)  AS ShipDateKey
			,CustomerKey, PromotionKey, CurrencyKey, SalesTerritoryKey
			,SalesOrderNumber, SalesOrderLineNumber, RevisionNumber
			,OrderQuantity, UnitPrice, ExtendedAmount, UnitPriceDiscountPct, DiscountAmount, ProductStandardCost, TotalProductCost, SalesAmount, TaxAmt, Freight
			,CarrierTrackingNumber, CustomerPONumber
			,OrderDate, DueDate, ShipDate
		FROM (
			SELECT
				fis.ProductKey
				,fis.CustomerKey, fis.PromotionKey, fis.CurrencyKey, fis.SalesTerritoryKey
				,fis.SalesOrderNumber + @salesOrderNumberPart AS SalesOrderNumber
				,fis.SalesOrderLineNumber
				,@maxRevisionNumber AS RevisionNumber
				,fis.OrderQuantity
				,fis.UnitPrice      * (1 + (@maxRevisionNumber / 1000.0)) AS UnitPrice
				,fis.ExtendedAmount * (1 + (@maxRevisionNumber / 1000.0)) AS ExtendedAmount
				,fis.UnitPriceDiscountPct
				,fis.DiscountAmount
				,fis.ProductStandardCost * (1 + (@maxRevisionNumber / 1000.0)) AS ProductStandardCost
				,fis.TotalProductCost    * (1 + (@maxRevisionNumber / 1000.0)) AS TotalProductCost
				,fis.SalesAmount         * (1 + (@maxRevisionNumber / 1000.0)) AS SalesAmount
				,fis.TaxAmt              * (1 + (@maxRevisionNumber / 1000.0)) AS TaxAmt
				,fis.Freight             * (1 + (@maxRevisionNumber / 1000.0)) AS Freight
				,fis.CarrierTrackingNumber, fis.CustomerPONumber
				,DATEADD(DAY, @maxRevisionNumber, fis.OrderDate) AS OrderDate
				,DATEADD(DAY, @maxRevisionNumber, fis.DueDate)   AS DueDate
				,DATEADD(DAY, @maxRevisionNumber, fis.ShipDate)  AS ShipDate
			FROM @factInternetSalesTable AS fis
		) AS a;

		-- Get the latest DueDate in FactInternetSales
		SET @maxDueDate = (
			SELECT MAX(DATEADD(DAY, @maxRevisionNumber, fis.DueDate))
			FROM @factInternetSalesTable AS fis
		);

		-- A quick check for number of rows in table. This number must not be expected to be 100% correct
		SET @currentNumberOfRecords = (
			SELECT SUM(p.rows)
			FROM sys.schemas AS sch
			INNER JOIN sys.objects AS o ON (o.schema_id = sch.schema_id)
			INNER JOIN sys.partitions AS p ON (p.object_id = o.object_id)
			WHERE (sch.name = 'dbo') AND (o.name = 'FactInternetSales') AND (p.index_id IN (0, 1))
		);

		-- Print out info message
		SET @message = 'Number of records approximately ' + FORMAT(@currentNumberOfRecords, '0,0') + ' @maxRevisionNumber ' + CAST(@maxRevisionNumber AS nvarchar) + ' ' + CAST(SYSDATETIME() AS nvarchar);
		RAISERROR ('%s', 10, 1, @message) WITH NOWAIT;
	END;

	-- Print out info message - but now the 100% exact number
	SET @currentNumberOfRecords = (SELECT COUNT(*) FROM dbo.FactInternetSales);
	SET @message = 'Number of records ' + FORMAT(@currentNumberOfRecords, '0,0') + ' @maxRevisionNumber ' + CAST(@maxRevisionNumber AS nvarchar) + ' ' + CAST(SYSDATETIME() AS nvarchar);
	RAISERROR ('%s', 10, 1, @message) WITH NOWAIT;

	-- Shrink the log file
	SET @databaseLogFilename = (
		SELECT df.name
		FROM sys.database_files AS df
		WHERE (df.type_desc = 'LOG')
	);
	SET @stmt = 'DBCC SHRINKFILE (''' + @databaseLogFilename + ''' , 0, TRUNCATEONLY);';
	EXEC(@stmt);

	-- Create the name of the backup file
	IF (RIGHT(@backupFilename, 1) <> '\')
	BEGIN
		SET @backupFilename += '\';
	END;
	SET @backupFilename += DB_NAME() + '-'
		+ RIGHT(REPLICATE('0', 3) + CAST(@numberOfRecords / 1000 / 1000 AS nvarchar), 4)
		+ '.bak';

	-- Give the backup a meaningful name
	SET @backupName = DB_NAME() + ' Full Database Backup with ' + FORMAT(@currentNumberOfRecords, '0,0') + ' rows in dbo.FactInsertSales';

	-- Backup the database
	SET @stmt = '
		BACKUP DATABASE ' + QUOTENAME(DB_NAME()) + '
			TO DISK = @backupFilename
			WITH COPY_ONLY, NOFORMAT, INIT, NAME = @backupName, SKIP, NOREWIND, NOUNLOAD, COMPRESSION
			,STATS = 5;
	';
	EXEC sp_executesql
		@stmt
		,N'@backupFilename nvarchar(128), @backupName nvarchar(128)'
		,@backupFilename = @backupFilename, @backupName = @backupName;
END;
