\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q08 — поставки ООО «Нефтеснаб» за IV квартал 2025 года'

SELECT d.delivery_number, d.delivery_date, d.invoice_number, d.status, d.total_amount
FROM deliveries d
JOIN suppliers s ON s.id_supplier = d.id_supplier
WHERE s.name = 'ООО «Нефтеснаб»'
  AND d.delivery_date BETWEEN DATE '2025-09-01' AND DATE '2025-12-31'
ORDER BY d.delivery_date, d.delivery_number;
