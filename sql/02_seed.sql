USE fintech_trading;

-- =========================
-- SAFE SETTINGS (Workbench)
-- =========================
SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;

-- =========================
-- PARAMETROS
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
-- CLEANUP (re-run safe)
-- =========================
-- Use TRUNCATE with FK checks OFF
TRUNCATE TABLE fact_risk_event;
TRUNCATE TABLE fact_cash_ledger;
TRUNCATE TABLE fact_position_snapshot;
TRUNCATE TABLE fact_trade_fill;
TRUNCATE TABLE fact_order;

TRUNCATE TABLE dim_calendar;
TRUNCATE TABLE dim_promo;
TRUNCATE TABLE dim_asset;
TRUNCATE TABLE dim_user;

-- =========================
-- UTIL: numbers 0..9999
-- (compatible with MySQL 5.7+)
-- =========================
CREATE TABLE IF NOT EXISTS util_numbers (
  n INT NOT NULL PRIMARY KEY
) ENGINE=InnoDB;

-- Fill util_numbers if empty
INSERT IGNORE INTO util_numbers (n)
SELECT ones.n + tens.n*10 + hundreds.n*100 + thousands.n*1000 AS n
FROM (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) ones
CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) tens
CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) hundreds
CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) thousands;

-- =========================
-- 1) DIM_CALENDAR
-- =========================
INSERT INTO dim_calendar (calendar_date, year, month, week, day_of_week)
SELECT
  DATE_ADD(@start_date, INTERVAL n DAY) AS calendar_date,
  YEAR(DATE_ADD(@start_date, INTERVAL n DAY)) AS year,
  MONTH(DATE_ADD(@start_date, INTERVAL n DAY)) AS month,
  WEEK(DATE_ADD(@start_date, INTERVAL n DAY), 3) AS week,
  DAYOFWEEK(DATE_ADD(@start_date, INTERVAL n DAY)) AS day_of_week
FROM util_numbers
WHERE n < @num_days
ORDER BY n;

-- =========================
-- 2) DIM_PROMO
-- =========================
INSERT INTO dim_promo (promo_id, promo_name, start_date, end_date, discount_bps)
VALUES
(@promo_base + 1, 'New Year Fee Discount', '2026-01-01', '2026-01-15', 15),
(@promo_base + 2, 'Referral Boost',        '2026-01-10', '2026-02-10', 10),
(@promo_base + 3, 'Crypto Campaign',       '2026-02-01', '2026-03-01', 20);

-- =========================
-- 3) DIM_ASSET (30)
-- =========================
INSERT INTO dim_asset (asset_id, symbol, asset_name, asset_class, quote_ccy)
SELECT
  @asset_base + n AS asset_id,
  CASE
    WHEN n <= 15 THEN CONCAT('EQ', LPAD(n, 2, '0'))
    ELSE CONCAT('CR', LPAD(n-15, 2, '0'))
  END AS symbol,
  CASE
    WHEN n <= 15 THEN CONCAT('Equity ', n)
    ELSE CONCAT('Crypto ', n-15)
  END AS asset_name,
  CASE WHEN n <= 15 THEN 'equity' ELSE 'crypto' END AS asset_class,
  'USD' AS quote_ccy
FROM util_numbers
WHERE n BETWEEN 1 AND @n_assets
ORDER BY n;

-- =========================
-- 4) DIM_USER (300)
-- =========================
INSERT INTO dim_user (user_id, signup_ts, country, region, acquisition_channel, kyc_tier, is_margin_enabled)
SELECT
  @user_base + n AS user_id,
  TIMESTAMP(
    DATE_ADD(@start_date, INTERVAL FLOOR(RAND()*20) DAY),
    SEC_TO_TIME(FLOOR(RAND()*86400))
  ) AS signup_ts,
  CASE
    WHEN RAND() < 0.55 THEN 'BR'
    WHEN RAND() < 0.80 THEN 'US'
    ELSE 'MX'
  END AS country,
  CASE
    WHEN RAND() < 0.50 THEN 'NE'
    WHEN RAND() < 0.80 THEN 'SE'
    ELSE 'S'
  END AS region,
  CASE
    WHEN RAND() < 0.40 THEN 'organic'
    WHEN RAND() < 0.75 THEN 'paid_search'
    WHEN RAND() < 0.90 THEN 'affiliate'
    ELSE 'referral'
  END AS acquisition_channel,
  CASE
    WHEN RAND() < 0.55 THEN 'basic'
    WHEN RAND() < 0.90 THEN 'verified'
    ELSE 'pro'
  END AS kyc_tier,
  CASE WHEN RAND() < 0.15 THEN 1 ELSE 0 END AS is_margin_enabled
