\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q23 — продукты с дефицитом запаса по данным материализованного представления'

SELECT product_code,
       name,
       category,
       total_volume,
       min_reserve,
       deviation,
       reserve_status
FROM mv_product_stock
WHERE reserve_status = 'дефицит'
ORDER BY deviation, product_code;
