USE SharkTankDWH;
GO

IF NOT EXISTS ( SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dwh' AND t.name = 'fact_deal_shark' )
BEGIN
    CREATE TABLE dwh.fact_deal_shark (  deal_shark_id           INT IDENTITY(1,1) PRIMARY KEY,
                                        pitch_id                INT NOT NULL,
                                        shark_id	            INT NOT NULL,
                                        investment_amount       FLOAT,
                                        investment_equity_pct   FLOAT,
                                        import_date             DATETIME       );
END