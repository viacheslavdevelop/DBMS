CREATE TABLE IF NOT EXISTS active_preorders (
    ap_id_preorder integer PRIMARY KEY,
    ap_id_client integer NOT NULL,
    ap_client_fio varchar(100) NOT NULL,
    ap_client_phone varchar(15) NOT NULL,
    ap_booking_datetime timestamp NOT NULL
);

CREATE OR REPLACE PROCEDURE fill_active_preorders()
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_preorder integer;
    v_id_client integer;
    v_fio varchar(100);
    v_phone varchar(15);
    v_booking_dt timestamp;
    cur CURSOR FOR
        SELECT p.id_preorder, p.id_client, c.fio, c.phone, p.booking_datetime
        FROM Preorders p
        JOIN Clients c ON c.id_client = p.id_client
        WHERE p.status = 'активен';
BEGIN
    TRUNCATE TABLE active_preorders;
    OPEN cur;
    LOOP
        FETCH cur INTO v_id_preorder, v_id_client, v_fio, v_phone, v_booking_dt;
        EXIT WHEN NOT FOUND;
        INSERT INTO active_preorders VALUES (v_id_preorder, v_id_client, v_fio, v_phone, v_booking_dt);
    END LOOP;
    CLOSE cur;
END;
$$;
