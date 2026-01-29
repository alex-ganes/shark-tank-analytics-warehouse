USE SharkTankDWH;
GO

DROP VIEW IF EXISTS analytics.vw_shark_alltime_summary;
GO

CREATE VIEW analytics.vw_shark_alltime_summary
AS
SELECT	s.shark_name,
		s.is_main_shark,
		COUNT(DISTINCT pitch_id) AS total_deals_participated,
		AVG(fds.investment_amount) AS avg_investment_amount,
		SUM(fds.investment_amount) AS total_investment_amount,
		AVG(fds.investment_equity_pct) AS avg_equity_pct_per_deal
FROM	dwh.fact_deal_shark fds
			JOIN dwh.dim_shark s ON fds.shark_id = s.shark_id
GROUP BY s.shark_name,
		s.is_main_shark;