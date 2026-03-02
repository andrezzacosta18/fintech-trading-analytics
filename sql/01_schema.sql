-- =========================================================
-- 01_schema.sql
-- FinTech Trading Analytics (MySQL 8+)
-- Creates database, dimensions, fact tables, PKs, FKs and indexes
-- =========================================================

-- ---------------------------------------------------------
-- Database
-- ---------------------------------------------------------

CREATE DATABASE IF NOT EXISTS fintech_trading_analytics;
USE fintech_trading_analytics;

SET FOREIGN_KEY_CHECKS = 0;

-- Drop fact tables first (dependency order)
DROP TABLE IF EXISTS fact_position_snapshot;
DROP TABLE IF EXISTS fact_risk_event;
DROP TABLE IF EXISTS fact_promo_credit;
DROP TABLE IF EXISTS fact_ledger;
DROP TABLE IF EXISTS fact_fill;
DROP TABLE IF EXISTS fact_order;

-- Drop dimensions
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_asset;
DROP TABLE IF EXISTS dim_user;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================================================
-- DIMENSIONS
-- =========================================================

CREATE TABLE dim_user (
  user_id              INT PRIMARY KEY,
  signup_ts            DATETIME NOT NULL,
  acquisition_channel  VARCHAR(30) NOT NULL,
  country              CHAR(2) NOT NULL,
  kyc_tier             TINYINT NOT NULL,
  is_margin_enabled    BOOLEAN NOT NULL DEFAULT FALSE
) ENGINE=InnoDB;

CREATE INDEX idx_user_signup ON dim_user(signup_ts);
CREATE INDEX idx_user_channel ON dim_user(acquisition_channel);
CREATE INDEX idx_user_country ON dim_user(country);


CREATE TABLE dim_asset (
  asset_id     INT PRIMARY KEY,
  symbol       VARCHAR(20) NOT NULL,
  asset_class  VARCHAR(20) NOT NULL,   -- EQUITY | CRYPTO
  venue        VARCHAR(30) NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX ux_asset_symbol ON dim_asset(symbol, asset_class);
CREATE INDEX idx_asset_class ON dim_asset(asset_class);
CREATE INDEX idx_asset_venue ON dim_asset(venue);


CREATE TABLE dim_date (
  date_id        INT PRIMARY KEY,      -- yyyymmdd
  calendar_date  DATE NOT NULL,
  year           SMALLINT NOT NULL,
  quarter        TINYINT NOT NULL,
  month          TINYINT NOT NULL,
  day            TINYINT NOT NULL,
  week_of_year   TINYINT NOT NULL,
  day_of_week    TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX ux_dim_date_calendar ON dim_date(calendar_date);


-- =========================================================
-- FACT TABLES
-- =========================================================

CREATE TABLE fact_order (
  order_id     BIGINT PRIMARY KEY,
  user_id      INT NOT NULL,
  asset_id     INT NOT NULL,
  side         ENUM('BUY','SELL') NOT NULL,
  order_type   ENUM('MARKET','LIMIT') NOT NULL,
  qty          DECIMAL(18,8) NOT NULL,
  limit_price  DECIMAL(18,8) NULL,
  status       ENUM('NEW','CANCELLED','PARTIALLY_FILLED','FILLED') NOT NULL,
  order_ts     DATETIME NOT NULL,

  CONSTRAINT fk_order_user
    FOREIGN KEY (user_id) REFERENCES dim_user(user_id),

  CONSTRAINT fk_order_asset
    FOREIGN KEY (asset_id) REFERENCES dim_asset(asset_id)
) ENGINE=InnoDB;

CREATE INDEX idx_order_user_ts ON fact_order(user_id, order_ts);
CREATE INDEX idx_order_asset_ts ON fact_order(asset_id, order_ts);
CREATE INDEX idx_order_status ON fact_order(status);


CREATE TABLE fact_fill (
  fill_id      BIGINT PRIMARY KEY,
  order_id     BIGINT NOT NULL,
  fill_ts      DATETIME NOT NULL,
  fill_qty     DECIMAL(18,8) NOT NULL,
  fill_price   DECIMAL(18,8) NOT NULL,
  slippage_bps DECIMAL(10,4) NOT NULL,

  CONSTRAINT fk_fill_order
    FOREIGN KEY (order_id) REFERENCES fact_order(order_id)
) ENGINE=InnoDB;

CREATE INDEX idx_fill_order_ts ON fact_fill(order_id, fill_ts);
CREATE INDEX idx_fill_ts ON fact_fill(fill_ts);


CREATE TABLE fact_ledger (
  ledger_id    BIGINT PRIMARY KEY,
  user_id      INT NOT NULL,
  entry_ts     DATETIME NOT NULL,
  entry_type   ENUM('DEPOSIT','WITHDRAWAL','FEE','TRADE_BUY','TRADE_SELL') NOT NULL,
  amount_usd   DECIMAL(18,8) NOT NULL,

  CONSTRAINT fk_ledger_user
    FOREIGN KEY (user_id) REFERENCES dim_user(user_id)
) ENGINE=InnoDB;

CREATE INDEX idx_ledger_user_ts ON fact_ledger(user_id, entry_ts);
CREATE INDEX idx_ledger_type_ts ON fact_ledger(entry_type, entry_ts);


CREATE TABLE fact_promo_credit (
  promo_id           BIGINT PRIMARY KEY,
  user_id            INT NOT NULL,
  credit_ts          DATETIME NOT NULL,
  promo_code         VARCHAR(30) NOT NULL,
  credit_amount_usd  DECIMAL(18,8) NOT NULL,

  CONSTRAINT fk_promo_user
    FOREIGN KEY (user_id) REFERENCES dim_user(user_id)
) ENGINE=InnoDB;

CREATE INDEX idx_promo_user_ts ON fact_promo_credit(user_id, credit_ts);
CREATE INDEX idx_promo_code ON fact_promo_credit(promo_code);


CREATE TABLE fact_risk_event (
  risk_event_id  BIGINT PRIMARY KEY,
  user_id        INT NOT NULL,
  event_ts       DATETIME NOT NULL,
  severity       ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL,
  event_type     VARCHAR(40) NOT NULL,
  notes          VARCHAR(255),

  CONSTRAINT fk_risk_user
    FOREIGN KEY (user_id) REFERENCES dim_user(user_id)
) ENGINE=InnoDB;

CREATE INDEX idx_risk_user_ts ON fact_risk_event(user_id, event_ts);
CREATE INDEX idx_risk_severity ON fact_risk_event(severity);


CREATE TABLE fact_position_snapshot (
  snapshot_id       BIGINT PRIMARY KEY,
  date_id           INT NOT NULL,
  user_id           INT NOT NULL,
  asset_id          INT NOT NULL,
  position_qty      DECIMAL(18,8) NOT NULL,
  last_price_usd    DECIMAL(18,8),
  market_value_usd  DECIMAL(18,8),

  CONSTRAINT fk_position_date
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id),

  CONSTRAINT fk_position_user
    FOREIGN KEY (user_id) REFERENCES dim_user(user_id),

  CONSTRAINT fk_position_asset
    FOREIGN KEY (asset_id) REFERENCES dim_asset(asset_id)
) ENGINE=InnoDB;

CREATE UNIQUE INDEX ux_position_unique
  ON fact_position_snapshot(date_id, user_id, asset_id);

CREATE INDEX idx_position_user_date
  ON fact_position_snapshot(user_id, date_id);

CREATE INDEX idx_position_asset_date
  ON fact_position_snapshot(asset_id, date_id);
