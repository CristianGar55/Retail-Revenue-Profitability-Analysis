-- Retail Revenue & Profitability Analysis
-- Run top to bottom: schema, cleaning checks, views, analysis, customer summary

-- =========================================================
-- SCHEMA
-- =========================================================

CREATE DATABASE IF NOT EXISTS retail_analysis;
USE retail_analysis;

CREATE TABLE customers (
    CustomerID   VARCHAR(10) PRIMARY KEY,
    FirstName    VARCHAR(50),
    LastName     VARCHAR(50),
    Gender       VARCHAR(10),
    BirthDate    DATE,
    City         VARCHAR(100),
    JoinDate     DATE
);

CREATE TABLE products (
    ProductID    VARCHAR(10) PRIMARY KEY,
    ProductName  VARCHAR(150),
    Category     VARCHAR(100),
    SubCategory  VARCHAR(100),
    UnitPrice    DECIMAL(10,2),
    CostPrice    DECIMAL(10,2)
);

CREATE TABLE stores (
    StoreID      VARCHAR(10) PRIMARY KEY,
    StoreName    VARCHAR(150),
    City         VARCHAR(100),
    Region       VARCHAR(50)
);

-- one row per transaction, confirmed in the grain check below
CREATE TABLE transactions (
    TransactionID    VARCHAR(10) PRIMARY KEY,
    TransactionDate  DATE,
    CustomerID       VARCHAR(10),
    ProductID        VARCHAR(10),
    StoreID          VARCHAR(10),
    Quantity         INT,
    Discount         DECIMAL(5,2),
    PaymentMethod    VARCHAR(50),
    FOREIGN KEY (CustomerID) REFERENCES customers(CustomerID),
    FOREIGN KEY (ProductID)  REFERENCES products(ProductID),
    FOREIGN KEY (StoreID)    REFERENCES stores(StoreID)
);

-- load dimension tables before transactions (FK constraints)
-- LOAD DATA LOCAL INFILE 'customers.csv'    INTO TABLE customers    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- LOAD DATA LOCAL INFILE 'products.csv'     INTO TABLE products     FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- LOAD DATA LOCAL INFILE 'stores.csv'       INTO TABLE stores       FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- LOAD DATA LOCAL INFILE 'transactions.csv' INTO TABLE transactions FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;


-- =========================================================
-- DATA CLEANING CHECKS
-- =========================================================

-- nulls, should all be 0
SELECT
  SUM(CustomerID IS NULL) AS null_customerid,
  SUM(FirstName IS NULL)  AS null_firstname,
  SUM(LastName IS NULL)   AS null_lastname,
  SUM(Gender IS NULL)     AS null_gender,
  SUM(BirthDate IS NULL)  AS null_birthdate,
  SUM(City IS NULL)       AS null_city,
  SUM(JoinDate IS NULL)   AS null_joindate
FROM customers;

SELECT
  SUM(ProductID IS NULL)   AS null_productid,
  SUM(ProductName IS NULL) AS null_productname,
  SUM(Category IS NULL)    AS null_category,
  SUM(SubCategory IS NULL) AS null_subcategory,
  SUM(UnitPrice IS NULL)   AS null_unitprice,
  SUM(CostPrice IS NULL)   AS null_costprice
FROM products;

SELECT
  SUM(StoreID IS NULL)   AS null_storeid,
  SUM(StoreName IS NULL) AS null_storename,
  SUM(City IS NULL)      AS null_city,
  SUM(Region IS NULL)    AS null_region
FROM stores;

SELECT
  SUM(TransactionID IS NULL)   AS null_txnid,
  SUM(TransactionDate IS NULL) AS null_date,
  SUM(CustomerID IS NULL)      AS null_customerid,
  SUM(ProductID IS NULL)       AS null_productid,
  SUM(StoreID IS NULL)         AS null_storeid,
  SUM(Quantity IS NULL)        AS null_quantity,
  SUM(Discount IS NULL)        AS null_discount,
  SUM(PaymentMethod IS NULL)   AS null_paymentmethod
FROM transactions;

-- range/logic checks, should all return 0 rows
SELECT * FROM transactions WHERE Quantity <= 0;
SELECT * FROM transactions WHERE Discount < 0 OR Discount > 1;
SELECT * FROM products WHERE UnitPrice <= 0 OR CostPrice <= 0;
SELECT * FROM products WHERE CostPrice > UnitPrice;  -- sold at a loss, not necessarily wrong
SELECT * FROM transactions WHERE TransactionDate < '2023-01-01' OR TransactionDate > CURDATE();

