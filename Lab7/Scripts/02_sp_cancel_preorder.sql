CREATE OR REPLACE PROCEDURE sp_cancel_preorder(p_preorder_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_status VARCHAR(20);
BEGIN
    SELECT status INTO v_current_status
    FROM Preorders
    WHERE id_preorder = p_preorder_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Предзаказ с ID % не найден.', p_preorder_id;
    END IF;

    IF v_current_status = 'выкуплен' THEN
        RAISE EXCEPTION 'Невозможно отменить предзаказ %, так как он уже выкуплен.', p_preorder_id;
    END IF;

    UPDATE Preorders
    SET status = 'отменен'
    WHERE id_preorder = p_preorder_id;

    UPDATE Tickets
    SET id_preorder = NULL
    WHERE id_preorder = p_preorder_id;

    RAISE NOTICE 'Предзаказ ID % успешно отменен.', p_preorder_id;
END;
$$;
