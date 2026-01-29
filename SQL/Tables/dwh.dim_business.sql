USE SharkTankDWH;
GO

IF NOT EXISTS ( SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dwh' AND t.name = 'dim_business' )
BEGIN
    CREATE TABLE dwh.dim_business ( business_id             INT IDENTITY(1,1) PRIMARY KEY,
                                    business_name           NVARCHAR(250) NOT NULL,
                                    industry                NVARCHAR(100),
                                    business_description    NVARCHAR(MAX),
                                    company_website         NVARCHAR(MAX),
                                    entrepreneur_names      NVARCHAR(250),
                                    entrepreneur_city       NVARCHAR(100),
                                    entrepreneur_state      NVARCHAR(20),
                                    import_date             DATETIME        );
END