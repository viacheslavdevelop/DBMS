\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q09 — розничные отгрузки вне I квартала 2026 года'

SELECT s.shipment_number,
       c.name AS client_name,
       s.shipment_date,
       s.total_amount
FROM shipments s
JOIN clients c ON c.id_client = s.id_client
WHERE c.client_type = 'розничный'
  AND s.shipment_date NOT BETWEEN DATE '2026-01-01' AND DATE '2026-03-31'
  AND s.status <> 'отменена'
ORDER BY s.shipment_date, s.shipment_number;
