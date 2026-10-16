SELECT 
    session_id,
    session_time,
    hall_name,
    total_capacity,
    sold_tickets,
    available_seats
FROM fn_get_movie_sessions_status(1);
