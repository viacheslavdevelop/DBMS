-- 2. Выборка: Проверить, у скольких клиентов ключ 'has_vip' = true
SELECT count(*) 
FROM Client_Details 
WHERE details @> '{"has_vip": true}'::jsonb;