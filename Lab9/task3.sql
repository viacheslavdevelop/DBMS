CREATE OR REPLACE FUNCTION get_movies_by_genre(refcursor, p_genre varchar)
RETURNS refcursor
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN $1 FOR
        SELECT m.id_movie, m.title, m.genre, m.duration, m.age_restriction, i.license_cost
        FROM Movies m
        JOIN Invoices i ON i.id_invoice = m.id_invoice
        WHERE m.genre = p_genre
        ORDER BY m.id_movie;
    RETURN $1;
END;
$$;
