-- =========================================================
-- FinTech Trading Analytics - ADVANCED ANALYSIS
-- Requires MySQL 8+ (CTE + Window Functions)
-- =========================================================

USE fintech_trading;

-- 1) Pareto Revenue (80/20 Rule)
WITH user_revenue AS (
  SELECT
    o.user_id,
    SUM(f.fee_amount) AS revenue
  FROM fact_trade_fill f
  JOIN fact_order o ON o.order_id = f.order_id
  GROUP BY o.user_id
),
ranked AS (
  SELECT
    user_id,
    revenue,
    SUM(revenue) OVER (ORDER BY revenue DESC) /
    SUM(revenue) OVER () AS cumulative_revenue_pct
  FROM user_revenue
)
SELECT *
FROM ranked
ORDER BY revenue DESC;

-- 2) Rolling 7-Day Revenue
SELECT
  DATE(fill_ts) AS trade_date,
  SUM(fee_amount) AS daily_revenue,
  SUM(SUM(fee_amount)) OVER (
    ORDER BY DATE(fill_ts)
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7d_revenue
FROM fact_trade_fill
GROUP BY DATE(fill_ts)
ORDER BY trade_date;

-- 3) Weighted Average Slippage
SELECT
  SUM(slippage_bps * (filled_qty * fill_price)) /
  SUM(filled_qty * fill_price) AS weighted_slippage_bps
FROM fact_trade_fill;

-- 4) Revenue Concentration (HHI)
WITH user_rev AS (
  SELECT
    o.user_id,
    SUM(f.fee_amount) AS revenue
  FROM fact_trade_fill f
  JOIN fact_order o ON o.order_id = f.order_id
  GROUP BY o.user_id
),
total AS (
  SELECT SUM(revenue) AS total_revenue FROM user_rev
)
SELECT
  SUM(POWER(revenue / total.total_revenue, 2)) AS hhi_index
FROM user_rev, total;

-- 5) Activation Cohort (Signup Month vs First Trade)
WITH first_trade AS (
  SELECT
    u.user_id,
    DATE_FORMAT(u.signup_ts, '%Y-%m') AS signup_month,
    MIN(o.order_ts) AS first_trade_date
  FROM dim_user u
  LEFT JOIN fact_order o
    ON o.user_id = u.user_id
   AND o.status IN ('FILLED','PARTIALLY_FILLED')
  GROUP BY u.user_id
)
SELECT
  signup_month,
  COUNT(*) AS users,
  SUM(CASE WHEN first_trade_date IS NOT NULL THEN 1 ELSE 0 END) AS activated_users
FROM first_trade
GROUP BY signup_month
ORDER BY signup_month;

