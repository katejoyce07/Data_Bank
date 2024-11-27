#What is the unique count and total amount for each transaction type?
SELECT txn_type,
SUM(txn_amount) as total_amount,
COUNT(*) as transcation_count
FROM customer_transactions
GROUP BY txn_type;

#What is the average total historical deposit counts and amounts for all customers?
WITH CTE AS (
SELECT customer_id,
AVG(txn_amount) as avg_deposit,
COUNT(*) as tran_count
FROM customer_transactions
WHERE txn_type = 'deposit'
GROUP BY customer_id
)
SELECT ROUND(AVG(avg_deposit),1) as avg_dep_amount,
ROUND(AVG(tran_count),0) as avg_tran
FROM CTE;

#For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
WITH CTE AS (
    SELECT DATE_FORMAT(txn_date, '%Y-%m-01') AS month, 
        customer_id,
        SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposits,
        SUM(CASE WHEN txn_type <> 'deposit' THEN 1 ELSE 0 END) AS purchase_or_withdrawal
    FROM customer_transactions
    GROUP BY DATE_FORMAT(txn_date, '%Y-%m-01'), customer_id
    HAVING 
        SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) > 1
        AND SUM(CASE WHEN txn_type <> 'deposit' THEN 1 ELSE 0 END) = 1
)
SELECT month,
    COUNT(customer_id) AS customers
FROM CTE
GROUP BY month;

#What is the closing balance for each customer at the end of the month?

WITH CTE AS (
    SELECT DATE_FORMAT(txn_date, '%Y-%m-01') AS txn_month, -- Start of the month
        txn_date,
        customer_id,
        SUM(
            (CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) - 
            (CASE WHEN txn_type <> 'deposit' THEN txn_amount ELSE 0 END)
        ) AS balance
    FROM customer_transactions
    GROUP BY DATE_FORMAT(txn_date, '%Y-%m-01'), txn_date, customer_id
),
BALANCES AS (
    SELECT *,
        SUM(balance) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_sum,
        ROW_NUMBER() OVER (PARTITION BY customer_id, txn_month ORDER BY txn_date DESC) AS rn
    FROM CTE
)
SELECT customer_id,
    LAST_DAY(txn_month) AS end_of_month, -- Equivalent to calculating the last day of the month
    running_sum AS closing_balance
FROM BALANCES 
WHERE rn = 1;

#What is the percentage of customers who increase their closing balance by more than 5%?
WITH CTE AS (
    SELECT DATE_FORMAT(txn_date, '%Y-%m-01') AS txn_month, -- Start of the month
        txn_date,
        customer_id,
        SUM(
            (CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) - 
            (CASE WHEN txn_type <> 'deposit' THEN txn_amount ELSE 0 END)
        ) AS balance
    FROM customer_transactions
    GROUP BY DATE_FORMAT(txn_date, '%Y-%m-01'), txn_date, customer_id
),
BALANCES AS (
    SELECT *,
        SUM(balance) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_sum,
        ROW_NUMBER() OVER (PARTITION BY customer_id, txn_month ORDER BY txn_date DESC) AS rn
    FROM CTE
),
CLOSING_BALANCES AS (
    SELECT customer_id,
        LAST_DAY(txn_month) AS end_of_month, 
        LAST_DAY(DATE_SUB(txn_month, INTERVAL 1 MONTH)) AS previous_end_of_month, 
        running_sum AS closing_balance
    FROM BALANCES 
    WHERE rn = 1
    ORDER BY end_of_month
),
PERCENT_INCREASE AS (
    SELECT CB1.customer_id,
        CB1.end_of_month,
        CB1.closing_balance,
        CB2.closing_balance AS next_month_closing_balance,
        (CB2.closing_balance / CB1.closing_balance) - 1 AS percentage_increase,
        CASE 
            WHEN (CB2.closing_balance > CB1.closing_balance AND 
                  (CB2.closing_balance / CB1.closing_balance) - 1 > 0.05) 
            THEN 1 ELSE 0 
        END AS percentage_increase_flag
    FROM CLOSING_BALANCES AS CB1
    INNER JOIN CLOSING_BALANCES AS CB2 
        ON CB1.end_of_month = CB2.previous_end_of_month 
        AND CB1.customer_id = CB2.customer_id
    WHERE CB1.closing_balance <> 0
)
SELECT SUM(percentage_increase_flag) / COUNT(percentage_increase_flag)*100 AS percentage_of_customers_increasing_balance
FROM PERCENT_INCREASE;

