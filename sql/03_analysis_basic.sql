-- =========================================================
-- FinTech Trading Analytics - BASIC ANALYSIS QUERIES
-- =========================================================

USE fintech_trading;

-- 1) Orders by status
SELECT status, COUNT(*) AS total_orders
FROM fact_order
GROUP BY status
ORDER BY total_orders DESC;

-- 2) Daily Active Traders (DAU)
SELECT
  DATE(order_ts) AS trade_date,
  COUNT(DISTINCT user_id) AS active_traders
FROM fact_order
WHERE status IN ('FILLED','PARTIALLY_FILLED')
GROUP BY DATE(order_ts)
ORDER BY trade_date;

-- 3) Daily Volume and Revenue
SELECT
  DATE(f.fill_ts) AS trade_date,
  SUM(f.filled_qty * f.fill_price) AS notional_volume,
  SUM(f.fee_amount) AS gross_revenue
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
WHERE o.status IN ('FILLED','PARTIALLY_FILLED')
GROUP BY DATE(f.fill_ts)
ORDER BY trade_date;

-- 4) Revenue by Asset Class
SELECT
  a.asset_class,
  SUM(f.fee_amount) AS gross_revenue,
  SUM(f.filled_qty * f.fill_price) AS notional_volume
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
JOIN dim_asset a ON a.asset_id = o.asset_id
GROUP BY a.asset_class;

-- 5) Top 10 Users by Revenue
SELECT
  o.user_id,
  SUM(f.fee_amount) AS total_revenue
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
GROUP BY o.user_id
ORDER BY total_revenue DESC
LIMIT 10;

-- 6) Revenue by Acquisition Channel
SELECT
  u.acquisition_channel,
  SUM(f.fee_amount) AS gross_revenue,
  COUNT(DISTINCT u.user_id) AS traders
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
JOIN dim_user u ON u.user_id = o.user_id
GROUP BY u.acquisition_channel
ORDER BY gross_revenue DESC;

-- 7) Average Slippage by Venue
SELECT
  venue,
  COUNT(*) AS fills,
  AVG(slippage_bps) AS avg_slippage_bps
FROM fact_trade_fill
GROUP BY venue
ORDER BY avg_slippage_bps DESC;
