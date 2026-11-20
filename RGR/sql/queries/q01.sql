\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q01 — оптовые клиенты'

SELECT id_client, name, client_type, phone, contract_date
FROM clients
WHERE client_type = 'оптовый'
ORDER BY name;