-- 75 customers have a JoinDate after their first transaction (data gen artifact)
-- using first-purchase-date instead of JoinDate everywhere below
SELECT c.CustomerID, c.JoinDate, MIN(t.TransactionDate) AS FirstPurchase
FROM customers c
JOIN transactions t ON c.CustomerID = t.CustomerID
GROUP BY c.CustomerID, c.JoinDate
HAVING MIN(t.TransactionDate) < c.JoinDate;

-- eyeball for typos/casing
SELECT DISTINCT Gender FROM customers;
SELECT DISTINCT Category FROM products;
SELECT DISTINCT SubCategory FROM products;
SELECT DISTINCT Region FROM stores;
SELECT DISTINCT PaymentMethod FROM transactions;

-- dupes, should return 0 rows
SELECT CustomerID, ProductID, StoreID, TransactionDate, Quantity, COUNT(*) AS occurrences
FROM transactions
GROUP BY CustomerID, ProductID, StoreID, TransactionDate, Quantity
HAVING COUNT(*) > 1;

-- grain check, should return 0 rows (confirms 1 row = 1 transaction, matters for AOV)
SELECT TransactionID, COUNT(*)
FROM transactions
GROUP BY TransactionID
HAVING COUNT(*) > 1;


-- =========================================================
-- VIEWS
-- =========================================================

CREATE VIEW vw_transactions_enriched AS
SELECT
  t.TransactionID,
  t.TransactionDate,
  DATE_FORMAT(t.TransactionDate, '%Y-%m') AS SaleMonth,
  t.CustomerID,
  t.ProductID,
  t.StoreID,
  t.Quantity,
  t.Discount,
  t.PaymentMethod,
  p.ProductName,
  p.Category,
  p.SubCategory,
  s.Region,
  ROUND(t.Quantity * p.UnitPrice * (1 - t.Discount), 2) AS Revenue,
  ROUND(t.Quantity * p.CostPrice, 2) AS Cost,
  ROUND((t.Quantity * p.UnitPrice * (1 - t.Discount)) - (t.Quantity * p.CostPrice), 2) AS Profit
FROM transactions t
JOIN products p ON t.ProductID = p.ProductID
JOIN stores s ON t.StoreID = s.StoreID;

CREATE VIEW vw_customer_first_purchase AS
SELECT CustomerID, MIN(TransactionDate) AS FirstPurchaseDate
FROM transactions
GROUP BY CustomerID;

CREATE VIEW vw_transactions_final AS
SELECT
  e.*,
  CASE WHEN e.TransactionDate = f.FirstPurchaseDate THEN 'New' ELSE 'Repeat' END AS CustomerType
FROM vw_transactions_enriched e
JOIN vw_customer_first_purchase f ON e.CustomerID = f.CustomerID;


-- =========================================================
-- CORE METRICS
-- =========================================================

-- monthly revenue (2023-09 and 2025-09 are partial months, exclude from trend comparisons)
SELECT SaleMonth, ROUND(SUM(Revenue), 2) AS MonthlyRevenue, COUNT(*) AS TransactionCount
FROM vw_transactions_enriched
GROUP BY SaleMonth
ORDER BY SaleMonth;

-- top 10 products by revenue
SELECT ProductID, ProductName, Category,
       SUM(Quantity) AS UnitsSold,
       ROUND(SUM(Revenue), 2) AS TotalRevenue
FROM vw_transactions_enriched
GROUP BY ProductID, ProductName, Category
ORDER BY TotalRevenue DESC
LIMIT 10;

-- new vs repeat by month
-- fixed 200-customer pool, no new customers after Jan 2024 - see churn query instead
SELECT
  e.SaleMonth,
  CASE WHEN e.TransactionDate = f.FirstPurchaseDate THEN 'New' ELSE 'Repeat' END AS CustomerType,
  COUNT(DISTINCT e.CustomerID) AS Customers,
  ROUND(SUM(e.Revenue), 2) AS Revenue
FROM vw_transactions_enriched e
JOIN vw_customer_first_purchase f ON e.CustomerID = f.CustomerID
GROUP BY e.SaleMonth, CustomerType
ORDER BY e.SaleMonth, CustomerType;

-- AOV, overall and by month
SELECT ROUND(AVG(Revenue), 2) AS OverallAOV FROM vw_transactions_enriched;

SELECT SaleMonth, ROUND(AVG(Revenue), 2) AS MonthlyAOV
FROM vw_transactions_enriched
GROUP BY SaleMonth
ORDER BY SaleMonth;

-- category profit
SELECT Category,
       ROUND(SUM(Revenue), 2) AS TotalRevenue,
       ROUND(SUM(Profit), 2) AS TotalProfit,
       ROUND(SUM(Profit) / SUM(Revenue) * 100, 2) AS ProfitMarginPct
FROM vw_transactions_enriched
GROUP BY Category
ORDER BY TotalProfit DESC;

