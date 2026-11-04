CREATE OR REPLACE FUNCTION fn_validate_ticket_sale()
RETURNS trigger
AS $$
DECLARE
    v_hall_capacity INTEGER;
    v_sold_count INTEGER;
    v_preorder_status VARCHAR(20);
BEGIN
    SELECT h.capacity INTO v_hall_capacity
    FROM Sessions s
    JOIN Halls h ON s.id_hall = h.id_hall
    WHERE s.id_session = NEW.id_session;

    SELECT COUNT(*) INTO v_sold_count
    FROM Tickets
    WHERE id_session = NEW.id_session;

    IF v_sold_count >= v_hall_capacity OR NEW.seat_num > v_hall_capacity THEN
        RAISE EXCEPTION 'Отказ в продаже: превышена вместимость зала (%) для сеанса ID=%', v_hall_capacity, NEW.id_session;
    END IF;

    IF NEW.id_preorder IS NOT NULL THEN
        SELECT status INTO v_preorder_status
        FROM Preorders
        WHERE id_preorder = NEW.id_preorder;

        IF v_preorder_status = 'отменен' THEN
            RAISE EXCEPTION 'Отказ в продаже: предзаказ ID=% отменен', NEW.id_preorder;
        END IF;

        UPDATE Preorders
        SET status = 'выкуплен'
        WHERE id_preorder = NEW.id_preorder;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_before_ticket_insert
BEFORE INSERT ON Tickets
FOR EACH ROW
EXECUTE FUNCTION fn_validate_ticket_sale();