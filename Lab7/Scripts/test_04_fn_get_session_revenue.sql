SELECT 
    s.id_session,
    m.title AS movie_title,
    s.session_datetime,
    fn_get_session_revenue(s.id_session) AS total_revenue_rub
FROM Sessions s
JOIN Movies m ON s.id_movie = m.id_movie
WHERE s.id_session = 1;
