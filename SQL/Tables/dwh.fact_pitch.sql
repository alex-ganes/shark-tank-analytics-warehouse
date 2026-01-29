USE SharkTankDWH;
GO

IF NOT EXISTS ( SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dwh' AND t.name = 'fact_pitch' )
BEGIN
    CREATE TABLE dwh.fact_pitch (   pitch_id                INT IDENTITY(1,1) PRIMARY KEY,
                                    business_id	            INT NOT NULL,
                                    episode_id	            INT NOT NULL,
                                    pitch_order_in_episode	INT,
                                    ask_amount	            FLOAT,
                                    ask_equity_pct	        FLOAT,
                                    valuation_requested	    FLOAT,
                                    is_deal	                BIT,
                                    number_of_sharks	    INT,
                                    deal_amount	            FLOAT,
                                    deal_equity_pct	        FLOAT,
                                    valuation_offered	    FLOAT,
                                    is_royalty_deal	        BIT,
                                    loan        	        FLOAT,
                                    advisory_shares	        FLOAT,
                                    deal_has_conditions	    BIT,
                                    import_date             DATETIME       );
END