CREATE OR REPLACE PROCEDURE session_select(
    IN p_session_id integer,
    IN p_movie_id integer,
    IN p_hall_id integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    c_session_id integer;
    c_movie_id integer;
    c_movie_title varchar(100);
    c_hall_id integer;
    c_hall_name varchar(20);
    c_session_dt timestamp;
    c_base_price numeric(5, 2);
    cur CURSOR FOR
        SELECT s.id_session, s.id_movie, m.title, s.id_hall, h.name, s.session_datetime, s.base_price
        FROM Sessions s
        JOIN Movies m ON m.id_movie = s.id_movie
        JOIN Halls h ON h.id_hall = s.id_hall
        WHERE (p_session_id IS NULL OR s.id_session = p_session_id)
          AND (p_movie_id IS NULL OR s.id_movie = p_movie_id)
          AND (p_hall_id IS NULL OR s.id_hall = p_hall_id)
        ORDER BY s.id_session;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO c_session_id, c_movie_id, c_movie_title, c_hall_id, c_hall_name, c_session_dt, c_base_price;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Сеанс ID: %, Фильм: % (ID: %), Зал: % (ID: %), Время: %, Базовая цена: %',
            c_session_id, c_movie_title, c_movie_id, c_hall_name, c_hall_id, c_session_dt, c_base_price;
    END LOOP;
    CLOSE cur;
END;
$$;
