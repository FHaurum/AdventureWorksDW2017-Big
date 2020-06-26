CREATE OR ALTER PROCEDURE dbo.spGenerateCalendar
(	
	 @year int
)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @dateId date;

	SET @dateId = DATEFROMPARTS(@year, 1, 1);

	-- If january 1. does not exist for the given year we assume that the entire year is missing
	IF NOT EXISTS(SELECT * FROM dbo.DimDate AS dd WHERE (dd.FullDateAlternateKey = @dateId))
	BEGIN
		-- Loop to create a calendar for the entire year
		WHILE (YEAR(@dateId) < (@year + 1))
		BEGIN
			INSERT INTO dbo.DimDate(
				DateKey
				,FullDateAlternateKey
				,DayNumberOfWeek
				,EnglishDayNameOfWeek
				,SpanishDayNameOfWeek
				,FrenchDayNameOfWeek
				,DayNumberOfMonth
				,DayNumberOfYear
				,WeekNumberOfYear
				,EnglishMonthName
				,SpanishMonthName
				,FrenchMonthName
				,MonthNumberOfYear
				,CalendarQuarter
				,CalendarYear
				,CalendarSemester
				,FiscalQuarter
				,FiscalYear
				,FiscalSemester
			)
			SELECT
				(YEAR(@dateId) * 100 * 100) + (MONTH(@dateId) * 100) + DAY(@dateId) AS DateKey
				,@dateId AS FullDateAlternateKey
				,DATEPART(WEEKDAY, @dateId) AS DayNumberOfWeek
				,(SELECT TOP 1 dd.EnglishDayNameOfWeek FROM dbo.DimDate AS dd WHERE (dd.DayNumberOfWeek = DATEPART(WEEKDAY, @dateId))) AS EnglishDayNameOfWeek
				,(SELECT TOP 1 dd.SpanishDayNameOfWeek FROM dbo.DimDate AS dd WHERE (dd.DayNumberOfWeek = DATEPART(WEEKDAY, @dateId))) AS SpanishDayNameOfWeek
				,(SELECT TOP 1 dd.FrenchDayNameOfWeek  FROM dbo.DimDate AS dd WHERE (dd.DayNumberOfWeek = DATEPART(WEEKDAY, @dateId))) AS FrenchDayNameOfWeek
				,DAY(@dateId) AS DayNumberOfMonth
				,DATEPART(DAYOFYEAR, @dateId) AS DayNumberOfYear
				,DATEPART(WEEK, @dateId) AS WeekNumberOfYear
				,(SELECT TOP 1 dd.EnglishMonthName FROM dbo.DimDate AS dd WHERE (dd.MonthNumberOfYear = MONTH(@dateId))) AS EnglishMonthName
				,(SELECT TOP 1 dd.SpanishMonthName FROM dbo.DimDate AS dd WHERE (dd.MonthNumberOfYear = MONTH(@dateId))) AS SpanishMonthName
				,(SELECT TOP 1 dd.FrenchMonthName  FROM dbo.DimDate AS dd WHERE (dd.MonthNumberOfYear = MONTH(@dateId))) AS FrenchMonthName
				,MONTH(@dateId) AS MonthNumberOfYear
				,DATEPART(QUARTER, @dateId) AS CalendarQuarter
				,YEAR(@dateId) AS CalendarYear
				,(SELECT TOP 1 dd.CalendarSemester FROM dbo.DimDate AS dd WHERE (dd.MonthNumberOfYear = MONTH(@dateId))) AS CalendarSemester
				,(SELECT TOP 1 dd.FiscalQuarter FROM dbo.DimDate AS dd WHERE (dd.MonthNumberOfYear = MONTH(@dateId))) AS FiscalQuarter
				,YEAR(@dateId) + CASE WHEN MONTH(@dateId) <= 6 THEN 0 ELSE 1 END AS FiscalYear
				,(SELECT TOP 1 dd.FiscalSemester FROM dbo.DimDate AS dd WHERE (dd.MonthNumberOfYear = MONTH(@dateId))) AS FiscalSemester;

			SET @DateId = DATEADD(DAY, 1, @DateId);
		END;
	END;
END;
