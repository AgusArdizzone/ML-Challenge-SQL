-- Nota: Respuestas escritas en Oracle SQL


-- 1. Listar los usuarios que cumplan años el día de hoy
--    cuya cantidad de ventas realizadas en enero 2020 sea superior a 1500.

/*
Query to get data from the Customers that it's their birthday today
and they have made 1500 sales or more in January 2020.
We can see some info about the customer in the output like their ID,
username, full name and email.
*/
SELECT c.ID as "Customer ID",
       c.USERNAME as "Customer Username",
       c.FIRST_NAME as "First Name",
       c.LAST_NAME as "Last Name",
       c.EMAIL as "Email"
FROM CUSTOMER c
JOIN (
--  Subquery to get the seller_id's with more than 1500 sales in January 2020.
    SELECT i.SELLER_ID
    FROM CUSTOMER_ORDER co
    JOIN ITEM i ON co.ITEM_ID = i.ID
    WHERE co.ORDER_DATE >= TO_DATE('2020-01-01', 'YYYY-MM-DD')
      AND co.ORDER_DATE < TO_DATE('2020-02-01', 'YYYY-MM-DD')
    GROUP BY i.SELLER_ID
-- To prevent any duplicates, we use DISTINCT on the order ID.
    HAVING COUNT(DISTINCT CO.ID) > 1500
) s ON C.ID = s.SELLER_ID
WHERE EXTRACT(MONTH FROM c.BIRTH_DATE) = EXTRACT(MONTH FROM SYSDATE)
  AND EXTRACT(DAY FROM c.BIRTH_DATE) = EXTRACT(DAY FROM SYSDATE);


-- 2. Por cada mes del 2020, se solicita el top 5 de usuarios que más
--    vendieron($) en la categoría Celulares.
--    Se requiere el mes y año de análisis, nombre y apellido del vendedor,
--    cantidad de ventas realizadas, cantidad de productos vendidos
--    y el monto total transaccionado.

/*
Query that list the top 5 sellers of the category "Celulares" for each month of 2020.
We can see the month rank, the month and year, info about the seller
and different sales metrics.
For better readability of the information, 
we ordered it by month and year (most recently first) and rank.
*/
SELECT 
    month_rank as "Month Rank",
    year_month as "Year Month",
    FIRST_NAME as "First Name",
    LAST_NAME as "Last Name",
    tota_sales as "Total Sales",
    total_items_sold as "Total Items Sold",
    total_amount as "Total Amount"
FROM (
-- Subqquery to get a rank of the sellers by month and year,
-- alongside calculating the sales metrics. and filtering by category and year.
-- We use the ROW_NUMBER function instead of RANK or DENSE_RANK since these
-- functions could return more than 5 sellers in case of a tie.
SELECT
    trunc(co.ORDER_DATE, 'MM') AS year_month,
    C.FIRST_NAME,
    C.LAST_NAME,
    COUNT(co.ID) AS tota_sales,
    SUM(co.QUANTITY) AS total_items_sold,
    SUM(co.TOTAL_AMOUNT) AS total_amount,
    ROW_NUMBER() OVER (
            PARTITION BY TRUNC(co.ORDER_DATE, 'MM')
            ORDER BY SUM(co.TOTAL_AMOUNT) DESC
        ) AS month_rank
FROM
    CUSTOMER_ORDER co
    JOIN ITEM i ON co.ITEM_ID = i.ID
    JOIN CATEGORY cat ON i.CATEGORY_ID = cat.ID
    JOIN CUSTOMER c ON i.SELLER_ID = c.ID
WHERE
    cat.NAME = 'Celulares'
    AND co.ORDER_DATE >= TO_DATE('2020-01-01', 'YYYY-MM-DD')
    AND co.ORDER_DATE < TO_DATE('2021-01-01', 'YYYY-MM-DD')
GROUP BY
    trunc(co.ORDER_DATE, 'MM'),
    c.ID,
    c.FIRST_NAME,
    c.LAST_NAME
)
-- We just want the first top 5 seellers of each month.
where month_rank <= 5
ORDER BY year_month desc, month_rank;

-- 3. Se solicita poblar una nueva tabla con el precio y estado de los Ítems
--    a fin del día. Tener en cuenta que debe ser reprocesable. Vale resaltar
--    que en la tabla Item, vamos a tener únicamente el último estado informado
--    por la PK definida. (Se puede resolver a través de StoredProcedure)

-- Nota: la tabla ITEM_HISTORY esta definida en el archivo create_tables.sql

CREATE PROCEDURE ITEM_HISTORY_DATA_LOAD AS
BEGIN
        INSERT INTO ITEM_HISTORY(ITEM_ID, PRICE, STATUS, INSERT_DATE)
        SELECT ID, PRICE, STATUS, SYSDATE
        FROM ITEM;
        COMMIT;
END;
/

-- PLUS: podemos crear un job dentro de DBMS_SCHEDULER para que
--       ejecute el procedimiento cada fin de día:

BEGIN
    DBMS_SCHEDULER.create_job (
        job_name        => 'ITEM_HISTORY_DATA_LOAD_JOB',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN ITEM_HISTORY_DATA_LOAD; END;',
        start_date      => TRUNC(SYSDATE) + 1, -- Start tomorrow
        repeat_interval  => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=0; BYSECOND=0', -- Daily at midnight
        enabled         => TRUE
    );
END;