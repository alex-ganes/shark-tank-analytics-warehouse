USE SharkTankDWH;
GO

DROP VIEW IF EXISTS analytics.vw_season_summary;
GO

CREATE VIEW analytics.vw_season_summary
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
season_viewership AS (
    SELECT  season_id,
            AVG(us_viewership) AS avg_us_viewership
    FROM    episode_base
    GROUP BY season_id
),
season_base AS (
    SELECT  s.season_id,
            s.season_label,
            s.season_number,
            sd_start.[date] AS season_start_date,
            sd_end.[date]   AS season_end_date
    FROM    dwh.dim_season s
                LEFT JOIN dwh.dim_date sd_start ON s.season_start_date_id = sd_start.date_id
                LEFT JOIN dwh.dim_date sd_end   ON s.season_end_date_id   = sd_end.date_id
),
shark_deals AS (
    SELECT  fps.pitch_id,
            MAX(CASE WHEN sh.is_main_shark = 1 THEN 1 ELSE 0 END) AS has_main_shark,
            MAX(CASE WHEN sh.is_main_shark = 0 THEN 1 ELSE 0 END) AS has_guest_shark
    FROM    dwh.fact_deal_shark fps
                JOIN dwh.dim_shark sh ON fps.shark_id = sh.shark_id
    GROUP BY fps.pitch_id
),
season_agg AS (
    SELECT  sb.season_id,
            sb.season_label,
            sb.season_number,
            sb.season_start_date,
            sb.season_end_date,
            COUNT(DISTINCT p.pitch_id) AS total_pitches,
            COUNT(DISTINCT CASE WHEN p.is_deal = 1 THEN p.pitch_id END) AS total_deals,
            SUM(p.deal_amount) AS total_investment,
            COUNT(DISTINCT fds.shark_id) AS sharks_in_deals,
            SUM(CASE WHEN p.is_royalty_deal = 1 THEN 1 ELSE 0 END) AS has_royalties,
            SUM(CASE WHEN p.advisory_shares > 0 THEN 1 ELSE 0 END) AS has_advisory_shares,
            SUM(CASE WHEN p.deal_has_conditions = 1 THEN 1 ELSE 0 END) AS has_conditions,
            COUNT(DISTINCT CASE WHEN sd.has_main_shark = 1 THEN p.pitch_id END) AS main_shark_deals,
            COUNT(DISTINCT CASE WHEN sd.has_guest_shark = 1 THEN p.pitch_id END) AS guest_shark_deals,
            COUNT(DISTINCT e.episode_id) AS total_episodes
    FROM    pitch_base p
                JOIN episode_base e ON p.episode_id = e.episode_id
                JOIN season_base sb ON e.season_id = sb.season_id
                LEFT JOIN dwh.fact_deal_shark fds ON p.pitch_id = fds.pitch_id
                LEFT JOIN shark_deals sd ON p.pitch_id = sd.pitch_id
    GROUP BY sb.season_id,
            sb.season_number,
            sb.season_label,
            sb.season_start_date,
            sb.season_end_date
)
SELECT  sa.season_label,
        sa.season_number,
        sa.season_start_date,
        sa.season_end_date,
        sa.total_episodes,
        sa.total_pitches,
        sa.total_deals,
        sa.total_deals * 1.0 / NULLIF(sa.total_pitches, 0) AS deal_rate,
        sa.total_investment,
        sa.sharks_in_deals,
        sa.has_royalties,
        sa.has_advisory_shares,
        sa.has_conditions,
        sa.main_shark_deals * 1.0 / NULLIF(sa.total_deals, 0) AS main_shark_deal_share,
        sa.guest_shark_deals * 1.0 / NULLIF(sa.total_deals, 0) AS guest_shark_deal_share,
        sv.avg_us_viewership,
        sa.total_pitches * 1.0 / NULLIF(sa.total_episodes, 0) AS pitches_per_episode,
        sa.total_deals * 1.0 / NULLIF(sa.total_episodes, 0) AS deals_per_episode
FROM    season_agg sa
            JOIN season_viewership sv ON sa.season_id = sv.season_id;