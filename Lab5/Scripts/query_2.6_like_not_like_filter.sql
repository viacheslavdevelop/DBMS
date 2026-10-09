SELECT fio AS "ФИО", phone AS "Телефон"
FROM Clients
WHERE phone LIKE '+7%' AND fio NOT LIKE '%Иван%';
