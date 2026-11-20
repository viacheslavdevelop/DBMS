\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q07 — отгруженные объёмы свыше 1000 л по цене ниже 60 руб.'

SELECT s.shipment_number,
       s.shipment_date,
       p.product_code,
       si.volume,
       si.price_per_liter,
       si.total_cost
FROM shipments s
JOIN shipment_items si ON si.id_shipment = s.id_shipment
JOIN products p ON p.id_product = si.id_product
WHERE s.status = 'отгружена'
  AND si.volume > 1000
  AND si.price_per_liter < 60
ORDER BY s.shipment_date, s.shipment_number, si.line_no;
