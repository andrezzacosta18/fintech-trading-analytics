-- =========================================================
-- FinTech Trading Analytics - Basic Analysis Queries
-- =========================================================

USE fintech_trading;

-- 1) Orders by status
SELECT status, COUNT(*) AS total_orders
FROM fact_order
GROUP BY status
ORDER BY total_orders DESC;

-- 2) Daily Active Traders (DAU) based on executed orders
SELECT
  DATE(o.order_ts) AS trade_date,
  COUNT(DISTINCT o.user_id) AS active_traders
FROM fact_order o
WHERE o.status IN ('FILLED','PARTIALLY_FILLED')
GROUP BY DATE(o.order_ts)
ORDER BY trade_date;

-- 2b) Daily Active Traders (DAU) based on fills (recommended)
SELECT
  DATE(f.fill_ts) AS trade_date,
  COUNT(DISTINCT o.user_id) AS active_traders
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
WHERE o.status IN ('FILLED','PARTIALLY_FILLED')
GROUP BY DATE(f.fill_ts)
ORDER BY trade_date;

-- 3) Daily Volume and Revenue (fees as positive revenue)
SELECT
  DATE(f.fill_ts) AS trade_date,
  SUM(f.filled_qty * f.fill_price) AS notional_volume,
  SUM(-f.fee_amount) AS gross_revenue
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
WHERE o.status IN ('FILLED','PARTIALLY_FILLED')
GROUP BY DATE(f.fill_ts)
ORDER BY trade_date;

-- 4) Revenue by Asset Class
SELECT
  a.asset_class,
  SUM(-f.fee_amount) AS gross_revenue,
  SUM(f.filled_qty * f.fill_price) AS notional_volume
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
JOIN dim_asset a ON a.asset_id = o.asset_id
WHERE o.status IN ('FILLED','PARTIALLY_FILLED')
GROUP BY a.asset_class
ORDER BY gross_revenue DESC;

-- 5) Top 10 Users by Revenue
SELECT
  o.user_id,
  SUM(-f.fee_amount) AS total_revenue
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
WHERE o.status IN ('FILLED','PARTIALLY_FILLED')
GROUP BY o.user_id
ORDER BY total_revenue DESC
LIMIT 10;

-- 6) Revenue by Acquisition Channel
SELECT
  u.acquisition_channel,
  SUM(-f.fee_amount) AS gross_revenue,
  COUNT(DISTINCT o.user_id) AS traders
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
JOIN dim_user u ON u.user_id = o.user_id
WHERE o.status IN ('FILLED','PARTIALLY_FILLED')
GROUP BY u.acquisition_channel
ORDER BY gross_revenue DESC;

-- 7) Slippage by Venue (simple average)
SELECT
  venue,
  COUNT(*) AS fills,
  AVG(slippage_bps) AS avg_slippage_bps
FROM fact_trade_fill
GROUP BY venue
ORDER BY avg_slippage_bps DESC;

-- 7b) Slippage by Venue (notional-weighted average, recommended)
SELECT
  f.venue,
  COUNT(*) AS fills,
  SUM(f.slippage_bps * (f.filled_qty * f.fill_price)) / NULLIF(SUM(f.filled_qty * f.fill_price), 0) AS wavg_slippage_bps
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
WHERE o.status IN ('FILLED','PARTIALLY_FILLED')
GROUP BY f.venue
ORDER BY wavg_slippage_bps DESC;