\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q04 — резервуары в эксплуатации, заполненные не более чем на 50 %'

SELECT id_tank, tank_number, capacity, current_volume, status
FROM tanks
WHERE status = 'в эксплуатации'
  AND current_volume <= capacity * 0.5
  AND capacity >= 10000
ORDER BY tank_number;
