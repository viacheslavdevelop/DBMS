SELECT id_ticket, actual_price AS "Стоимость"
FROM Tickets
ORDER BY actual_price DESC
LIMIT 3 OFFSET 3;
