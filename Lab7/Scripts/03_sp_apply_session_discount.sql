CREATE OR REPLACE PROCEDURE sp_apply_session_discount(
    p_session_id   INTEGER,
    p_discount_pct NUMERIC
)
LANGUAGE sql
AS $$
    UPDATE Sessions
    SET base_price = ROUND(base_price * (1.0 - p_discount_pct / 100.0), 2)
    WHERE id_session = p_session_id;
$$;
