\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q20 — клиенты, покупавшие АИ-95, но не покупавшие ДТ-Л'

SELECT c.id_client, c.name, c.client_type
FROM clients c
WHERE c.id_client IN (
        SELECT s.id_client
        FROM shipments s
        JOIN shipment_items si ON si.id_shipment = s.id_shipment
        JOIN products p ON p.id_product = si.id_product
        WHERE s.status = 'отгружена'
          AND p.product_code = 'АИ-95'
      )
  AND c.id_client NOT IN (
        SELECT s.id_client
        FROM shipments s
        JOIN shipment_items si ON si.id_shipment = s.id_shipment
        JOIN products p ON p.id_product = si.id_product
        WHERE s.status = 'отгружена'
          AND p.product_code = 'ДТ-Л'
      )
ORDER BY c.name;
