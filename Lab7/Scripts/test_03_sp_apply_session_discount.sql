SELECT id_session, session_datetime, base_price AS price_before_discount
FROM Sessions
WHERE id_session = 2;

CALL sp_apply_session_discount(
    p_session_id   => 2,
    p_discount_pct => 20.00
);

SELECT id_session, session_datetime, base_price AS price_after_discount
FROM Sessions
WHERE id_session = 2;
