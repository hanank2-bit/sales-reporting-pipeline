-- The twelve reports this pipeline runs, in order of difficulty.
-- Each block starts with a name line and is picked up by run_reports.py.


-- name: revenue_by_region
-- Level 1: your first GROUP BY. Always qualify every non-aggregated column.
SELECT
    region,
    COUNT(*)                       AS orders,
    SUM(quantity)                  AS units,
    ROUND(SUM(line_total), 2)      AS revenue
FROM sales
GROUP BY region
ORDER BY revenue DESC;



-- name: revenue_by_month
-- Level 1: date handling. strftime pulls the month out of the stored date.
SELECT
    strftime('%Y-%m', order_date)  AS month,
    COUNT(*)                       AS orders,
    ROUND(SUM(line_total), 2)      AS revenue,
    ROUND(AVG(line_total), 2)      AS avg_order_value
FROM sales
GROUP BY month
ORDER BY month;


-- name: top_customers
-- Level 1: rank and cut. LIMIT is how you turn a query into a "top N" report.
SELECT
    customer,
    COUNT(*)                       AS orders,
    ROUND(SUM(line_total), 2)      AS lifetime_value,
    MIN(order_date)                AS first_order,
    MAX(order_date)                AS last_order
FROM sales
GROUP BY customer
ORDER BY lifetime_value DESC
LIMIT 10;


-- name: category_performance
-- Level 2: HAVING filters after grouping, WHERE filters before it.
SELECT
    category,
    COUNT(*)                       AS orders,
    ROUND(SUM(line_total), 2)      AS revenue,
    ROUND(AVG(discount_pct), 1)    AS avg_discount_pct
FROM sales
GROUP BY category
HAVING SUM(line_total) > 10000
ORDER BY revenue DESC;


-- name: channel_mix
-- Level 2: percentage of total using a subquery.
SELECT
    channel,
    COUNT(*)                                                           AS orders,
    ROUND(SUM(line_total), 2)                                          AS revenue,
    ROUND(100.0 * SUM(line_total) / (SELECT SUM(line_total) FROM sales), 1) AS pct_of_total
FROM sales
GROUP BY channel
ORDER BY revenue DESC;


-- name: customer_segments
-- Level 2: CASE WHEN to bucket rows into named groups.
SELECT
    CASE
        WHEN lifetime_value >= 20000 THEN 'A - Key account'
        WHEN lifetime_value >= 8000  THEN 'B - Growing'
        WHEN lifetime_value >= 2000  THEN 'C - Regular'
        ELSE 'D - Occasional'
    END                            AS segment,
    COUNT(*)                       AS customer_count,
    ROUND(SUM(lifetime_value), 2)  AS segment_revenue
FROM (
    SELECT customer, SUM(line_total) AS lifetime_value
    FROM sales
    GROUP BY customer
)
GROUP BY segment
ORDER BY segment;


-- name: running_revenue
-- Level 3: the first window function. SUM(...) OVER (ORDER BY ...) is a running total.
SELECT
    month,
    revenue,
    ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS running_total
FROM (
    SELECT strftime('%Y-%m', order_date) AS month,
           SUM(line_total)               AS revenue
    FROM sales
    GROUP BY month
)
ORDER BY month;


-- name: month_on_month_growth
-- Level 3: LAG() reaches back one row. This is how you report growth.
SELECT
    month,
    ROUND(revenue, 2)                                AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY month), 2)     AS previous_month,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
          / LAG(revenue) OVER (ORDER BY month), 1)   AS growth_pct
FROM (
    SELECT strftime('%Y-%m', order_date) AS month,
           SUM(line_total)               AS revenue
    FROM sales
    GROUP BY month
)
ORDER BY month;


-- name: top_products_per_category
-- Level 3: ROW_NUMBER() partitioned by category gives a rank within each group.
SELECT
    category,
    product_name,
    ROUND(revenue, 2) AS revenue,
    rank_in_category
FROM (
    SELECT
        category,
        product_name,
        SUM(line_total) AS revenue,
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY SUM(line_total) DESC
        ) AS rank_in_category
    FROM sales
    GROUP BY category, product_name
)
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;


-- name: customer_order_gaps
-- Level 4: self-join style analysis via LAG on each customer's own timeline.
SELECT
    customer,
    order_date,
    previous_order,
    CAST(julianday(order_date) - julianday(previous_order) AS INTEGER) AS days_between
