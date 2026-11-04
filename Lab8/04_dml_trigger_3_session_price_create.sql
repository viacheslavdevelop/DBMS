CREATE OR REPLACE FUNCTION fn_check_session_price()
RETURNS trigger
AS $$
BEGIN
    RAISE NOTICE 'Контекст триггера: % | Операция: % | Таблица: %.% | Время: % | Уровень: %',
        TG_NAME, TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_WHEN, TG_LEVEL;

    IF NEW.base_price < 150.00 THEN
        RAISE EXCEPTION 'Некорректная базовая цена сеанса (% руб.). Минимальная допустимая цена составляет 150.00 руб.', NEW.base_price;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_session_price
BEFORE INSERT OR UPDATE ON Sessions
FOR EACH ROW
EXECUTE FUNCTION fn_check_session_price();