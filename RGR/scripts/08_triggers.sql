-- =============================================================================
-- 08. Триггеры контроля остатков и автоматического оповещения
-- РГР по СУБД, вариант 17. База данных oil_depot_db (PostgreSQL)
-- =============================================================================

-- 8. ТРИГГЕРЫ КОНТРОЛЯ ОСТАТКОВ И АВТОМАТИЧЕСКОГО ОПОВЕЩЕНИЯ

CREATE OR REPLACE FUNCTION fn_trg_validate_and_update_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status    VARCHAR(20);
    v_cur_stock NUMERIC(10, 3);
    v_max_mass  NUMERIC(10, 3);
BEGIN
    SELECT t.status, t.current_stock_tons,
           ROUND(t.max_capacity_m3 * f.std_density, 3)
    INTO v_status, v_cur_stock, v_max_mass
    FROM storage_tanks t
    JOIN fuel_types f ON f.fuel_id = t.fuel_id
    WHERE t.tank_id = NEW.tank_id
    FOR UPDATE;

    IF v_status <> 'Активен' THEN
        RAISE EXCEPTION 'Операция запрещена: резервуар ID=% имеет статус %', NEW.tank_id, v_status;
    END IF;

    NEW.mass_tons := ROUND(NEW.volume_m3 * NEW.measured_density, 3);

    IF NEW.operation_type = 'Приход' THEN
        IF v_cur_stock + NEW.mass_tons > v_max_mass THEN
            RAISE EXCEPTION 'Превышена вместимость резервуара ID=% (макс. % т)', NEW.tank_id, v_max_mass;
        END IF;
        UPDATE storage_tanks
        SET current_stock_tons = current_stock_tons + NEW.mass_tons
        WHERE tank_id = NEW.tank_id;
    ELSE
        IF v_cur_stock < NEW.mass_tons THEN
            RAISE EXCEPTION 'Недостаточно топлива в резервуаре ID=% (остаток % т)', NEW.tank_id, v_cur_stock;
        END IF;
        UPDATE storage_tanks
        SET current_stock_tons = current_stock_tons - NEW.mass_tons
        WHERE tank_id = NEW.tank_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_and_update_stock
BEFORE INSERT ON stock_operations
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validate_and_update_stock();

CREATE OR REPLACE FUNCTION fn_trg_monitor_stock_threshold()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'Активен' AND NEW.current_stock_tons < NEW.min_reserve_tons THEN
        INSERT INTO stock_alerts (tank_id, alert_type, message)
        VALUES (
            NEW.tank_id,
            'Ниже минимума',
            FORMAT('Остаток в %s (%s т) ниже страхового запаса (%s т).',
                   NEW.tank_code, NEW.current_stock_tons, NEW.min_reserve_tons)
        );
    ELSIF NEW.current_stock_tons >= NEW.min_reserve_tons
      AND OLD.current_stock_tons < OLD.min_reserve_tons THEN
        UPDATE stock_alerts
        SET is_resolved = TRUE
        WHERE tank_id = NEW.tank_id
          AND alert_type = 'Ниже минимума'
          AND is_resolved = FALSE;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_monitor_stock_threshold
AFTER UPDATE OF current_stock_tons ON storage_tanks
FOR EACH ROW
EXECUTE FUNCTION fn_trg_monitor_stock_threshold();
