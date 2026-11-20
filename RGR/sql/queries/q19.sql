\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q19 — отклонение суммы отгрузки от средней по отгруженным документам'

SELECT s.shipment_number,
       s.shipment_date,
       s.total_amount,
       ROUND(s.total_amount - (
           SELECT AVG(total_amount)
           FROM shipments
           WHERE status = 'отгружена'
       ), 2) AS deviation_from_avg
FROM shipments s
WHERE s.status = 'отгружена'
ORDER BY deviation_from_avg DESC, s.shipment_number;
