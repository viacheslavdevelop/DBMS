CREATE OR REPLACE FUNCTION fn_prevent_drop_table()
RETURNS event_trigger
AS $$
BEGIN
    IF tg_tag = 'DROP TABLE' THEN
        RAISE EXCEPTION 'Операция % заблокирована триггером безопасности БД CinemaDB!', tg_tag;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER ev_trg_prevent_drop_table
ON ddl_command_start
EXECUTE FUNCTION fn_prevent_drop_table();