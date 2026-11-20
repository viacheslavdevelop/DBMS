\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q21 — резервуары с объёмом выше любого запаса мазута и масла, но ниже любой ёмкости бензина'

SELECT t.tank_number,
       p.product_code,
       p.category,
       t.current_volume,
       t.capacity
FROM tanks t
JOIN products p ON p.id_product = t.id_product
WHERE t.current_volume > ANY (
        SELECT t2.current_volume
        FROM tanks t2
        JOIN products p2 ON p2.id_product = t2.id_product
        WHERE p2.category IN ('мазут', 'масло')
      )
  AND t.current_volume < ALL (
        SELECT t3.capacity
        FROM tanks t3
        JOIN products p3 ON p3.id_product = t3.id_product
        WHERE p3.category = 'бензин'
      )
ORDER BY t.current_volume DESC, t.tank_number;
