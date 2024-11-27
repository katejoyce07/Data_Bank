#A. Customer Nodes Exploration
#How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id) as unique_nodes
FROM customer_nodes;


#What is the number of nodes per region?
SELECT region_name,
COUNT(DISTINCT node_id) as num_nodes
FROM customer_nodes as C
INNER JOIN regions as R on C.region_id = R.REGION_ID
GROUP BY region_name;


#How many customers are allocated to each region?
SELECT region_name,
COUNT(DISTINCT customer_id) as num_cust
FROM customer_nodes as C
INNER JOIN regions as R on C.region_id = R.REGION_ID
GROUP BY region_name;

#How many days on average are customers reallocated to a different node?

WITH DAYS_IN_NODE AS (
    SELECT 
        customer_id,
        node_id,
        SUM(DATEDIFF(end_date, start_date)) AS days_in_node
    FROM customer_nodes
    WHERE end_date <> '9999-12-31'
    GROUP BY customer_id, node_id
)
SELECT ROUND(AVG(days_in_node), 0) AS average_days_in_node
FROM DAYS_IN_NODE;


#What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
WITH DAYS_IN_NODE AS (
    SELECT R.region_name,
        C.customer_id,
        C.node_id,
        SUM(DATEDIFF(end_date, start_date)) AS days_in_node
    FROM customer_nodes AS C
    INNER JOIN regions AS R ON R.region_id = C.region_id
    WHERE end_date <> '9999-12-31'
    GROUP BY R.region_name, C.customer_id, C.node_id
),
ORDERED AS (
    SELECT region_name,
        days_in_node,
        ROW_NUMBER() OVER (PARTITION BY region_name ORDER BY days_in_node) AS rn
    FROM DAYS_IN_NODE
),
MAX_ROWS AS (
    SELECT region_name,
        MAX(rn) AS max_rn
    FROM ORDERED
    GROUP BY region_name
)
SELECT O.region_name,
    CASE 
        WHEN rn = ROUND(M.max_rn / 2, 0) THEN 'Median'
        WHEN rn = ROUND(M.max_rn * 0.8, 0) THEN '80th Percentile'
        WHEN rn = ROUND(M.max_rn * 0.95, 0) THEN '95th Percentile'
    END AS metric,
    days_in_node AS value
FROM ORDERED AS O
INNER JOIN MAX_ROWS AS M ON M.region_name = O.region_name
WHERE rn IN (
    ROUND(M.max_rn / 2, 0),
    ROUND(M.max_rn * 0.8, 0),
    ROUND(M.max_rn * 0.95, 0)
);
