-- 4. Обновление: Изменить значение внутри массива в JSON (добавить новый жанр на нулевую позицию)
UPDATE Client_Details
SET details = jsonb_set(details, '{favorite_genres, 0}', '"боевик"')
WHERE id_client = 1;