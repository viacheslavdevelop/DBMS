\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q18 — клиенты с суммарным объёмом отгрузок свыше 100 000 руб.'

SELECT c.name,
       c.client_type,
       COUNT(DISTINCT s.id_shipment) AS shipments_count,
       SUM(si.volume) AS total_volume,
       ROUND(SUM(si.total_cost), 2) AS total_amount
FROM clients c
JOIN shipments s ON s.id_client = c.id_client
JOIN shipment_items si ON si.id_shipment = s.id_shipment
WHERE s.status = 'отгружена'
GROUP BY c.id_client, c.name, c.client_type
HAVING SUM(si.total_cost) > 100000
ORDER BY c.client_type, total_amount DESC, c.name;
