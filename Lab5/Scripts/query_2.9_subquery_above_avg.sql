SELECT title AS "Название фильма", duration AS "Продолжительность"
FROM Movies
WHERE duration > (
    SELECT AVG(duration) FROM Movies
)
ORDER BY duration DESC;
