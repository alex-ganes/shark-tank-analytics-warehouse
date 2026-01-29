USE SharkTankDWH;
GO

IF NOT EXISTS ( SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dwh' AND t.name = 'dim_season' )
BEGIN
    CREATE TABLE dwh.dim_season ( season_id             INT IDENTITY(1,1) PRIMARY KEY,
                                  season_number         INT NOT NULL,
                                  season_label          NVARCHAR(10) NOT NULL,
                                  season_abbrev         NVARCHAR(5) NOT NULL,
                                  season_start_date_id  INT,
                                  season_end_date_id    INT,
                                  import_date           DATETIME,

                                  CONSTRAINT uq_dim_season_number UNIQUE (season_number) );
END