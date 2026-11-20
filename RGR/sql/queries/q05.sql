\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q05 — позиции поставок с ценой выше 50 руб. за литр'

SELECT d.delivery_number,
       d.delivery_date,
       p.product_code,
       t.tank_number,
       di.volume,
       di.price_per_liter,
       ROUND(di.volume * di.price_per_liter, 2) AS line_total
FROM deliveries d
JOIN delivery_items di ON di.id_delivery = d.id_delivery
JOIN products p ON p.id_product = di.id_product
JOIN tanks t ON t.id_tank = di.id_tank
WHERE di.price_per_liter > 50
ORDER BY d.delivery_date, d.delivery_number, di.line_no;
