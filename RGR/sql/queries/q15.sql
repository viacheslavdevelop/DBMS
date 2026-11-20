\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q15 — масса продукта в резервуарах и степень заполнения'

SELECT t.tank_number,
       p.product_code,
       p.category,
       t.current_volume,
       p.density,
       ROUND(t.current_volume * p.density / 1000000, 3) AS mass_tons,
       ROUND(t.current_volume / t.capacity * 100, 2) AS fill_pct
FROM tanks t
JOIN products p ON p.id_product = t.id_product
ORDER BY mass_tons DESC, t.tank_number;
