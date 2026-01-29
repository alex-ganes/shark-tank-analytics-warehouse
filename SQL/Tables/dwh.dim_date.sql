USE SharkTankDWH;
GO

IF NOT EXISTS ( SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dwh' AND t.name = 'dim_date' )
BEGIN
    CREATE TABLE dwh.dim_date ( date_id             INT NOT NULL PRIMARY KEY,
                                [date]              DATE NOT NULL,
                                day_of_year         INT NOT NULL,
                                day_of_week         NVARCHAR(9) NOT NULL,
                                day_of_week_num     INT NOT NULL,
                                [month]             NVARCHAR(9) NOT NULL,
                                month_num           INT NOT NULL,
                                [year]              INT    );
END