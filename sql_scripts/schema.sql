-- ============================================================
-- Plugging into the Future: India's Electricity Consumption
-- Database Schema  |  MySQL 8.0+ (tested on MariaDB 10.11)
-- ============================================================
-- Run this FIRST. It creates two tables:
--   1) stg_consumption_raw     -- raw landing zone for the CSV import
--   2) electricity_consumption -- clean, deduplicated table Tableau/Flask use
--
-- WHY TWO TABLES: the source CSV has 165 rows where the same
-- (state, date) pair appears twice with two different usage readings,
-- concentrated on 5 dates (8-12 July 2019). Importing straight into a
-- table with a UNIQUE(state, date) constraint will throw a duplicate-key
-- error on those rows. Staging first, then de-duplicating with AVG(),
-- avoids that error AND keeps the analysis numbers honest (rather than
-- silently double-counting those 5 days).

CREATE DATABASE IF NOT EXISTS electricity_db
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE electricity_db;

DROP TABLE IF EXISTS stg_consumption_raw;
CREATE TABLE stg_consumption_raw (
    state       VARCHAR(50)    NOT NULL,
    region      VARCHAR(10)    NOT NULL,
    usage_date  DATE           NOT NULL,
    usage_mwh   DECIMAL(12,2)  NOT NULL,
    latitude    DECIMAL(10,6),
    longitude   DECIMAL(10,6)
) ENGINE = InnoDB;

DROP TABLE IF EXISTS electricity_consumption;
CREATE TABLE electricity_consumption (
    consumption_id  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    state           VARCHAR(50)    NOT NULL,
    region          VARCHAR(10)    NOT NULL,
    usage_date      DATE           NOT NULL,
    usage_mwh       DECIMAL(12,2)  NOT NULL,
    latitude        DECIMAL(10,6),
    longitude       DECIMAL(10,6),
    CONSTRAINT uq_state_date UNIQUE (state, usage_date)
) ENGINE = InnoDB;

-- NOTE ON UNITS: India's grid data is conventionally reported in Million
-- Units (1 MU = 1,000 MWh). The source CSV's usage_mwh column carries the
-- raw MU figures unconverted. Column kept as usage_mwh to match the
-- project spec -- multiply by 1000 in the transform below if you need
-- true MWh for a report.

CREATE INDEX idx_consumption_date   ON electricity_consumption(usage_date);
CREATE INDEX idx_consumption_region ON electricity_consumption(region);
CREATE INDEX idx_consumption_state  ON electricity_consumption(state);

INSERT INTO electricity_consumption (state, region, usage_date, usage_mwh, latitude, longitude)
SELECT
    state,
    region,
    usage_date,
    ROUND(AVG(usage_mwh), 2),
    AVG(latitude),
    AVG(longitude)
FROM stg_consumption_raw
GROUP BY state, region, usage_date;

SELECT
    COUNT(*)                    AS total_rows,
    COUNT(DISTINCT state)       AS total_states,
    COUNT(DISTINCT usage_date)  AS total_dates,
    MIN(usage_date)             AS earliest_date,
    MAX(usage_date)             AS latest_date
FROM electricity_consumption;