FROM util_numbers
WHERE n BETWEEN 1 AND @n_users
ORDER BY n;

-- =========================
-- 5) FACT_ORDER (5000)
-- =========================
INSERT INTO fact_order (order_id, user_id, asset_id, order_ts, side, order_type, qty, limit_price, status, promo_id)
SELECT
  @order_base + n AS order_id,
  (@user_base + 1 + FLOOR(RAND()*@n_users)) AS user_id,
  (@asset_base + 1 + FLOOR(RAND()*@n_assets)) AS asset_id,
  TIMESTAMP(
    DATE_ADD(@start_date, INTERVAL FLOOR(RAND()*@num_days) DAY),
    SEC_TO_TIME(FLOOR(RAND()*86400))
  ) AS order_ts,
  IF(RAND() < 0.52, 'BUY', 'SELL') AS side,
  IF(RAND() < 0.70, 'MARKET', 'LIMIT') AS order_type,
  ROUND(IF(RAND() < 0.50, (1 + FLOOR(RAND()*50)), (RAND()*2)), 8) AS qty,
  -- limit_price só para LIMIT
  CASE
    WHEN RAND() < 0.70 THEN NULL
    ELSE ROUND(IF(RAND() < 0.50, (20 + RAND()*200), (100 + RAND()*40000)), 8)
  END AS limit_price,
  CASE
    WHEN RAND() < 0.82 THEN 'FILLED'
    WHEN RAND() < 0.92 THEN 'CANCELLED'
    WHEN RAND() < 0.98 THEN 'PARTIALLY_FILLED'
    ELSE 'REJECTED'
  END AS status,
  CASE
    WHEN RAND() < 0.18 THEN (@promo_base + 1)
    WHEN RAND() < 0.30 THEN (@promo_base + 2)
    WHEN RAND() < 0.40 THEN (@promo_base + 3)
    ELSE NULL
  END AS promo_id
FROM util_numbers
WHERE n BETWEEN 1 AND @n_orders
ORDER BY n;

-- Ajuste: para LIMIT, garantir limit_price; para MARKET, forçar NULL
UPDATE fact_order
SET limit_price = ROUND(IF(RAND() < 0.50, (20 + RAND()*200), (100 + RAND()*40000)), 8)
WHERE order_type='LIMIT' AND limit_price IS NULL;

UPDATE fact_order
SET limit_price = NULL
WHERE order_type='MARKET';

-- =========================
-- 6) FACT_TRADE_FILL
-- (1 fill por FILLED/PARTIAL)
-- + 30% FILLED ganham um 2º fill
-- =========================
INSERT INTO fact_trade_fill (fill_id, order_id, fill_ts, filled_qty, fill_price, venue, fee_amount, fee_ccy, slippage_bps)
SELECT
  (@fill_base + o.order_id - @order_base) AS fill_id,
  o.order_id,
  DATE_ADD(o.order_ts, INTERVAL FLOOR(RAND()*600) SECOND) AS fill_ts,
  CASE
    WHEN o.status='PARTIALLY_FILLED' THEN ROUND(o.qty * (0.30 + RAND()*0.50), 8)
    WHEN o.status='FILLED' THEN o.qty
    ELSE 0
  END AS filled_qty,
  ROUND(COALESCE(o.limit_price, (20 + RAND()*200)) * (1 + (RAND()-0.5)/100), 8) AS fill_price,
  CASE
    WHEN RAND() < 0.60 THEN 'internal'
    WHEN RAND() < 0.85 THEN 'exchange_a'
    ELSE 'exchange_b'
  END AS venue,
  ROUND(
    (CASE WHEN o.status IN ('FILLED','PARTIALLY_FILLED') THEN 1 ELSE 0 END) *
    ((CASE WHEN o.status='PARTIALLY_FILLED' THEN (o.qty * (0.30 + RAND()*0.50)) ELSE o.qty END)
     * COALESCE(o.limit_price, (20 + RAND()*200)) * 0.001),
    8
  ) AS fee_amount,
  'USD' AS fee_ccy,
  ROUND(
    CASE WHEN a.asset_class='crypto' THEN (RAND()*25) ELSE (RAND()*8) END,
    4
  ) AS slippage_bps
FROM fact_order o
JOIN dim_asset a ON a.asset_id = o.asset_id
WHERE o.status IN ('FILLED','PARTIALLY_FILLED');

