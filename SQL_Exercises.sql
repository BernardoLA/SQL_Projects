-- language: SQL
-- Exercises based on Classes I did online in SQL

-- *-------------- SubQueries ------------------*

 -- 1) find the day-channel with the most web events.
 -- Use it as subquery to get the average events per channel 
SELECT channel,
	   AVG(count_events) AS avg_events
FROM (SELECT DATE_TRUNC('day', occurred_at) as day, 
	channel,
	COUNT(*) AS count_events	
	FROM web_events
	GROUP BY 1, 2
	) AS sub1 
-- WHERE channel IN ('facebook', 'twitter', 'direct', 'organic') -- narrow to specific channels
GROUP BY 1
ORDER BY 2 DESC -- get from top to bottom average values


-- 2) The client wants to know the average volume of sales per day and per paper type in the first month. 
SELECT AVG(standard_qty) AS avg_std_paper_sold,
	 AVG(gloss_qty) AS avg_gloss_paper_sold,
       AVG(poster_qty) AS avg_poster_paper_sold
FROM orders
WHERE DATE_TRUNC('month', occurred_at) = 
	(SELECT MIN(DATE_TRUNC('month', occurred_at)) -- filtering subquery
	 FROM orders)


-- 2.1) A follow-up question is what is the sales in the period per type of paper:
SELECT SUM(standard_amt_usd) AS std_paper_revenue,
	 SUM(gloss_amt_usd) AS gloss_paper_revenue,
       SUM(poster_amt_usd) AS poster_paper_revenue
FROM orders
WHERE DATE_TRUNC('month', occurred_at) = 
			(SELECT MIN(DATE_TRUNC('month', occurred_at)) -- filtering subquery
	 FROM orders)

-- 2.2) We can better format this data visualize it with the following code:
-- The client wants to know the average volume of sales per day and per paper type in the first month. 

SELECT 'Standard' AS paper_type, 
	   SUM(standard_amt_usd) AS revenue_per_paper_type
FROM orders
WHERE DATE_TRUNC('month', occurred_at) = 
		(SELECT MIN(DATE_TRUNC('month', occurred_at)) -- filtering subquery
	 FROM orders)
UNION
SELECT 'Gloss' AS Paper_Type, 
	   SUM(gloss_amt_usd) AS Revenue_per_paper_type
FROM orders
WHERE DATE_TRUNC('month', occurred_at) = 
		(SELECT MIN(DATE_TRUNC('month', occurred_at)) -- filtering subquery
	 FROM orders)
UNION
SELECT 'Poster' AS Paper_Type, 
	   SUM(poster_amt_usd) AS Revenue_per_paper_type
FROM orders
WHERE DATE_TRUNC('month', occurred_at) = 
		(SELECT MIN(DATE_TRUNC('month', occurred_at)) -- filtering subquery
	 FROM orders)
ORDER BY 2 DESC -- sort in descending from top to bottom figures 

                    
-- 2.3) A follow-up question is what is the total sales in the period:
SELECT std_paper_revenue + gloss_paper_revenue + poster_paper_revenue as Total_Spent
FROM
	(SELECT SUM(standard_amt_usd) AS std_paper_revenue,
	   		SUM(gloss_amt_usd) AS gloss_paper_revenue,
       		SUM(poster_amt_usd) AS poster_paper_revenue
	FROM orders
	WHERE DATE_TRUNC('month', occurred_at) = 
			(SELECT MIN(DATE_TRUNC('month', occurred_at)) -- filtering subquery
	 FROM orders)) as sub
-- get this data in the right format for visualize it 



-- 3) What about the sales agents? What are the sales representatives in each region with the largest amount of sales for this first month.
-- 3.1) We need 2 separate tables and then to merge then into 1.
--	  3.1.1) First we need a table with the sum of sales per agent and region. We calculate this in sub1
--	  3.1.2) Then Based on sub1 we can calculate the maximum sales per region. We calculate this in sub2
--	  3.1.3) We can finally merge the two tables where we see how much sales the best performing achieved in each region.		

SELECT sub3.sales_agent, sub3.region, sub3.total_sales
FROM (SELECT region,
	   	 MAX(total_sales) AS total_sales
	FROM (SELECT s.name AS sales_agent,
	  		r.name AS region,
       		SUM(o.total_amt_usd) AS total_sales
	  		FROM accounts a
	  		INNER JOIN sales_reps s ON a.sales_rep_id = s.id
	  		INNER JOIN region r ON  s.region_id = r.id
	  		INNER JOIN orders o ON o.account_id = a.id
	  		GROUP BY 1,2
      		ORDER BY 2,3 DESC) AS sub1
	GROUP BY 1) AS sub2
INNER JOIN (SELECT s.name AS sales_agent,
	   		 r.name AS region,
       		 SUM(o.total_amt_usd) AS total_sales
	  		 FROM accounts a
	  		 INNER JOIN sales_reps s ON a.sales_rep_id = s.id
	  		 INNER JOIN region r ON  s.region_id = r.id
	 		 INNER JOIN orders o ON o.account_id = a.id
	 		 GROUP BY 1,2
      		 ORDER BY 2,3 DESC) AS sub3
