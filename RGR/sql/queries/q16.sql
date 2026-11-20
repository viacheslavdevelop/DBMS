\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q16 — обеспеченность запасами относительно минимального резерва'

SELECT p.product_code,
       p.name,
       p.min_reserve,
       COALESCE(SUM(t.current_volume), 0) AS total_volume,
       ROUND(COALESCE(SUM(t.current_volume), 0) / NULLIF(p.min_reserve, 0) * 100, 2) AS reserve_pct
FROM products p
LEFT JOIN tanks t
       ON t.id_product = p.id_product
      AND t.status <> 'выведен'
GROUP BY p.id_product, p.product_code, p.name, p.min_reserve
ORDER BY reserve_pct ASC, p.product_code;
