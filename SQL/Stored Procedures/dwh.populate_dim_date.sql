USE SharkTankDWH;
GO

DROP PROCEDURE IF EXISTS dwh.populate_dim_date;
GO

CREATE PROCEDURE dwh.populate_dim_date ( @start_year INT,
                                         @end_year   INT = NULL )
AS
BEGIN
    SET NOCOUNT ON

    SET @end_year = ISNULL(@end_year, @start_year);     -- set end year if null

    IF @end_year < @start_year
        THROW 50000, '@end_year cannot be before @start_year.', 1;

    DECLARE @start_date DATE = DATEFROMPARTS(@start_year, 1, 1),
            @end_date   DATE = DATEFROMPARTS(@end_year, 12, 31);

    DECLARE @date_counter DATE = @start_date;

    DROP TABLE IF EXISTS #calendar_dates;
    CREATE TABLE #calendar_dates ([date] DATE);

    WHILE @date_counter <= @end_date                    -- get all relevant dates
        BEGIN
            INSERT INTO #calendar_dates ([date])
            SELECT @date_counter;

            SET @date_counter = DATEADD(DAY, 1, @date_counter);
        END

    INSERT INTO dwh.dim_date (                          -- add new dates to calendar table
        date_id,
        [date],
        day_of_year,
        day_of_week,
        day_of_week_num,
        [month],
        month_num,
        [year]
    )
    SELECT  YEAR(cd.[date])*10000+MONTH(cd.[date])*100+DAY(cd.[date]),
            cd.[date],
            DATEPART(DAYOFYEAR, cd.[date]),
            DATENAME(WEEKDAY, cd.[date]),
            DATEPART(WEEKDAY, cd.[date]),
            DATENAME(MONTH, cd.[date]),
            MONTH(cd.[date]),
            YEAR(cd.[date])
    FROM    #calendar_dates cd
                LEFT JOIN dwh.dim_date d ON cd.[date] = d.[date]
    WHERE   d.[date] IS NULL;
END