ON sub3.total_sales = sub2.total_sales AND sub3.region =  sub2.region
ORDER BY 3 DESC

-- 4) For the region with the largest sum of sales, how many orders were placed.
-- 4.1) We need two separate tables
-- 4.1.1) A table with the region with the top sales which we use as a condition to get the right orders from the 2nd table (4.1.2).
-- 4.1.2) A table with all orders be filtered by the first one.
-- 4.1.3) We can then Count all orders for the regions with most sales in terms of revenue.

SELECT r.name,
	   COUNT(*) AS total_orders
FROM sales_reps s 
INNER JOIN accounts a ON a.sales_rep_id = s.id
INNER JOIN orders o ON o.account_id = a.id
INNER JOIN region r ON r.id = s.region_id
GROUP BY r.name
HAVING SUM(o.total_amt_usd) = (
  		SELECT SUM(o.total_amt_usd) total_amt
		FROM sales_reps s 
		INNER JOIN accounts a ON a.sales_rep_id = s.id
		INNER JOIN orders o ON o.account_id = a.id
		INNER JOIN region r ON r.id = s.region_id
		GROUP BY r.name
		ORDER BY 1 DESC
		LIMIT 1)


-- 5) How many accounts had more total purchases than the account name which has bought the most standard_qty paper throughout their lifetime as a customer?
-- 5.1) We need two separate tables
-- 5.1.1) One with the the account with the highest purchase of std_qty_paper and the total sales for this account. This table is the condition to be evaluated in the other table.
-- 5.1.2) The second table we filter for all accounts that have more total sales than the account in the first table (5.1.2). 
-- 5.1.3) We finally later count the number of accounts that satisfy this condition.

SELECT COUNT(*)
FROM (SELECT a.name AS account_name
	FROM accounts a 
	INNER JOIN orders o 
	ON o.account_id = a.id
	GROUP BY 1
	HAVING SUM(o.total) > (SELECT total_purchase
    	FROM (SELECT a.name AS account_name,
     	   SUM(o.standard_qty) AS total_std,
		   SUM(o.total) AS total_purchase
		   FROM accounts a 
           INNER JOIN orders o ON o.account_id = a.id
           GROUP BY 1
           ORDER BY 2 DESC
           LIMIT 1) AS sub)) AS sub2;
 

-- 6) For the account with the highest expense, how many web events were done per channel.
-- 6.1.) We need again two data sets. 
-- 6.1.1) First we get the account_name with the highest expense. 
-- 6.1.2) We then get all web events per channel and look into only those for the account of the first data.

SELECT a.name AS account_name,
	 w.channel AS channel,
	 COUNT(*) AS counts_per_channel	
FROM web_events w
INNER JOIN accounts a
ON w.account_id = a.id
WHERE a.name = (SELECT account_name 
				FROM (SELECT a.name AS account_name,
	   					 SUM(total_amt_usd) AS total_expense
					FROM accounts a
                      		INNER JOIN orders o
                     		ON o.account_id = a.id
                     		GROUP BY a.name
                     		ORDER BY 2 DESC
                      		LIMIT 1) as account_name)
GROUP BY 1, 2
ORDER BY 3 DESC; 

-- 6.1.3) An alternative to the WHERE clause is to in the ON statement use the account_name as an additional condition to be merged. 

SELECT a.name AS account_name,
	 w.channel AS channel,
	 COUNT(*) AS counts_per_channel	
FROM web_events w
INNER JOIN accounts a
ON w.account_id = a.id AND a.name = (SELECT account_name -- instead of later filtering out with the WHERE clause we already merge only web events for the correct acocunt.
						 FROM (SELECT a.name AS account_name,
	   					 	       SUM(total_amt_usd) AS total_expense
							FROM accounts a
                      				INNER JOIN orders o
                     				ON o.account_id = a.id
                     				GROUP BY a.name
                     				ORDER BY 2 DESC
                      				LIMIT 1) as account_name)
GROUP BY 1, 2
ORDER BY 3 DESC; 


-- 7) What was the average expense among the top 10 spenders in the entired period
-- 7.1.1) We need to 1st get the top 10 accounts and their sums across the entire period
-- 7.1.2) We then average over these top 10 accounts

SELECT AVG(sum) AS average_spent
FROM (SELECT a.name AS account_name,
		SUM(total_amt_usd)
FROM accounts a 
JOIN orders o
ON a.id = o.account_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10) AS top_10_accounts

-- 8) What is the lifetime average amount spent for the companies that spent more per order, on average, than the average of all orders.

-- 8.1.1) First calculate the average of all orders.
-- 8.1.2) Calculate the average price per order per acocunts.
-- 8.1.3) Calculate the average among the accounts who have only averages above the total average of all orders 

SELECT AVG(top_accounts) AS avg_top_accounts
FROM (SELECT a.name AS account_name
		, AVG(total_amt_usd) as top_accounts
	FROM orders o
	INNER JOIN accounts a
	ON o.account_id = a.id
	GROUP BY 1
	HAVING AVG(total_amt_usd) > (SELECT AVG(total_amt_usd) as avg_total_orders
					     FROM orders o)) AS top_accounts;


-- *-------------- CTE's ------------------*
