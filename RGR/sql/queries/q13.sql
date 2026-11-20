\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q13 — накопленная сумма и скользящее среднее по отгрузкам'

SELECT s.shipment_number,
       s.shipment_date,
       s.total_amount,
       SUM(s.total_amount) OVER (ORDER BY s.shipment_date, s.id_shipment) AS cumulative_amount,
       ROUND(AVG(s.total_amount) OVER (
           ORDER BY s.shipment_date, s.id_shipment
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ), 2) AS moving_avg_3
FROM shipments s
WHERE s.status = 'отгружена'
ORDER BY s.shipment_date, s.shipment_number;
