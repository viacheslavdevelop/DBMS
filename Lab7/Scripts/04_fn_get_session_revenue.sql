CREATE OR REPLACE FUNCTION fn_get_session_revenue(p_session_id INTEGER)
RETURNS NUMERIC(10, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_revenue NUMERIC(10, 2);
BEGIN
    SELECT COALESCE(SUM(actual_price), 0.00)
    INTO v_total_revenue
    FROM Tickets
    WHERE id_session = p_session_id;

    RETURN v_total_revenue;
END;
$$;
