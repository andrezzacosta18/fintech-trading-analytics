-- =========================================================
-- FinTech Trading Analytics - Advanced Analysis
-- Requires MySQL 8+ (CTE + Window Functions)
-- =========================================================

USE fintech_trading;

-- 1) Pareto Revenue (cumulative revenue share by user)
WITH user_revenue AS (
  SELECT
    o.user_id,
    SUM(-f.fee_amount) AS revenue
  FROM fact_trade_fill f
  JOIN fact_order o ON o.order_id = f.order_id
  WHERE o.status IN ('FILLED','PARTIALLY_FILLED')
  GROUP BY o.user_id
),
ranked AS (
  SELECT
    user_id,
    revenue,
    SUM(revenue) OVER (ORDER BY revenue DESC) / NULLIF(SUM(revenue) OVER (), 0) AS cumulative_revenue_pct
  FROM user_revenue
)
SELECT
  user_id,
  revenue,
  cumulative_revenue_pct
FROM ranked
ORDER BY revenue DESC;

-- 2) Rolling 7-Day Revenue (calendar-aligned)
WITH daily AS (
  SELECT
    c.calendar_date AS trade_date,
    COALESCE(SUM(-f.fee_amount), 0) AS daily_revenue
  FROM dim_calendar c
  LEFT JOIN fact_trade_fill f
    ON DATE(f.fill_ts) = c.calendar_date
  LEFT JOIN fact_order o
    ON o.order_id = f.order_id
   AND o.status IN ('FILLED','PARTIALLY_FILLED')
  WHERE c.calendar_date BETWEEN @start_date AND DATE_ADD(@start_date, INTERVAL @num_days-1 DAY)
  GROUP BY c.calendar_date
)
SELECT
  trade_date,
  daily_revenue,
  SUM(daily_revenue) OVER (
    ORDER BY trade_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7d_revenue
FROM daily
ORDER BY trade_date;

-- 3) Weighted Average Slippage (notional-weighted)
SELECT
  SUM(f.slippage_bps * (f.filled_qty * f.fill_price)) /
  NULLIF(SUM(f.filled_qty * f.fill_price), 0) AS weighted_slippage_bps
FROM fact_trade_fill f
JOIN fact_order o ON o.order_id = f.order_id
WHERE o.status IN ('FILLED','PARTIALLY_FILLED');

-- 4) Revenue Concentration (HHI)
WITH user_rev AS (
  SELECT
    o.user_id,
    SUM(-f.fee_amount) AS revenue
  FROM fact_trade_fill f
  JOIN fact_order o ON o.order_id = f.order_id
  WHERE o.status IN ('FILLED','PARTIALLY_FILLED')
  GROUP BY o.user_id
),
tot AS (
  SELECT SUM(revenue) AS total_revenue FROM user_rev
)
SELECT
  SUM(POWER(user_rev.revenue / NULLIF(tot.total_revenue, 0), 2)) AS hhi_index
FROM user_rev
CROSS JOIN tot;

-- 5) Activation Cohort (Signup Month vs First Fill)
WITH first_fill AS (
  SELECT
    u.user_id,
    DATE_FORMAT(u.signup_ts, '%Y-%m') AS signup_month,
    MIN(f.fill_ts) AS first_trade_ts
  FROM dim_user u
  LEFT JOIN fact_order o
    ON o.user_id = u.user_id
   AND o.status IN ('FILLED','PARTIALLY_FILLED')
  LEFT JOIN fact_trade_fill f
    ON f.order_id = o.order_id
  GROUP BY u.user_id, DATE_FORMAT(u.signup_ts, '%Y-%m')
)
SELECT
  signup_month,
  COUNT(*) AS users,
  SUM(CASE WHEN first_trade_ts IS NOT NULL THEN 1 ELSE 0 END) AS activated_users,
  ROUND(SUM(CASE WHEN first_trade_ts IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 4) AS activation_rate
FROM first_fill
GROUP BY signup_month
ORDER BY signup_month;