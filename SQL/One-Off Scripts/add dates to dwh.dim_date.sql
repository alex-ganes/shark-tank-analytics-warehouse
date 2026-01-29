-- add dates to dwh.dim_date

EXEC dwh.populate_dim_date @start_year = 2000, @end_year = 2030;