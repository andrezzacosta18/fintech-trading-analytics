-- =========================================================
-- FinTech Trading Analytics - SEED DATA
-- MySQL 5.7+
-- =========================================================

USE fintech_trading;

SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;

-- =========================
-- PARAMETERS
-- =========================
SET @start_date = DATE('2026-01-01');
SET @num_days   = 60;

SET @n_users  = 300;
SET @n_assets = 30;
SET @n_orders = 5000;

SET @user_base   = 10000;
SET @asset_base  = 200;
SET @promo_base  = 900;
SET @order_base  = 1000000;
SET @fill_base   = 5000000;
SET @ledger_base = 8000000;
SET @risk_base   = 7000000;

-- =========================
-- CLEAN TABLES
-- =========================
TRUNCATE TABLE fact_risk_event;
TRUNCATE TABLE fact_cash_ledger;
TRUNCATE TABLE fact_position_snapshot;
TRUNCATE TABLE fact_trade_fill;
TRUNCATE TABLE fact_order;

TRUNCATE TABLE dim_calendar;
TRUNCATE TABLE dim_promo;
TRUNCATE TABLE dim_asset;
TRUNCATE TABLE dim_user;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================
-- UTIL TABLE (0..9999)
-- =========================
CREATE TABLE IF NOT EXISTS util_numbers (
  n INT NOT NULL PRIMARY KEY
) ENGINE=InnoDB;

INSERT IGNORE INTO util_numbers (n)
SELECT ones.n + tens.n*10 + hundreds.n*100 + thousands.n*1000
FROM (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) ones
CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) tens
CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) hundreds
CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) thousands;

-- =========================
-- DIM_CALENDAR
-- =========================
INSERT INTO dim_calendar (calendar_date, year, month, week, day_of_week)
SELECT
  DATE_ADD(@start_date, INTERVAL n DAY),
  YEAR(DATE_ADD(@start_date, INTERVAL n DAY)),
  MONTH(DATE_ADD(@start_date, INTERVAL n DAY)),
  WEEK(DATE_ADD(@start_date, INTERVAL n DAY), 3),
  DAYOFWEEK(DATE_ADD(@start_date, INTERVAL n DAY))
FROM util_numbers
WHERE n < @num_days;

-- =========================
-- DIM_PROMO
-- =========================
INSERT INTO dim_promo (promo_id, promo_name, start_date, end_date, discount_bps)
VALUES
(@promo_base + 1, 'New Year Fee Discount', '2026-01-01', '2026-01-15', 15),
(@promo_base + 2, 'Referral Boost',        '2026-01-10', '2026-02-10', 10),
(@promo_base + 3, 'Crypto Campaign',       '2026-02-01', '2026-03-01', 20);

-- =========================
-- DIM_ASSET
-- =========================
INSERT INTO dim_asset (asset_id, symbol, asset_name, asset_class, quote_ccy)
SELECT
  @asset_base + n,
  CASE
    WHEN n <= 15 THEN CONCAT('EQ', LPAD(n, 2, '0'))
    ELSE CONCAT('CR', LPAD(n-15, 2, '0'))
  END,
  CASE
    WHEN n <= 15 THEN CONCAT('Equity ', n)
    ELSE CONCAT('Crypto ', n-15)
  END,
  CASE WHEN n <= 15 THEN 'equity' ELSE 'crypto' END,
  'USD'
FROM util_numbers
WHERE n BETWEEN 1 AND @n_assets;

-- =========================
-- DIM_USER
-- =========================
INSERT INTO dim_user (user_id, signup_ts, country, region, acquisition_channel, kyc_tier, is_margin_enabled)
SELECT
  @user_base + n,
  TIMESTAMP(
    DATE_ADD(@start_date, INTERVAL FLOOR(RAND()*20) DAY),
    SEC_TO_TIME(FLOOR(RAND()*86400))
  ),
  CASE
    WHEN RAND() < 0.55 THEN 'BR'
    WHEN RAND() < 0.80 THEN 'US'
    ELSE 'MX'
  END,
  CASE
    WHEN RAND() < 0.50 THEN 'NE'
    WHEN RAND() < 0.80 THEN 'SE'
    ELSE 'S'
  END,
  CASE
    WHEN RAND() < 0.40 THEN 'organic'
    WHEN RAND() < 0.75 THEN 'paid_search'
    WHEN RAND() < 0.90 THEN 'affiliate'
    ELSE 'referral'
  END,
  CASE
    WHEN RAND() < 0.55 THEN 'basic'
    WHEN RAND() < 0.90 THEN 'verified'
    ELSE 'pro'
  END,
  CASE WHEN RAND() < 0.15 THEN 1 ELSE 0 END