FROM (
    SELECT
        customer,
        order_date,
        LAG(order_date) OVER (PARTITION BY customer ORDER BY order_date) AS previous_order
    FROM sales
)
WHERE previous_order IS NOT NULL
ORDER BY days_between DESC
LIMIT 20;


-- name: high_discount_impact
-- Level 4: CTE (WITH clause) - name an intermediate result and reuse it.
WITH discounted AS (
    SELECT
        CASE WHEN discount_pct = 0 THEN 'No discount' ELSE 'Discounted' END AS discount_band,
        quantity,
        line_total,
        unit_price * quantity AS gross_value
    FROM sales
)
SELECT
    discount_band,
    COUNT(*)                                        AS orders,
    ROUND(SUM(gross_value), 2)                      AS gross_value,
    ROUND(SUM(line_total), 2)                       AS net_value,
    ROUND(SUM(gross_value - line_total), 2)         AS discount_given,
    ROUND(AVG(quantity), 1)                         AS avg_units
FROM discounted
GROUP BY discount_band;


-- name: retention_by_cohort
-- Level 4: the report a client actually asks for. Groups customers by the
-- month of their first order, then counts how many were still buying later.
WITH first_order AS (
    SELECT customer, MIN(order_date) AS joined
    FROM sales
    GROUP BY customer
),
activity AS (
    SELECT
        f.customer,
        strftime('%Y-%m', f.joined)      AS cohort,
        strftime('%Y-%m', s.order_date)  AS activity_month
    FROM first_order f
    JOIN sales s ON s.customer = f.customer
)
SELECT
    cohort,
    COUNT(DISTINCT customer)   AS customers,
    COUNT(DISTINCT activity_month) AS active_months,
    ROUND(1.0 * COUNT(*) / COUNT(DISTINCT customer), 1) AS orders_per_customer
FROM activity
GROUP BY cohort
ORDER BY cohort;

-- name: revenue_by_channel_and_region
-- Question: which sales channel works best in each region?
SELECT
    region,
    channel,
    count(*)                 AS orders,
    SUM(quantity)            AS units,
    ROUND(SUM(line_total), 2) AS revenue
FROM sales
GROUP BY region, channel
ORDER BY region, revenue DESC;

-- name: region_check
-- Found 15 orders with no region (1.2% of total). Small enough to footnote,
-- but it explains why revenue_by_channel_and_region has 36 rows, not 32.
SELECT region, COUNT(*) AS orders
FROM sales
GROUP BY region
ORDER BY region;


 -- name: s5_totals_by_region
SELECT
    region,
    COUNT(*) AS orders
FROM sales
GROUP BY region
ORDER BY orders DESC;

-- name: s6_revenue_by_region
SELECT
    region,
    COUNT(*)                  AS orders,
    ROUND(SUM(line_total), 2) AS revenue
FROM sales
GROUP BY region
ORDER BY revenue DESC;
  
-- name: s7_average_order_by_region
SELECT
    region,
    COUNT(*)                  AS orders,
    ROUND(SUM(line_total), 2) AS revenue,
    ROUND(AVG(line_total), 2) AS avg_order_value
FROM sales
GROUP BY region
ORDER BY avg_order_value DESC;

-- name: s8_discount_by_region
SELECT
    region,
    ROUND(AVG(discount_pct), 2)  AS avg_discount,
    COUNT(*)                     AS orders
FROM sales
GROUP BY region
ORDER BY avg_discount DESC;

-- name: s9_revenue_by_discount_band
SELECT
    CASE
        WHEN discount_pct = 0            THEN '0 - none'
        WHEN discount_pct <= 5           THEN '5%' 
        WHEN discount_pct <= 10          THEN '10%'
        ELSE '15 - 20%'
    END                              AS discount_band,
    COUNT(*)                         AS orders,
    ROUND(AVG(line_total), 2)        AS avg_order_value
FROM sales
GROUP BY discount_band
ORDER BY avg_order_value DESC;

-- name: s10_leeds_vs_manchester
SELECT
    region,
    ROUND(AVG(quantity), 1)    AS avg_quantity,
    ROUND(AVG(unit_price), 2)  AS avg_unit_price
FROM sales
WHERE region IN ('Leeds', 'Manchester')
GROUP BY region;




