
# 📊 FinTech Trading Analytics

## 📌 Project Overview

This project simulates a digital trading platform (equities and crypto) and builds a full analytics environment to evaluate:

- Revenue generation
- Trading volume
- User activation
- Execution quality (slippage)
- Revenue concentration
- Risk exposure

The objective was to design a realistic trading data warehouse and develop business-focused SQL analytics aligned with Finance, Growth, and Risk stakeholders.

---

## 🏗 Data Architecture

The project follows a star schema model.

### Dimension Tables
- `dim_user`
- `dim_asset`
- `dim_promo`
- `dim_calendar`

### Fact Tables
- `fact_order`
- `fact_trade_fill`
- `fact_cash_ledger`
- `fact_position_snapshot`
- `fact_risk_event`

### Granularity

- Orders at order level  
- Revenue at fill level  
- Positions at daily snapshot level  

---

## 📊 Key Business Metrics

- Gross Revenue (sum of trading fees)
- Notional Trading Volume
- Active Traders (DAU)
- Activation Rate (first trade ≤ 7 days)
- Weighted Slippage (bps)
- Revenue Concentration (Herfindahl Index)

---

## 🧠 Analytics Implemented

### Basic Analytics
- Revenue by day
- Volume by asset class
- Top users by revenue
- Promo impact analysis
- Slippage by venue
- Risk event distribution

### Advanced Analytics (MySQL 8+)
- Pareto Revenue (80/20 rule)
- Cohort analysis
- Rolling 7-day revenue
- Herfindahl-Hirschman Index (HHI)
- Weighted slippage analysis

---

## 🛠 Tech Stack

- MySQL
- SQL (joins, aggregations, CTEs, window functions)
- Power BI (dashboard visualization)
- Git & GitHub

---

## 📁 Repository Structure
```fintech-trading-analytics/
│
├── sql/
│ ├── 02_seed.sql
│ ├── 03_analysis_basic.sql
│ ├── 04_analysis_advanced.sql
│
├── docs/
├── powerbi/
└── README.md
```

---

## ▶️ How to Run

1. Execute `02_seed.sql` in MySQL.
2. Run `03_analysis_basic.sql` for operational metrics.
3. Run `04_analysis_advanced.sql` for advanced analytics.
4. Connect Power BI to the database for dashboard visualization.

---

## 🎯 Business Impact

This project demonstrates the ability to:

- Design realistic financial data models
- Build end-to-end analytics workflows
- Translate raw trading data into executive-level insights
- Apply financial concentration metrics (HHI)
- Evaluate execution quality and monetization efficiency

---

## 💼 Positioning

This project simulates real-world trading analytics work found in:

- FinTech companies
- Digital brokerages
- Crypto exchanges
- Trading platforms
- Financial analytics teams