FROM util_numbers
WHERE n BETWEEN 1 AND @n_users;

-- =========================
-- FACT_ORDER
-- =========================
INSERT INTO fact_order (order_id, user_id, asset_id, order_ts, side, order_type, qty, limit_price, status, promo_id)
SELECT
  @order_base + n,
  (@user_base + 1 + FLOOR(RAND()*@n_users)),
  (@asset_base + 1 + FLOOR(RAND()*@n_assets)),
  TIMESTAMP(
    DATE_ADD(@start_date, INTERVAL FLOOR(RAND()*@num_days) DAY),
    SEC_TO_TIME(FLOOR(RAND()*86400))
  ),
  IF(RAND() < 0.52, 'BUY', 'SELL'),
  IF(RAND() < 0.70, 'MARKET', 'LIMIT'),
  ROUND(IF(RAND() < 0.50, (1 + FLOOR(RAND()*50)), (RAND()*2)), 8),
  NULL,
  CASE
    WHEN RAND() < 0.82 THEN 'FILLED'
    WHEN RAND() < 0.92 THEN 'CANCELLED'
    WHEN RAND() < 0.98 THEN 'PARTIALLY_FILLED'
    ELSE 'REJECTED'
  END,
  CASE
    WHEN RAND() < 0.18 THEN (@promo_base + 1)
    WHEN RAND() < 0.30 THEN (@promo_base + 2)
    WHEN RAND() < 0.40 THEN (@promo_base + 3)
    ELSE NULL
  END
FROM util_numbers
WHERE n BETWEEN 1 AND @n_orders;

-- Ajustes para LIMIT / MARKET
UPDATE fact_order
SET limit_price = ROUND(20 + RAND()*200, 8)
WHERE order_type='LIMIT';

UPDATE fact_order
SET limit_price = NULL
WHERE order_type='MARKET';

-- =========================
-- FACT_TRADE_FILL
-- =========================
INSERT INTO fact_trade_fill (fill_id, order_id, fill_ts, filled_qty, fill_price, venue, fee_amount, fee_ccy, slippage_bps)
SELECT
  (@fill_base + o.order_id - @order_base),
  o.order_id,
  DATE_ADD(o.order_ts, INTERVAL FLOOR(RAND()*600) SECOND),
  o.qty,
  ROUND(COALESCE(o.limit_price, (20 + RAND()*200)), 8),
  IF(RAND() < 0.6, 'internal', 'exchange_a'),
  ROUND(o.qty * COALESCE(o.limit_price, (20 + RAND()*200)) * 0.001, 8),
  'USD',
  ROUND(RAND()*10, 4)
FROM fact_order o
WHERE o.status IN ('FILLED','PARTIALLY_FILLED');

-- =========================
-- FACT_CASH_LEDGER
-- =========================
INSERT INTO fact_cash_ledger (ledger_id, user_id, entry_ts, entry_type, amount, ccy)
SELECT
  @ledger_base + (user_id - @user_base),
  user_id,
  signup_ts,
  'DEPOSIT',
  ROUND(100 + RAND()*1900, 8),
  'USD'
FROM dim_user;

INSERT INTO fact_cash_ledger (ledger_id, user_id, entry_ts, entry_type, amount, ccy)
SELECT
  @ledger_base + 200000 + f.fill_id,
  o.user_id,
  f.fill_ts,
  'FEE',
  -ABS(f.fee_amount),
  'USD'
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id;

-- =========================
-- FACT_RISK_EVENT (~1%)
-- =========================
INSERT INTO fact_risk_event (risk_event_id, user_id, event_ts, event_type, severity, notes)
SELECT
  @risk_base + user_id,
  user_id,
  NOW(),
  'MARGIN_CALL',
  3,
  'Auto-generated risk flag'
FROM dim_user
WHERE RAND() < 0.01;

SET SQL_SAFE_UPDATES = 1;
