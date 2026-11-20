\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q17 — сводные показатели поставок по продуктам'

SELECT p.product_code,
       p.name,
       COUNT(DISTINCT di.id_delivery) AS deliveries_count,
       SUM(di.volume) AS total_volume,
       ROUND(SUM(di.total_cost), 2) AS total_cost,
       ROUND(SUM(di.total_cost) / NULLIF(SUM(di.volume), 0), 2) AS avg_price
FROM products p
JOIN delivery_items di ON di.id_product = p.id_product
GROUP BY p.id_product, p.product_code, p.name
ORDER BY total_volume DESC, p.product_code;
