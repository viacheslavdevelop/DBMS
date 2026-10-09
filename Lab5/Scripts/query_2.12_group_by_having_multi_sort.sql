SELECT 
    id_session AS "ID сеанса", 
    SUM(actual_price) AS "Выручка за сеанс"
FROM Tickets
GROUP BY id_session
HAVING SUM(actual_price) > 1000
ORDER BY "Выручка за сеанс" DESC, id_session ASC;
