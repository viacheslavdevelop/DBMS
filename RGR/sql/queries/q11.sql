\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q11 — клиенты с отгрузками, не покупавшие мазут'

SELECT c.id_client,
       c.name,
       c.client_type,
       COUNT(DISTINCT s.id_shipment) AS shipments_count
FROM clients c
JOIN shipments s ON s.id_client = c.id_client
WHERE s.status = 'отгружена'
  AND c.id_client NOT IN (
      SELECT s2.id_client
      FROM shipments s2
      JOIN shipment_items si ON si.id_shipment = s2.id_shipment
      JOIN products p ON p.id_product = si.id_product
      WHERE s2.status = 'отгружена'
        AND p.category = 'мазут'
  )
GROUP BY c.id_client, c.name, c.client_type
ORDER BY c.name;
