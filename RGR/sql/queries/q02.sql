\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q02 — активные бензины с октановым числом не ниже 95'

SELECT id_product, product_code, name, category, octane_rating, min_reserve
FROM products
WHERE is_active = TRUE
  AND category = 'бензин'
  AND NOT (octane_rating < 95)
ORDER BY octane_rating DESC, product_code;
