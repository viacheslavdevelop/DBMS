SELECT title AS "Название фильма"
FROM Movies
WHERE title ~ '^[А-М].*';
