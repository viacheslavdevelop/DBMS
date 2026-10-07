-- 3. Обновление: Добавить новое свойство (любимый напиток) клиенту с id_client = 1
UPDATE Client_Details
SET details = details || '{"favorite_drink": "добрый кола"}'::jsonb
WHERE id_client = 1;