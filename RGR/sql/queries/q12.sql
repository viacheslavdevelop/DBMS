\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q12 — ранжирование резервуаров по объёму внутри категории продукта'

SELECT t.id_tank,
       t.tank_number,
       p.category,
       p.product_code,
       t.current_volume,
       RANK() OVER (PARTITION BY p.category ORDER BY t.current_volume DESC) AS rank_in_category,
       ROUND(t.current_volume / t.capacity * 100, 2) AS fill_pct
FROM tanks t
JOIN products p ON p.id_product = t.id_product
WHERE t.status = 'в эксплуатации'
ORDER BY p.category, rank_in_category, t.tank_number;
