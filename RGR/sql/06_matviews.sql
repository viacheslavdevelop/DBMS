SET client_encoding = 'UTF8';

DROP MATERIALIZED VIEW IF EXISTS mv_monthly_sales CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_product_stock CASCADE;

CREATE MATERIALIZED VIEW mv_product_stock AS
WITH stock AS (
    SELECT id_product, SUM(current_volume) AS total_volume
    FROM tanks
    WHERE status <> 'выведен'
    GROUP BY id_product
)
SELECT p.id_product,
       p.product_code,
       p.name,
       p.category,
       COALESCE(s.total_volume, 0) AS total_volume,
       p.min_reserve,
       COALESCE(s.total_volume, 0) - p.min_reserve AS deviation,
       CASE
           WHEN COALESCE(s.total_volume, 0) < p.min_reserve THEN 'дефицит'
           WHEN COALESCE(s.total_volume, 0) < p.min_reserve * 1.2 THEN 'ниже нормы'
           ELSE 'норма'
       END AS reserve_status,
       now() AS refreshed_at
FROM products p
LEFT JOIN stock s ON s.id_product = p.id_product;

CREATE UNIQUE INDEX mv_product_stock_pk ON mv_product_stock (id_product);

CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT date_trunc('month', s.shipment_date)::date AS month,
       p.id_product,
       p.product_code,
       p.name,
       COUNT(DISTINCT s.id_shipment) AS shipments_count,
       SUM(si.volume) AS volume,
       ROUND(SUM(si.total_cost), 2) AS revenue,
       ROUND(SUM(si.total_cost) / NULLIF(SUM(si.volume), 0), 2) AS avg_price
FROM shipments s
JOIN shipment_items si ON si.id_shipment = s.id_shipment
JOIN products p ON p.id_product = si.id_product
WHERE s.status = 'отгружена'
GROUP BY 1, 2, 3, 4;

CREATE UNIQUE INDEX mv_monthly_sales_pk ON mv_monthly_sales (month, id_product);

REFRESH MATERIALIZED VIEW mv_product_stock;
REFRESH MATERIALIZED VIEW mv_monthly_sales;
