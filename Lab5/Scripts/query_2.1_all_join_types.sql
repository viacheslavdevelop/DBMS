SELECT 
    c.fio AS "Клиент", 
    p.id_preorder AS "Номер брони", 
    t.id_ticket AS "Номер билета", 
    s.session_datetime AS "Время сеанса",
    m.title AS "Фильм"
FROM Clients c
LEFT JOIN Preorders p ON c.id_client = p.id_client
FULL JOIN Tickets t ON p.id_preorder = t.id_preorder
RIGHT JOIN Sessions s ON t.id_session = s.id_session
INNER JOIN Movies m ON s.id_movie = m.id_movie;
