USE SharkTankDWH;
GO

DROP VIEW IF EXISTS analytics.vw_alltime_summary;
GO

CREATE VIEW analytics.vw_alltime_summary
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
            e.us_viewership
    FROM    dwh.dim_episode e
),
us_viewership AS (
    SELECT  AVG(us_viewership) AS avg_us_viewership
    FROM    episode_base
),
shark_deals AS (
    SELECT DISTINCT fps.pitch_id,
                    MAX(CASE WHEN s.is_main_shark = 1 THEN 1 ELSE 0 END) AS has_main_shark,
                    MAX(CASE WHEN s.is_main_shark = 0 THEN 1 ELSE 0 END) AS has_guest_shark
    FROM    dwh.fact_deal_shark fps
    JOIN    dwh.dim_shark s ON fps.shark_id = s.shark_id
    GROUP BY fps.pitch_id
),
agg AS (
    SELECT  COUNT(DISTINCT se.season_id) AS total_seasons,
            COUNT(DISTINCT e.episode_id) AS total_episodes,
            COUNT(DISTINCT p.pitch_id) AS total_pitches,
            COUNT(DISTINCT CASE WHEN p.is_deal = 1 THEN p.pitch_id END) AS total_deals,
            SUM(p.deal_amount) AS total_investment,
            COUNT(DISTINCT fds.shark_id) AS sharks_in_deals,
            SUM(CASE WHEN p.is_royalty_deal = 1 THEN 1 ELSE 0 END) AS has_royalties,
            SUM(CASE WHEN p.advisory_shares > 0 THEN 1 ELSE 0 END) AS has_advisory_shares,
            SUM(CASE WHEN p.deal_has_conditions = 1 THEN 1 ELSE 0 END) AS has_conditions,
            COUNT(DISTINCT CASE WHEN sd.has_main_shark = 1 THEN p.pitch_id END) AS main_shark_deals,
            COUNT(DISTINCT CASE WHEN sd.has_guest_shark = 1 THEN p.pitch_id END) AS guest_shark_deals
    FROM    pitch_base p
                JOIN episode_base e ON p.episode_id = e.episode_id
                JOIN dwh.dim_season se ON e.season_id = se.season_id
                LEFT JOIN dwh.fact_deal_shark fds ON p.pitch_id = fds.pitch_id
                LEFT JOIN shark_deals sd ON p.pitch_id = sd.pitch_id
)
SELECT  agg.total_seasons,
        agg.total_episodes,
        agg.total_pitches,
        agg.total_deals,
        agg.total_deals * 1.0 / NULLIF(agg.total_pitches, 0) AS deal_rate,
        agg.total_investment,
        agg.sharks_in_deals,
        agg.has_royalties,
        agg.has_advisory_shares,
        agg.has_conditions,
        agg.main_shark_deals * 1.0 / NULLIF(agg.total_deals, 0) AS main_shark_deal_share,
        agg.guest_shark_deals * 1.0 / NULLIF(agg.total_deals, 0) AS guest_shark_deal_share,
        usv.avg_us_viewership,
        agg.total_pitches * 1.0 / NULLIF(agg.total_episodes, 0) AS pitches_per_episode,
        agg.total_deals   * 1.0 / NULLIF(agg.total_episodes, 0) AS deals_per_episode,
        agg.total_pitches * 1.0 / NULLIF(agg.total_seasons, 0) AS pitches_per_season,
        agg.total_deals   * 1.0 / NULLIF(agg.total_seasons, 0) AS deals_per_season
FROM    agg
            CROSS JOIN us_viewership usv;