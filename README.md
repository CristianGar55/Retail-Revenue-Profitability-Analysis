# Retail Revenue & Profitability Analysis

SQL + Tableau project analyzing two years of retail transaction data to answer questions a business would actually ask — not just report metrics for their own sake.

**Live dashboard:** https://public.tableau.com/app/profile/cristian.garcia3939/viz/RetailRevenueProfitabilityAnalysis/Overview

## What this answers

- Why did revenue move month to month, and what actually drove it
- Which product category drives the most profit, not just the most revenue
- How dependent the business is on its top customers
- Where the real retention risk sits, and what it's worth in dollars

## Stack

MySQL for cleaning and analysis. Tableau Public for the dashboard.

## Data

Synthetic star-schema retail dataset — customers, products, stores, transactions. ~5,000 transactions, 200 customers, 50 products across Electronics, Fashion, and Groceries. Sept 2023–Sept 2025.

## Process

1. Normalized schema (4 tables, foreign keys) instead of working off one flat file
2. Validated the data before trusting it — null checks, range checks, duplicate checks, grain checks
3. Built two views so revenue/profit math lives in one place, not copy-pasted into every query
4. Core metrics: monthly revenue, top products, AOV, category profit
5. Two deeper cuts: revenue decomposition (volume effect vs. price effect) and customer concentration (Pareto)
6. Dashboard: 3 pages, click-to-filter actions, adjustable parameters — not just static charts

## Findings

- **$14.3M total revenue** across the window (first/last months are partial, excluded from trend analysis)
- **Electronics leads on revenue ($6.32M), Fashion leads on profit ($1.66M vs. $1.63M)** — Electronics runs a thinner margin, 25.8% vs. 26.6%
- **Groceries is the smallest category by revenue but the best margin (30.4%)** — worth a look for expansion, though margins usually compress as a category scales
- **No single lever explains revenue growth.** Some months are volume-driven, some price-driven. April 2025's peak was almost entirely price — bigger orders, not more customers
- **Revenue isn't customer-concentrated.** Top 20% of customers hold only 26.5% of revenue, well under the 60–80% you'd expect in a dependent business
- **11 of 200 customers (5.5%) are inactive 90+ days**, representing $701K (4.9%) of historical revenue sitting idle

## Data caveats

- 2023-09 and 2025-09 are partial months (data starts 9/10/23, ends 9/9/25) — excluded from trend charts
- 75 customers have a `JoinDate` recorded after their actual first purchase — used first-purchase-date instead
- Fixed 200-customer pool, no new customers appear after Jan 2024 — reframed new-vs-repeat as churn/inactivity instead
- Dashboard KPI badges compare fixed months (Aug vs. Jul 2025) — fine for a static snapshot, would need to be dynamic on live data
- Dataset is synthetic — the methodology transfers to real data, the numbers themselves are illustrative

## Files

- `sql/retail_revenue_analysis.sql` — full pipeline: schema, cleaning checks, views, core + advanced analysis, customer summary. Runs top to bottom.
