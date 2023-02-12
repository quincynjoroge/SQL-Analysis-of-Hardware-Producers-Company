show databases;
-- Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
SELECT DISTINCT market
FROM dim_customer
WHERE customer = "Atliq Exclusive" AND region = "APAC";

-- What is the percentage of unique product increase in 2021 vs. 2020? 
WITH product_counts AS (
SELECT fiscal_year, COUNT(DISTINCT product_code) AS unique_product_count
FROM fact_sales_monthly
WHERE fiscal_year IN (2020, 2021)
GROUP BY fiscal_year)
SELECT 
  unique_products_2020, 
  unique_products_2021, 
  ((unique_products_2021 - unique_products_2020) / unique_products_2020) * 100 AS percentage_chg
FROM 
  (
    SELECT 
      (SELECT unique_product_count FROM product_counts WHERE fiscal_year = 2020) AS unique_products_2020,
      (SELECT unique_product_count FROM product_counts WHERE fiscal_year = 2021) AS unique_products_2021
  ) AS subquery;
  
-- Provide a report with all the unique product counts for each segment and sort them in descending order of product counts
SELECT segment, COUNT(product_code) product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- Which segment had the most increase in unique products in 2021 vs 2020?
SELECT d.segment, 
  COUNT(CASE WHEN f.fiscal_year = 2020 THEN f.product_code END) AS product_count_2020,
  COUNT(CASE WHEN f.fiscal_year = 2021 THEN f.product_code END) AS product_count_2021,
  COUNT(CASE WHEN f.fiscal_year = 2021 THEN f.product_code END) - 
  COUNT(CASE WHEN f.fiscal_year = 2020 THEN f.product_code END) AS difference
FROM dim_product d
JOIN fact_sales_monthly f USING(product_code)
GROUP BY d.segment
ORDER BY difference DESC;

-- Get the products that have the highest and lowest manufacturing costs
SELECT product_code, product, manufacturing_cost 
FROM fact_manufacturing_cost
JOIN dim_product USING(product_code)
ORDER BY manufacturing_cost DESC;

-- top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market
SELECT c.customer_code, c.customer, AVG(i.pre_invoice_discount_pct)*100 AS average_discount_percentage
FROM dim_customer c
JOIN fact_pre_invoice_deductions i USING(customer_code)
WHERE i.fiscal_year = "2021" AND c.market = "India"
GROUP BY c.customer_code, c.customer 
ORDER BY average_discount_percentage DESC
LIMIT 5; 

-- Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month.
WITH customer AS
(
SELECT s.product_code,s.customer_code,s.date,s.sold_quantity
FROM fact_sales_monthly s
JOIN dim_customer c USING(customer_code)
WHERE c.customer = "Atliq Exclusive")
SELECT MONTH(c.date) AS Month, YEAR(c.date) AS year, ROUND(SUM(g.gross_price*c.sold_quantity),2) AS gross_sales_amount
FROM customer c
JOIN fact_gross_price g USING(product_code)
GROUP BY Month(c.date),YEAR(c.date)
ORDER BY gross_sales_amount DESC;

-- In which quarter of 2020, got the maximum total_sold_quantity?
SELECT 
    CASE 
    WHEN MONTH(date) IN(9,10,11) THEN 1
    WHEN MONTH(date) IN(12,1,2) THEN 2
    WHEN MONTH(date) IN(3,4,5) THEN 3
    WHEN MONTH(date) IN(6,7,8) THEN 4
  END AS quarter,
       SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year="2020"
GROUP BY quarter
ORDER BY total_sold_quantity DESC;

-- Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
WITH gross_sales AS
(
SELECT customer_code,gross_price*sold_quantity AS gross_sales_mln
FROM fact_gross_price g
JOIN fact_sales_monthly s USING(product_code)
WHERE s.fiscal_year="2021" AND g.fiscal_year="2021"
)
SELECT channel, 
	   ROUND(SUM(gross_sales_mln),2) AS gross_sales_mln, 
	   ROUND(100*(SUM(gross_sales_mln)/
                                    (Select SUM(gross_sales_mln) FROM gross_sales)),2)AS percentage
FROM dim_customer
JOIN gross_sales USING(customer_code)
GROUP BY channel
ORDER BY gross_sales_mln DESC;

-- Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
WITH cte AS (
  SELECT 
    d.division, 
    d.product_code, 
    d.product, 
    SUM(f.sold_quantity) AS total_sold_quantity,
    ROW_NUMBER() OVER (PARTITION BY d.division ORDER BY SUM(f.sold_quantity) DESC) AS rank_order
  FROM dim_product d
  JOIN fact_sales_monthly f ON d.product_code = f.product_code
  WHERE f.fiscal_year = "2021"
  GROUP BY d.division, d.product_code, d.product
)
SELECT division, product_code, product, total_sold_quantity, rank_order
FROM cte
WHERE rank_order <= 3
ORDER BY division, rank_order;

