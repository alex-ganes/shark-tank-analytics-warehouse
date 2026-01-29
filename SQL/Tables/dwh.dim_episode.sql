USE SharkTankDWH;
GO

IF NOT EXISTS ( SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dwh' AND t.name = 'dim_episode' )
BEGIN
    CREATE TABLE dwh.dim_episode (  episode_id            INT IDENTITY(1,1) PRIMARY KEY,
                                    season_id             INT NOT NULL,
                                    episode_in_season_num INT NOT NULL,
                                    air_date_id           INT,
                                    us_viewership         FLOAT,
                                    import_date           DATETIME  );
END
