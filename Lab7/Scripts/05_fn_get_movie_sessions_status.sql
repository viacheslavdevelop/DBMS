CREATE OR REPLACE FUNCTION fn_get_movie_sessions_status(p_movie_id INTEGER)
RETURNS TABLE (
    session_id      INTEGER,
    session_time    TIMESTAMP,
    hall_name       VARCHAR(20),
    total_capacity  INTEGER,
    sold_tickets    BIGINT,
    available_seats BIGINT
)
LANGUAGE sql
AS $$
    SELECT
        s.id_session,
        s.session_datetime,
        h.name AS hall_name,
        h.capacity AS total_capacity,
        COUNT(t.id_ticket) AS sold_tickets,
        (h.capacity - COUNT(t.id_ticket)) AS available_seats
    FROM Sessions s
    JOIN Halls h ON s.id_hall = h.id_hall
    LEFT JOIN Tickets t ON s.id_session = t.id_session
    WHERE s.id_movie = p_movie_id
    GROUP BY s.id_session, s.session_datetime, h.name, h.capacity
    ORDER BY s.session_datetime;
$$;
