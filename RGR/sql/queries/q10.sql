\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q10 — позиции поставок с кодами АИ-92, АИ-95 и ДТ-Л'

SELECT d.delivery_number,
       d.delivery_date,
       p.product_code,
       p.name,
       di.volume,
       di.price_per_liter,
       di.total_cost
FROM delivery_items di
JOIN deliveries d ON d.id_delivery = di.id_delivery
JOIN products p ON p.id_product = di.id_product
WHERE p.product_code IN ('АИ-92', 'АИ-95', 'ДТ-Л')
ORDER BY d.delivery_date, d.delivery_number, di.line_no;
