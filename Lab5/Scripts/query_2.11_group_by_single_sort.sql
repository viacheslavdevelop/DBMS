SELECT 
    id_hall AS "ID зала", 
    COUNT(id_session) AS "Количество сеансов"
FROM Sessions
GROUP BY id_hall
ORDER BY "Количество сеансов" DESC;
