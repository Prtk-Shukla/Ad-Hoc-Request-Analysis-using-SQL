
-- 1. Provide the list of markets in which customer  "Atliq  Exclusive"  operates its business in the  APAC  region.

select 
	distinct market 
from dim_customer
where region = 'APAC' and customer = 'Atliq Exclusive';

 -- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, 
 -- unique_products_2020, unique_products_2021 & percentage_chg 

with unique_products_2020 As(
SELECT 
	COUNT(distinct(p.product_code)) as Total_unique_products_2020
FROM dim_product p
JOIN fact_gross_price gp
ON p.product_code = gp.product_code
where gp.fiscal_year = 2020
),
unique_products_2021 As(
SELECT 
	COUNT(distinct p.product_code) as Total_unique_products_2021 
FROM dim_product p
JOIN fact_gross_price gp
ON p.product_code = gp.product_code
where gp.fiscal_year = 2021
)
select *, 
ROUND((u21.Total_unique_products_2021- u20.Total_unique_products_2020)/u20.Total_unique_products_2020 * 100,2) as pct_change

from unique_products_2021 u21,
unique_products_2020 u20;

-- 3.  Provide a report with all the unique product counts for each  segment  and sort them in descending order of product counts. The final output contains 
-- two fields, segment & product_count 

select 
	segment,
    Count(distinct(product_code)) as product_count
from dim_product
group by segment
order by product_count desc;

-- 4.  Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields, 
-- segment, product_count_2020, product_count_2021 & difference 

WITH unique_product_2020 AS (
    SELECT 
        p.segment,
        COUNT(DISTINCT p.product_code) AS product_count_2020
    FROM dim_product p
    JOIN fact_gross_price gp ON p.product_code = gp.product_code
    WHERE gp.fiscal_year = 2020
    GROUP BY p.segment
),
unique_product_2021 AS (
    SELECT 
        p.segment,
        COUNT(DISTINCT p.product_code) AS product_count_2021
    FROM dim_product p
    JOIN fact_gross_price gp ON p.product_code = gp.product_code
    WHERE gp.fiscal_year = 2021
    GROUP BY p.segment
)
SELECT 
    u21.segment,
    u20.product_count_2020,
    u21.product_count_2021,
    (u21.product_count_2021 - u20.product_count_2020)  AS difference
FROM 
    unique_product_2020 u20
JOIN 
    unique_product_2021 u21 ON u20.segment = u21.segment
ORDER BY 
    difference DESC;
    
 -- 5.  Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields, 
-- product_code, product & manufacturing_cost  

-- Get Products with Highest manufacturing costs
(SELECT 
    sub.product_code, sub.product, sub.manufacturing_cost
FROM (
    SELECT 
        p.product_code, p.product, mc.manufacturing_cost,
        ROW_NUMBER() OVER (PARTITION BY p.product ORDER BY mc.manufacturing_cost DESC) as rnk
    FROM dim_product p 
    JOIN fact_manufacturing_cost mc
    ON p.product_code = mc.product_code
) sub
WHERE sub.rnk = 1
ORDER BY sub.manufacturing_cost DESC
LIMIT 5)

UNION ALL

-- Get Products with lowest manufacturing costs
(SELECT 
    sub.product_code, sub.product, sub.manufacturing_cost
FROM (
    SELECT 
        p.product_code, p.product, mc.manufacturing_cost,
        ROW_NUMBER() OVER (PARTITION BY p.product ORDER BY mc.manufacturing_cost ASC) as rnk
    FROM dim_product p 
    JOIN fact_manufacturing_cost mc
    ON p.product_code = mc.product_code
) sub
WHERE sub.rnk = 1
ORDER BY sub.manufacturing_cost ASC
LIMIT 5); 

-- 6.  Generate a report which contains the top 5 customers who received an average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the 
-- Indian  market. The final output contains these fields, customer_code, customer & average_discount_percentage 

with cte_avg_disc as 
(SELECT 
	c.customer_code,c.customer,
    ROUND(AVG(pid.pre_invoice_discount_pct),2) as avg_pre_inv_disc_pct,
    dense_rank() over(order by AVG(pid.pre_invoice_discount_pct) desc) as drank
FROM dim_customer c 
JOIN fact_pre_invoice_deductions pid
ON c.customer_code = pid.customer_code
where pid.fiscal_year = 2021 and c.market = "India"
group by c.customer_code,c.customer
)
select 
	customer_code,customer,avg_pre_inv_disc_pct
from cte_avg_disc
where drank <=5;



-- 7.Get the complete report of the Gross sales amount for the customer  “Atliq Exclusive”  for each month  .  This analysis helps to  get an idea of low and 
-- high-performing months and take strategic decisions. The final report contains these columns: Month, Year & Gross sales Amount 

SELECT 
	month(sm.date) as month,sm.fiscal_year as year, 
    ROUND(sum(sm.sold_quantity * gp.gross_price)/1000000,2) as gross_sales_amount_mln
FROM fact_sales_monthly sm
JOIN dim_customer c
On c.customer_code = sm.customer_code
JOIN fact_gross_price gp
ON sm.product_code = gp.product_code and
sm.fiscal_year = gp.fiscal_year
where c.customer = 'Atliq Exclusive'
group by month,year
order by year;

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity, 
-- Quarter & total_sold_quantity 

SELECT 
    CASE 
        WHEN MONTH(date) IN (9, 10, 11) THEN 'Q1'
        WHEN MONTH(date) IN (12, 1, 2) THEN 'Q2'
        WHEN MONTH(date) IN (3, 4, 5) THEN 'Q3'
        WHEN MONTH(date) IN (6, 7, 8) THEN 'Q4'
    END AS Quarter,
   SUM(sold_quantity) AS total_sold_quantity
FROM 
    fact_sales_monthly 
WHERE 
    fiscal_year = 2020
GROUP BY 
	Quarter
ORDER BY 
    total_sold_quantity DESC
    LIMIT 1;
    
    
-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?  The final output  contains these fields, 
-- channel, gross_sales_mln & percentage

with channel_sales as (
SELECT 
	c.channel, 
    sum(sm.sold_quantity * gp.gross_price)/1000000 as gross_sales_mln
FROM fact_sales_monthly sm
JOIN dim_customer c 
ON c.customer_code = sm.customer_code
JOIN fact_gross_price gp
ON gp.product_code = sm.product_code and gp.fiscal_year = sm.fiscal_year
where sm.fiscal_year = 2021
group by c.channel
),
total_sales as (
select 
	sum(gross_sales_mln) as total_gross_sales
from channel_sales
) 
select 
	channel,
    ROUND(gross_sales_mln,2) as gross_sales_mln,
    ROUND((gross_sales_mln/total_gross_sales)*100,2) as percentage
    from channel_sales, total_sales
    order by gross_sales_mln desc;




-- 10.Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these 
-- fields, division, product_code, product , total_sold_quantity , rank_order

with cte as (
SELECT 
	p.division,p.product_code,p.product,
   SUM(sm.sold_quantity) as total_sold_quantity,
   RANK() over(partition by p.division order by SUM(sm.sold_quantity) desc) as rank_order
FROM dim_product p
JOIN fact_sales_monthly sm
ON sm.product_code = p.product_code
where sm.fiscal_year = 2021
group by p.division,p.product_code,p.product
)
select 
	division,product_code,product,total_sold_quantity,rank_order
from cte
where rank_order <=3
order by total_sold_quantity desc;