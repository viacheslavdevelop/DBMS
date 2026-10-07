-- 1. Выборка: Получить всех клиентов, у которых в JSON-объекте любимый жанр "боевик"
SELECT 
    c.fio,
    cd.id_client,
    cd.details
FROM Client_Details cd
JOIN Clients c ON cd.id_client = c.id_client
WHERE cd.details @> '{"favorite_genres": ["боевик"]}'::jsonb;