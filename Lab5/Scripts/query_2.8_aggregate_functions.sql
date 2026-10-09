SELECT 
    COUNT(id_ticket) AS "Всего билетов", 
    SUM(actual_price) AS "Общая выручка", 
    ROUND(AVG(actual_price), 2) AS "Средняя цена билета"
FROM Tickets;