-- inactive customers (90+ days) and revenue at risk
SELECT
  CustomerID,
  MAX(TransactionDate) AS LastPurchase,
  DATEDIFF('2025-09-09', MAX(TransactionDate)) AS DaysSinceLastPurchase
FROM transactions
GROUP BY CustomerID
HAVING DaysSinceLastPurchase > 90
ORDER BY DaysSinceLastPurchase DESC;

SELECT ROUND(SUM(Revenue), 2) AS HistoricalRevenueFromInactiveCustomers
FROM vw_transactions_enriched
WHERE CustomerID IN (
  SELECT CustomerID FROM transactions
  GROUP BY CustomerID
  HAVING DATEDIFF('2025-09-09', MAX(TransactionDate)) > 90
);


-- =========================================================
-- ADVANCED ANALYSIS
-- =========================================================

-- revenue decomposition: volume effect vs price effect
-- VolumeEffect = revenue change from more/fewer transactions
-- PriceEffect  = revenue change from bigger/smaller average orders
-- (the two won't sum exactly to RevenueChange - normal for chain substitution)
WITH monthly AS (
  SELECT SaleMonth, COUNT(*) AS Txns, SUM(Revenue) AS Revenue, AVG(Revenue) AS AOV
  FROM vw_transactions_enriched
  GROUP BY SaleMonth
),
with_lag AS (
  SELECT *,
    LAG(Txns) OVER (ORDER BY SaleMonth)    AS PrevTxns,
    LAG(Revenue) OVER (ORDER BY SaleMonth) AS PrevRevenue,
    LAG(AOV) OVER (ORDER BY SaleMonth)     AS PrevAOV
  FROM monthly
)
SELECT
  SaleMonth,
  ROUND(Revenue, 2)      AS Revenue,
  ROUND(Revenue - PrevRevenue, 2)          AS RevenueChange,
  ROUND((Txns - PrevTxns) * PrevAOV, 2)    AS VolumeEffect,
  ROUND((AOV - PrevAOV) * Txns, 2)         AS PriceEffect
FROM with_lag
WHERE PrevRevenue IS NOT NULL
ORDER BY SaleMonth;

-- customer concentration: revenue share of top 10% / top 20% of customers
WITH customer_revenue AS (
  SELECT CustomerID, SUM(Revenue) AS TotalRevenue
  FROM vw_transactions_enriched
  GROUP BY CustomerID
),
ranked AS (
  SELECT CustomerID, TotalRevenue,
    ROW_NUMBER() OVER (ORDER BY TotalRevenue DESC) AS RevenueRank
  FROM customer_revenue
),
totals AS (
  SELECT SUM(TotalRevenue) AS GrandTotal, COUNT(*) AS CustomerCount FROM customer_revenue
)
SELECT
  ROUND(SUM(CASE WHEN r.RevenueRank <= t.CustomerCount * 0.1 THEN r.TotalRevenue ELSE 0 END) / t.GrandTotal * 100, 2) AS Top10PctCustomers_RevenueShare,
  ROUND(SUM(CASE WHEN r.RevenueRank <= t.CustomerCount * 0.2 THEN r.TotalRevenue ELSE 0 END) / t.GrandTotal * 100, 2) AS Top20PctCustomers_RevenueShare
FROM ranked r
CROSS JOIN totals t
GROUP BY t.GrandTotal;


-- =========================================================
-- CUSTOMER SUMMARY (feeds Tableau, one row per customer)
-- =========================================================

-- reference date fixed to 2025-09-09 (last day in the data), not CURDATE()
-- this is a static dataset, so CURDATE() would make DaysSinceLastPurchase drift over time
SELECT
  c.CustomerID,
  c.FirstName,
  c.LastName,
  c.Gender,
  c.City,
  f.FirstPurchaseDate,
  MAX(e.TransactionDate) AS LastPurchaseDate,
  DATEDIFF('2025-09-09', MAX(e.TransactionDate)) AS DaysSinceLastPurchase,
  COUNT(e.TransactionID) AS TotalTransactions,
  ROUND(SUM(e.Revenue), 2) AS TotalRevenue,
  ROUND(SUM(e.Profit), 2) AS TotalProfit
FROM customers c
JOIN vw_transactions_enriched e ON c.CustomerID = e.CustomerID
JOIN vw_customer_first_purchase f ON c.CustomerID = f.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName, c.Gender, c.City, f.FirstPurchaseDate;

-- sanity check, should return 200
SELECT COUNT(*) FROM (
  SELECT c.CustomerID
  FROM customers c
  JOIN vw_transactions_enriched e ON c.CustomerID = e.CustomerID
  JOIN vw_customer_first_purchase f ON c.CustomerID = f.CustomerID
  GROUP BY c.CustomerID
) AS t;
