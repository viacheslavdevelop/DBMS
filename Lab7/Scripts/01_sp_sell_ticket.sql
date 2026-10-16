CREATE OR REPLACE PROCEDURE sp_sell_ticket(
    p_session_id   INTEGER,
    p_row_num      INTEGER,
    p_seat_num     INTEGER,
    p_employee_id  INTEGER,
    p_preorder_id  INTEGER DEFAULT NULL,
    p_discount_pct NUMERIC DEFAULT 0.00
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_base_price  NUMERIC(5, 2);
    v_final_price NUMERIC(5, 2);
BEGIN
    SELECT base_price INTO STRICT v_base_price
    FROM Sessions
    WHERE id_session = p_session_id;

    v_final_price := ROUND(v_base_price * (1.0 - p_discount_pct / 100.0), 2);

    INSERT INTO Tickets (
        id_preorder,
        seat_num,
        row_num,
        actual_price,
        id_session,
        id_employee
    )
    VALUES (
        p_preorder_id,
        p_seat_num,
        p_row_num,
        v_final_price,
        p_session_id,
        p_employee_id
    );

    IF p_preorder_id IS NOT NULL THEN
        UPDATE Preorders
        SET status = 'выкуплен'
        WHERE id_preorder = p_preorder_id;
    END IF;

    RAISE NOTICE 'Билет успешно оформлен. Итоговая стоимость: % руб.', v_final_price;
END;
$$;