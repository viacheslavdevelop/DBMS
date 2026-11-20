\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q06 — отгрузки оптовым клиентам или на сумму свыше 100 000 руб.'

SELECT s.shipment_number,
       c.name AS client_name,
       c.client_type,
       s.shipment_date,
       s.total_amount
FROM shipments s
JOIN clients c ON c.id_client = s.id_client
WHERE (c.client_type = 'оптовый' OR s.total_amount > 100000)
  AND s.status <> 'отменена'
  AND s.shipment_date >= DATE '2025-01-01'
ORDER BY s.shipment_date, s.shipment_number;
