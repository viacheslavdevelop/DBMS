CREATE TABLE ddl_audit_log (
    log_id SERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    command_tag TEXT NOT NULL,
    username TEXT NOT NULL,
    event_time TIMESTAMP NOT NULL
);

CREATE OR REPLACE FUNCTION fn_ddl_logger()
RETURNS event_trigger
AS $$
BEGIN
    RAISE NOTICE 'Сработал событийный триггер: событие = %, команда = %', tg_event, tg_tag;
    INSERT INTO ddl_audit_log (event_type, command_tag, username, event_time)
    VALUES (tg_event, tg_tag, current_user, now());
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER ev_trg_ddl_logger
ON ddl_command_start
EXECUTE FUNCTION fn_ddl_logger();