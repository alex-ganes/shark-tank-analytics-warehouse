USE SharkTankDWH;
GO

DROP PROCEDURE IF EXISTS dwh.load_shark_tank_dw;
GO

CREATE PROCEDURE dwh.load_shark_tank_dw

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @batch_import_date DATETIME = ( SELECT MAX(import_date) FROM stage.pitch_raw_data );

    IF @batch_import_date IS NOT NULL           -- staging data loaded
    AND EXISTS ( SELECT 1 FROM dwh.dim_date )   -- dates loaded
        BEGIN

        ---------------------------------------------------------------
        ----------------------- LOAD DIMENSIONS -----------------------
        ---------------------------------------------------------------

            -- upsert into dwh.dim_shark

            MERGE dwh.dim_shark AS s
            USING (
                SELECT  main_shark.shark_name, 
                        1 AS is_main_shark
                FROM (  VALUES  ('Barbara Corcoran'), -- hardcode main sharks
                                ('Mark Cuban'),
                                ('Lori Greiner'),
                                ('Robert Herjavec'),
                                ('Daymond John'),
                                ('Kevin O''Leary')
                        ) main_shark(shark_name)

                UNION ALL

                SELECT DISTINCT LTRIM(RTRIM(guest_name.value)) AS shark_name,
                       0 AS is_main_shark
                FROM stage.pitch_raw_data stg
                        CROSS APPLY STRING_SPLIT(REPLACE(stg.guest_name, ', and ', ', '), ',') guest_name -- multiple guests
                WHERE stg.guest_name IS NOT NULL
            ) AS stg
            ON s.shark_name = stg.shark_name -- natural key

            WHEN MATCHED THEN
                UPDATE 
                SET shark_name = stg.shark_name,
                    is_main_shark = stg.is_main_shark,
                    import_date = @batch_import_date

            WHEN NOT MATCHED THEN
                INSERT (    shark_name,
                            is_main_shark,
                            import_date  )
                VALUES (    stg.shark_name, 
                            stg.is_main_shark, 
                            @batch_import_date  );

            -- upsert into dwh.dim_business

            WITH stg AS (
                SELECT  startup_name AS business_name,
                        industry,
                        business_description,
                        company_website,
                        entrepreneur_names,
                        pitchers_city AS entrepreneur_city,
                        pitchers_state AS entrepreneur_state,
                        ROW_NUMBER() OVER (
                            PARTITION BY startup_name
                            ORDER BY original_air_date DESC -- if business occurs multiple times, take most recent
                        ) AS occurrence_number
                FROM    stage.pitch_raw_data              
            )
            MERGE dwh.dim_business AS b
            USING (
                SELECT  business_name,
                        industry,
                        business_description,
                        company_website,
                        entrepreneur_names,
                        entrepreneur_city,
                        entrepreneur_state
                FROM    stg
                WHERE   occurrence_number = 1
            ) AS stg
            ON b.business_name = stg.business_name -- natural key

            WHEN MATCHED THEN
                UPDATE 
                SET industry = stg.industry,
                    business_description = stg.business_description,
                    company_website = stg.company_website,
                    entrepreneur_names = stg.entrepreneur_names,
                    entrepreneur_city = stg.entrepreneur_city,
                    entrepreneur_state = stg.entrepreneur_state,
                    import_date = @batch_import_date

            WHEN NOT MATCHED THEN
                INSERT (    business_name,
                            industry,
                            business_description,
                            company_website,
                            entrepreneur_names,
                            entrepreneur_city, 
                            entrepreneur_state,
                            import_date )
                VALUES (    stg.business_name, 
                            stg.industry, 
                            stg.business_description,
                            stg.company_website, 
                            stg.entrepreneur_names,
                            stg.entrepreneur_city,
                            stg.entrepreneur_state,
                            @batch_import_date );

            -- upsert into dwh.dim_season
       
            MERGE dwh.dim_season AS s
            USING (
                SELECT  stg.season_number,
                        'Season '+CAST(stg.season_number AS VARCHAR(5)) AS season_label,
                        'S'+CAST(stg.season_number AS VARCHAR(5)) AS season_abbrev,
                        MIN(sd.date_id) AS season_start_date_id,
                        MAX(ed.date_id) AS season_end_date_id
                FROM    stage.pitch_raw_data stg 
                            LEFT JOIN dwh.dim_date sd ON stg.season_start = sd.[date]
                            LEFT JOIN dwh.dim_date ed ON stg.season_end = ed.[date]
                GROUP BY stg.season_number
            ) AS stg
            ON s.season_number = stg.season_number -- natural key

            WHEN MATCHED THEN
                UPDATE 
                SET season_number = stg.season_number,
                    season_label = stg.season_label,
                    season_abbrev = stg.season_abbrev,
                    season_start_date_id = stg.season_start_date_id,
                    season_end_date_id = stg.season_end_date_id,
                    import_date = @batch_import_date

            WHEN NOT MATCHED THEN
                INSERT (    season_number,
                            season_label,
                            season_abbrev,
                            season_start_date_id,
                            season_end_date_id,
                            import_date  )
                VALUES (    stg.season_number, 
                            stg.season_label, 
                            stg.season_abbrev,
                            stg.season_start_date_id, 
                            stg.season_end_date_id,
                            @batch_import_date  );

            -- upsert into dwh.dim_episode

            MERGE dwh.dim_episode AS e
            USING (
                SELECT  s.season_id,
                        stg.episode_number AS episode_in_season_num,
                        MAX(ad.date_id) AS air_date_id,
                        MAX(stg.us_viewership) AS us_viewership
                FROM    stage.pitch_raw_data stg
                            LEFT JOIN dwh.dim_season s ON stg.season_number = s.season_number
                            LEFT JOIN dwh.dim_date ad ON stg.original_air_date = ad.[date]
                GROUP BY season_id, episode_number
            ) AS stg
            ON  e.season_id = stg.season_id     -- natural key
            AND e.episode_in_season_num = stg.episode_in_season_num

            WHEN MATCHED THEN
                UPDATE 
                SET season_id = stg.season_id,
                    episode_in_season_num = stg.episode_in_season_num,
                    air_date_id = stg.air_date_id,
                    us_viewership = stg.us_viewership,
                    import_date = @batch_import_date

            WHEN NOT MATCHED THEN
                INSERT (    season_id,
                            episode_in_season_num,
                            air_date_id,
                            us_viewership,
                            import_date )
                VALUES (    stg.season_id, 
                            stg.episode_in_season_num, 
                            stg.air_date_id,
                            stg.us_viewership, 
                            @batch_import_date );

        ---------------------------------------------------------------
        ----------------------- LOAD FACTS ----------------------------
        ---------------------------------------------------------------
 
        -- facts are append-only; removal from source does not retract historical records 
        -- type 1 dimensions and mutable facts: overwrite on match for simplicity

            -- upsert into dwh.fact_pitch
       
            MERGE dwh.fact_pitch AS p
            USING (
                SELECT  COALESCE(b.business_id, 0) AS business_id,
                        COALESCE(e.episode_id, 0) AS episode_id,
                        ROW_NUMBER() OVER (
                            PARTITION BY stg.season_number, stg.episode_number
                            ORDER BY stg.pitch_number, stg.startup_name -- pitch_number is otherwise for full series
                        ) AS pitch_order_in_episode,
                        stg.original_ask_amount AS ask_amount,
                        stg.original_offered_equity / 100.0 AS ask_equity_pct,
                        stg.valuation_requested,
                        stg.got_deal AS is_deal,
                        stg.number_of_sharks_in_deal AS number_of_sharks,
                        stg.total_deal_amount AS deal_amount,
                        stg.total_deal_equity / 100.0 AS deal_equity_pct,
                        stg.deal_valuation AS valuation_offered,

                    -- note: deal subcomponents default to 0 when a deal exists but component is absent
                        CASE WHEN stg.got_deal = 1 AND stg.royalty_deal IS NULL THEN 0 ELSE stg.royalty_deal END AS is_royalty_deal,
                        CASE WHEN stg.got_deal = 1 AND stg.loan IS NULL THEN 0 ELSE stg.loan END AS loan,
                        CASE WHEN stg.got_deal = 1 AND stg.advisory_shares_equity IS NULL THEN 0 ELSE stg.advisory_shares_equity END AS advisory_shares,
                        CASE WHEN stg.got_deal = 1 AND stg.deal_has_conditions IS NULL THEN 0 ELSE stg.deal_has_conditions END AS deal_has_conditions

                FROM    stage.pitch_raw_data stg
                            LEFT JOIN dwh.dim_business b ON stg.startup_name = b.business_name
                            LEFT JOIN dwh.dim_season s ON stg.season_number = s.season_number
                            LEFT JOIN dwh.dim_episode e ON e.season_id = s.season_id
                                                        AND e.episode_in_season_num = stg.episode_number
            ) AS stg
            ON  p.business_id = stg.business_id     -- natural key
            AND p.episode_id = stg.episode_id

            WHEN MATCHED THEN
                UPDATE 
                SET business_id = stg.business_id,
                    episode_id = stg.episode_id,
                    pitch_order_in_episode = stg.pitch_order_in_episode,
                    ask_amount = stg.ask_amount,
                    ask_equity_pct = stg.ask_equity_pct,
                    valuation_requested = stg.valuation_requested,
                    is_deal = stg.is_deal,
                    number_of_sharks = stg.number_of_sharks,
                    deal_amount = stg.deal_amount,
                    deal_equity_pct = stg.deal_equity_pct,
                    valuation_offered = stg.valuation_offered,
                    is_royalty_deal = stg.is_royalty_deal,
                    loan = stg.loan,
                    advisory_shares = stg.advisory_shares,
                    deal_has_conditions = stg.deal_has_conditions,
                    import_date = @batch_import_date

            WHEN NOT MATCHED THEN
                INSERT (    business_id,
                            episode_id,
                            pitch_order_in_episode,
                            ask_amount,
                            ask_equity_pct,
                            valuation_requested,
                            is_deal,
                            number_of_sharks,
                            deal_amount,
                            deal_equity_pct,
                            valuation_offered,
                            is_royalty_deal,
                            loan,
                            advisory_shares,
                            deal_has_conditions,
                            import_date )
                VALUES (    stg.business_id,
                            stg.episode_id,
                            stg.pitch_order_in_episode,
                            stg.ask_amount,
                            stg.ask_equity_pct,
                            stg.valuation_requested,
                            stg.is_deal,
                            stg.number_of_sharks,
                            stg.deal_amount,
                            stg.deal_equity_pct,
                            stg.valuation_offered,
                            stg.is_royalty_deal,
                            stg.loan,
                            stg.advisory_shares,
                            stg.deal_has_conditions,
                            @batch_import_date );

            -- upsert into dwh.fact_deal_shark

            WITH shark_pitch AS (   SELECT  p.pitch_id,                               -- hardcode main sharks
                                            stg.barbara_corcoran_investment_amount,
                                            stg.barbara_corcoran_investment_equity,
                                            stg.mark_cuban_investment_amount,
                                            stg.mark_cuban_investment_equity,
                                            stg.lori_greiner_investment_amount,
                                            stg.lori_greiner_investment_equity,
                                            stg.robert_herjavec_investment_amount,
                                            stg.robert_herjavec_investment_equity,
                                            stg.daymond_john_investment_amount,
                                            stg.daymond_john_investment_equity,
                                            stg.kevin_o_leary_investment_amount,
                                            stg.kevin_o_leary_investment_equity,
                                            stg.guest_name,
                                            stg.guest_investment_amount,
                                            stg.guest_investment_equity
                                    FROM    stage.pitch_raw_data stg
                                                LEFT JOIN dwh.dim_business b ON stg.startup_name = b.business_name
                                                LEFT JOIN dwh.dim_season s ON stg.season_number = s.season_number
                                                LEFT JOIN dwh.dim_episode e ON e.season_id = s.season_id
                                                                            AND e.episode_in_season_num = stg.episode_number
                                                JOIN dwh.fact_pitch p ON b.business_id = p.business_id
                                                                      AND e.episode_id = p.episode_id   ),
                guest_expanded AS ( SELECT  sp.pitch_id,
                                            LTRIM(RTRIM(guest_name.value)) AS shark_name,
                                            sp.guest_investment_amount,
                                            sp.guest_investment_equity,
                                            COUNT(1) OVER (PARTITION BY sp.pitch_id) AS guest_count
                                     FROM   shark_pitch sp
                                                CROSS APPLY STRING_SPLIT(REPLACE(sp.guest_name, ', and ', ', '), ',') guest_name
                                     WHERE  sp.guest_investment_amount IS NOT NULL  )
            MERGE dwh.fact_deal_shark AS ds
            USING (
                SELECT  sp.pitch_id,
                        sh.shark_id,
                        sp.barbara_corcoran_investment_amount AS investment_amount,
                        sp.barbara_corcoran_investment_equity / 100.0 AS investment_equity_pct
                FROM shark_pitch sp
                JOIN dwh.dim_shark sh ON sh.shark_name = 'Barbara Corcoran'
                WHERE sp.barbara_corcoran_investment_amount IS NOT NULL

                UNION ALL

                SELECT  sp.pitch_id,
                        sh.shark_id,
                        sp.mark_cuban_investment_amount AS investment_amount,
                        sp.mark_cuban_investment_equity / 100.0 AS investment_equity_pct
                FROM shark_pitch sp
                JOIN dwh.dim_shark sh ON sh.shark_name = 'Mark Cuban'
                WHERE sp.mark_cuban_investment_amount IS NOT NULL

                UNION ALL

                SELECT  sp.pitch_id,
                        sh.shark_id,
                        sp.lori_greiner_investment_amount AS investment_amount,
                        sp.lori_greiner_investment_equity / 100.0 AS investment_equity_pct
                FROM shark_pitch sp
                JOIN dwh.dim_shark sh ON sh.shark_name = 'Lori Greiner'
                WHERE sp.lori_greiner_investment_amount IS NOT NULL

                UNION ALL

                SELECT  sp.pitch_id,
                        sh.shark_id,
                        sp.robert_herjavec_investment_amount AS investment_amount,
                        sp.robert_herjavec_investment_equity / 100.0 AS investment_equity_pct
                FROM shark_pitch sp
                JOIN dwh.dim_shark sh ON sh.shark_name = 'Robert Herjavec'
                WHERE sp.robert_herjavec_investment_amount IS NOT NULL

                UNION ALL

                SELECT  sp.pitch_id,
                        sh.shark_id,
                        sp.daymond_john_investment_amount AS investment_amount,
                        sp.daymond_john_investment_equity / 100.0 AS investment_equity_pct
                FROM shark_pitch sp
                JOIN dwh.dim_shark sh ON sh.shark_name = 'Daymond John'
                WHERE sp.daymond_john_investment_amount IS NOT NULL

                UNION ALL

                SELECT  sp.pitch_id,
                        sh.shark_id,
                        sp.kevin_o_leary_investment_amount AS investment_amount,
                        sp.kevin_o_leary_investment_equity / 100.0 AS investment_equity_pct
                FROM shark_pitch sp
                JOIN dwh.dim_shark sh ON sh.shark_name = 'Kevin O''Leary'
                WHERE sp.kevin_o_leary_investment_amount IS NOT NULL
        
                UNION ALL
        
                SELECT  ge.pitch_id,
                        sh.shark_id,
                        ge.guest_investment_amount / ge.guest_count AS investment_amount,
                        ge.guest_investment_equity  / ge.guest_count / 100.0 AS investment_equity_pct
                FROM    guest_expanded ge
                            JOIN dwh.dim_shark sh ON sh.shark_name = ge.shark_name            
            ) AS stg
            ON  ds.pitch_id = stg.pitch_id     -- natural key
            AND ds.shark_id = stg.shark_id

            WHEN MATCHED THEN
                UPDATE 
                SET pitch_id = stg.pitch_id,
                    shark_id = stg.shark_id,
                    investment_amount = stg.investment_amount,
                    investment_equity_pct = stg.investment_equity_pct,
                    import_date = @batch_import_date

            WHEN NOT MATCHED THEN
                INSERT (    pitch_id,
                            shark_id,
                            investment_amount,
                            investment_equity_pct,
                            import_date )
                VALUES (    stg.pitch_id,
                            stg.shark_id,
                            stg.investment_amount,
                            stg.investment_equity_pct,
                            @batch_import_date );

        ---------------------------------------------------------------
        ----------------------- DROP STAGING --------------------------
        ---------------------------------------------------------------

            TRUNCATE TABLE stage.pitch_raw_data;

        END
END