INSERT INTO fact_trade_fill (fill_id, order_id, fill_ts, filled_qty, fill_price, venue, fee_amount, fee_ccy, slippage_bps)
SELECT
  (@fill_base + 100000 + o.order_id - @order_base) AS fill_id,
  o.order_id,
  DATE_ADD(o.order_ts, INTERVAL 600 + FLOOR(RAND()*1200) SECOND) AS fill_ts,
  ROUND(o.qty * (0.10 + RAND()*0.25), 8) AS filled_qty,
  ROUND(COALESCE(o.limit_price, (20 + RAND()*200)) * (1 + (RAND()-0.5)/80), 8) AS fill_price,
  IF(RAND() < 0.50, 'exchange_a', 'exchange_b') AS venue,
  ROUND((o.qty * (0.10 + RAND()*0.25) * COALESCE(o.limit_price, (20 + RAND()*200)) * 0.001), 8) AS fee_amount,
  'USD' AS fee_ccy,
  ROUND(CASE WHEN a.asset_class='crypto' THEN (RAND()*30) ELSE (RAND()*10) END, 4) AS slippage_bps
FROM fact_order o
JOIN dim_asset a ON a.asset_id = o.asset_id
WHERE o.status='FILLED'
  AND RAND() < 0.30;

-- =========================
-- 7) FACT_CASH_LEDGER
-- =========================
-- Depósito inicial
INSERT INTO fact_cash_ledger (ledger_id, user_id, entry_ts, entry_type, amount, ccy)
SELECT
  @ledger_base + (u.user_id - @user_base) AS ledger_id,
  u.user_id,
  DATE_ADD(u.signup_ts, INTERVAL FLOOR(RAND()*3600) SECOND) AS entry_ts,
  'DEPOSIT',
  ROUND(100 + RAND()*1900, 8),
  'USD'
FROM dim_user u;

-- Taxas como saída negativa
INSERT INTO fact_cash_ledger (ledger_id, user_id, entry_ts, entry_type, amount, ccy)
SELECT
  @ledger_base + 200000 + f.fill_id AS ledger_id,
  o.user_id,
  f.fill_ts,
  'FEE',
  ROUND(-ABS(f.fee_amount), 8),
  f.fee_ccy
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id;

-- =========================
-- 8) FACT_POSITION_SNAPSHOT
-- 50 usuários x 5 assets x 60 dias = 15k linhas
-- =========================
INSERT INTO fact_position_snapshot (user_id, asset_id, snapshot_date, position_qty, avg_cost, mkt_price, unreal_pnl)
SELECT
  (@user_base + u.n) AS user_id,
  (@asset_base + a.n) AS asset_id,
  DATE_ADD(@start_date, INTERVAL d.n DAY) AS snapshot_date,
  ROUND((RAND()*5), 8) AS position_qty,
  ROUND(20 + RAND()*200, 8) AS avg_cost,
  ROUND(20 + RAND()*200, 8) AS mkt_price,
  ROUND(((20 + RAND()*200) - (20 + RAND()*200)) * (RAND()*5), 8) AS unreal_pnl
FROM (SELECT n FROM util_numbers WHERE n BETWEEN 1 AND 50) u
CROSS JOIN (SELECT n FROM util_numbers WHERE n BETWEEN 1 AND 5) a
CROSS JOIN (SELECT n FROM util_numbers WHERE n BETWEEN 0 AND (@num_days-1)) d;

-- =========================
-- 9) FACT_RISK_EVENT (~1%)
-- =========================
INSERT INTO fact_risk_event (risk_event_id, user_id, event_ts, event_type, severity, notes)
SELECT
  @risk_base + u.user_id,
  u.user_id,
  TIMESTAMP(
    DATE_ADD(@start_date, INTERVAL 10 + FLOOR(RAND()*(@num_days-10)) DAY),
    SEC_TO_TIME(FLOOR(RAND()*86400))
  ) AS event_ts,
  CASE
    WHEN RAND() < 0.50 THEN 'MARGIN_CALL'
    WHEN RAND() < 0.80 THEN 'RESTRICTION'
    ELSE 'LIQUIDATION'
  END AS event_type,
  1 + FLOOR(RAND()*5) AS severity,
  'Auto-generated risk flag' AS notes
FROM dim_user u
WHERE RAND() < 0.01;

-- =========================
-- QUICK CHECK
-- =========================
SELECT 'users' AS tbl, COUNT(*) cnt FROM dim_user
UNION ALL SELECT 'assets', COUNT(*) FROM dim_asset
UNION ALL SELECT 'orders', COUNT(*) FROM fact_order
UNION ALL SELECT 'fills', COUNT(*) FROM fact_trade_fill
UNION ALL SELECT 'ledger', COUNT(*) FROM fact_cash_ledger
UNION ALL SELECT 'positions', COUNT(*) FROM fact_position_snapshot
UNION ALL SELECT 'risk', COUNT(*) FROM fact_risk_event;

-- restore
SET FOREIGN_KEY_CHECKS = 1;
SET SQL_SAFE_UPDATES = 1;