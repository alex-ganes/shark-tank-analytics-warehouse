USE SharkTankDWH;
GO

IF NOT EXISTS ( SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dwh' AND t.name = 'dim_shark' )
BEGIN
    CREATE TABLE dwh.dim_shark (    shark_id        INT IDENTITY(1,1) PRIMARY KEY,
                                    shark_name      NVARCHAR(250) NOT NULL,
                                    is_main_shark   BIT,
                                    import_date     DATETIME              );
END