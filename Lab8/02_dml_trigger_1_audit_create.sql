CREATE TABLE IF NOT EXISTS tickets_audit (
    audit_id SERIAL PRIMARY KEY,
    operation CHAR(1) NOT NULL,
    stamp TIMESTAMP NOT NULL,
    userid TEXT NOT NULL,
    id_ticket INTEGER NOT NULL,
    id_preorder INTEGER,
    seat_num INTEGER NOT NULL,
    row_num INTEGER NOT NULL,
    actual_price NUMERIC(5, 2) NOT NULL,
    id_session INTEGER NOT NULL,
    id_employee INTEGER NOT NULL
);

CREATE OR REPLACE FUNCTION fn_process_tickets_audit()
RETURNS trigger
AS $$
DECLARE
    op CHAR(1);
    ticket RECORD;
BEGIN
    IF TG_OP = 'DELETE' THEN
        op := 'D';
        ticket := OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        op := 'U';
        ticket := NEW;
    ELSE
        op := 'I';
        ticket := NEW;
    END IF;

    INSERT INTO tickets_audit (
        operation, stamp, userid, id_ticket, id_preorder,
        seat_num, row_num, actual_price, id_session, id_employee
    )
    VALUES (
        op, now(), user, ticket.id_ticket, ticket.id_preorder,
        ticket.seat_num, ticket.row_num, ticket.actual_price,
        ticket.id_session, ticket.id_employee
    );

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tickets_audit
AFTER INSERT OR UPDATE OR DELETE ON Tickets
FOR EACH ROW
EXECUTE FUNCTION fn_process_tickets_audit();
