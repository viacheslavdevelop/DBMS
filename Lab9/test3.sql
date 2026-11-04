BEGIN;
SELECT get_movies_by_genre('movie_cursor', (SELECT genre FROM Movies LIMIT 1));
FETCH ALL IN movie_cursor;
