-- Nota: Respuestas escritas en Oracle SQL


-- 1. Listar los usuarios que cumplan años el día de hoy
--    cuya cantidad de ventas realizadas en enero 2020 sea superior a 1500.

SELECT c.ID as "Customer ID",
       c.USERNAME as "Customer Username",
       c.FIRST_NAME as "First Name",
       c.LAST_NAME as "Last Name",
       c.EMAIL as "Email"
FROM CUSTOMER c
JOIN (
    SELECT i.SELLER_ID
    FROM CUSTOMER_ORDER co
    JOIN ITEM i ON co.ITEM_ID = i.ID
    WHERE co.ORDER_DATE >= TO_DATE('2020-01-01', 'YYYY-MM-DD')
      AND co.ORDER_DATE < TO_DATE('2020-02-01', 'YYYY-MM-DD')
    GROUP BY i.SELLER_ID
    HAVING COUNT(DISTINCT CO.ID) > 1500
) s ON C.ID = s.SELLER_ID
WHERE EXTRACT(MONTH FROM c.BIRTH_DATE) = EXTRACT(MONTH FROM SYSDATE)
  AND EXTRACT(DAY FROM c.BIRTH_DATE) = EXTRACT(DAY FROM SYSDATE);


-- 2. Por cada mes del 2020, se solicita el top 5 de usuarios que más
--    vendieron($) en la categoría Celulares.
--    Se requiere el mes y año de análisis, nombre y apellido del vendedor,
--    cantidad de ventas realizadas, cantidad de productos vendidos
--    y el monto total transaccionado.

SELECT 
    month_rank as "Month Rank",
    year_month as "Year Month",
    FIRST_NAME as "First Name",
    LAST_NAME as "Last Name",
    tota_sales as "Total Sales",
    total_items_sold as "Total Items Sold",
    total_amount as "Total Amount"
FROM (
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