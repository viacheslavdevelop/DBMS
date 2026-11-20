\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q22 — клиенты с отгрузками с 2025 года и без отменённых документов'

SELECT c.id_client, c.name, c.client_type
FROM clients c
WHERE EXISTS (
        SELECT 1
        FROM shipments s
        WHERE s.id_client = c.id_client
          AND s.status = 'отгружена'
          AND s.shipment_date >= DATE '2025-01-01'
      )
  AND NOT EXISTS (
        SELECT 1
        FROM shipments s
        WHERE s.id_client = c.id_client
          AND s.status = 'отменена'
      )
ORDER BY c.name;
