USE SharkTankDWH;
GO

DROP VIEW IF EXISTS analytics.vw_episode_summary;
GO

CREATE VIEW analytics.vw_episode_summary
AS
WITH pitch_base AS (
    SELECT  p.pitch_id,
            p.episode_id,
            p.is_deal,
            p.is_royalty_deal,
            p.advisory_shares,
            p.deal_has_conditions,
            p.deal_amount
    FROM    dwh.fact_pitch p
),
episode_base AS (
    SELECT DISTINCT e.episode_id,
            e.season_id,
            s.season_number,
            e.episode_in_season_num,
            e.us_viewership,
            d.[date] AS episode_air_date,
            CONCAT('Season ', s.season_number, ', Episode ', e.episode_in_season_num) AS episode_label
    FROM    dwh.dim_episode e
                JOIN dwh.dim_season s ON e.season_id = s.season_id
                LEFT JOIN dwh.dim_date d ON e.air_date_id = d.date_id
),
shark_deals AS (
    SELECT  fps.pitch_id,
            MAX(CASE WHEN sh.is_main_shark = 1 THEN 1 ELSE 0 END) AS has_main_shark,
            MAX(CASE WHEN sh.is_main_shark = 0 THEN 1 ELSE 0 END) AS has_guest_shark
    FROM    dwh.fact_deal_shark fps
                JOIN dwh.dim_shark sh ON fps.shark_id = sh.shark_id
    GROUP BY fps.pitch_id
),
episode_agg AS (
    SELECT  eb.episode_id,
            eb.episode_label,
            eb.season_number,
            eb.episode_in_season_num,
            eb.episode_air_date,
            eb.us_viewership,
            COUNT(DISTINCT p.pitch_id) AS total_pitches,
            COUNT(DISTINCT CASE WHEN p.is_deal = 1 THEN p.pitch_id END) AS total_deals,
            SUM(p.deal_amount) AS total_investment,
            COUNT(DISTINCT fds.shark_id) AS sharks_in_deals,
            SUM(CASE WHEN p.is_royalty_deal = 1 THEN 1 ELSE 0 END) AS has_royalties,
            SUM(CASE WHEN p.advisory_shares > 0 THEN 1 ELSE 0 END) AS has_advisory_shares,
            SUM(CASE WHEN p.deal_has_conditions = 1 THEN 1 ELSE 0 END) AS has_conditions,
            COUNT(DISTINCT CASE WHEN sd.has_main_shark = 1 THEN p.pitch_id END) AS main_shark_deals,
            COUNT(DISTINCT CASE WHEN sd.has_guest_shark = 1 THEN p.pitch_id END) AS guest_shark_deals
    FROM    episode_base eb
                JOIN pitch_base p ON eb.episode_id = p.episode_id
                LEFT JOIN dwh.fact_deal_shark fds ON p.pitch_id = fds.pitch_id
                LEFT JOIN shark_deals sd ON p.pitch_id = sd.pitch_id
    GROUP BY eb.episode_id,
             eb.episode_label,
             eb.season_number,
             eb.episode_in_season_num,
             eb.episode_air_date,
             eb.us_viewership
)
SELECT  ea.episode_label,
        ea.season_number,
        ea.episode_in_season_num,
        ea.episode_air_date,
        ea.total_pitches,
        ea.total_deals,
        ea.total_deals * 1.0 / NULLIF(ea.total_pitches, 0) AS deal_rate,
        ea.total_investment,
        ea.sharks_in_deals,
        ea.has_royalties,
        ea.has_advisory_shares,
        ea.has_conditions,
        ea.main_shark_deals  * 1.0 / NULLIF(ea.total_deals, 0) AS main_shark_deal_share,
        ea.guest_shark_deals * 1.0 / NULLIF(ea.total_deals, 0) AS guest_shark_deal_share,
        ea.us_viewership
FROM    episode_agg ea;
