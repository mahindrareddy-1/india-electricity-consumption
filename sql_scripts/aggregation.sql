-- ============================================================
-- Plugging into the Future: India's Electricity Consumption
-- Analytics Views  |  MySQL 8.0+ (tested on MariaDB 10.11)
-- ============================================================
USE electricity_db;

-- Note: columns below are named usage_period rather than the more obvious
-- "year_month" -- YEAR_MONTH is a reserved MySQL/MariaDB keyword.

CREATE OR REPLACE VIEW vw_monthly_national_trend AS
SELECT
    YEAR(usage_date)                    AS usage_year,
    MONTH(usage_date)                   AS usage_month,
    DATE_FORMAT(usage_date, '%Y-%m')    AS usage_period,
    ROUND(SUM(usage_mwh), 2)            AS total_usage_mwh,
    ROUND(AVG(usage_mwh), 2)            AS avg_daily_usage_mwh,
    COUNT(DISTINCT state)               AS reporting_states,
    COUNT(DISTINCT usage_date)          AS days_in_month
FROM electricity_consumption
GROUP BY YEAR(usage_date), MONTH(usage_date), DATE_FORMAT(usage_date, '%Y-%m')
ORDER BY usage_year, usage_month;

CREATE OR REPLACE VIEW vw_regional_demand AS
SELECT
    region,
    CASE region
        WHEN 'NR'  THEN 'Northern Region'
        WHEN 'WR'  THEN 'Western Region'
        WHEN 'SR'  THEN 'Southern Region'
        WHEN 'ER'  THEN 'Eastern Region'
        WHEN 'NER' THEN 'North Eastern Region'
        ELSE region
    END                                  AS region_name,
    YEAR(usage_date)                     AS usage_year,
    MONTH(usage_date)                    AS usage_month,
    DATE_FORMAT(usage_date, '%Y-%m')     AS usage_period,
    ROUND(SUM(usage_mwh), 2)             AS total_usage_mwh,
    ROUND(AVG(usage_mwh), 2)             AS avg_daily_usage_mwh,
    COUNT(DISTINCT state)                AS num_states
FROM electricity_consumption
GROUP BY region, usage_year, usage_month, usage_period
ORDER BY region, usage_year, usage_month;

CREATE OR REPLACE VIEW vw_lockdown_recovery AS
WITH phase_data AS (
    SELECT
        state, region, usage_mwh,
        CASE
            WHEN usage_date BETWEEN '2020-01-01' AND '2020-03-24' THEN 'Pre-Lockdown'
            WHEN usage_date BETWEEN '2020-03-25' AND '2020-06-30' THEN 'Lockdown'
            WHEN usage_date BETWEEN '2020-07-01' AND '2020-12-05' THEN 'Post-Lockdown'
        END AS lockdown_phase
    FROM electricity_consumption
    WHERE usage_date BETWEEN '2020-01-01' AND '2020-12-05'
),
phase_avg AS (
    SELECT state, region, lockdown_phase, AVG(usage_mwh) AS avg_usage_mwh
    FROM phase_data
    WHERE lockdown_phase IS NOT NULL
    GROUP BY state, region, lockdown_phase
),
baseline AS (
    SELECT state, avg_usage_mwh AS pre_lockdown_avg_mwh
    FROM phase_avg
    WHERE lockdown_phase = 'Pre-Lockdown'
)
SELECT
    p.state, p.region, p.lockdown_phase,
    ROUND(p.avg_usage_mwh, 2)                                    AS avg_daily_usage_mwh,
    ROUND(b.pre_lockdown_avg_mwh, 2)                              AS pre_lockdown_avg_mwh,
    ROUND(100 * p.avg_usage_mwh / b.pre_lockdown_avg_mwh, 1)      AS pct_of_pre_lockdown
FROM phase_avg p
JOIN baseline b ON p.state = b.state
ORDER BY p.state, FIELD(p.lockdown_phase, 'Pre-Lockdown', 'Lockdown', 'Post-Lockdown');
