-- =============================================================================
-- 07. Курсоры (функции с курсорами)
-- РГР по СУБД, вариант 17. База данных oil_depot_db (PostgreSQL)
-- =============================================================================

-- 7. КУРСОРЫ

CREATE OR REPLACE FUNCTION fn_generate_reorder_plan(p_horizon_days SMALLINT DEFAULT 14)
RETURNS TABLE (
    tank_code       VARCHAR(20),
    fuel_code       VARCHAR(20),
    current_tons    NUMERIC(10, 3),
    order_tons      NUMERIC(10, 3),
    estimated_cost  NUMERIC(14, 2),
    risk_level      VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    cur_tanks CURSOR FOR
        SELECT t.tank_id, t.tank_code, f.fuel_code,
               t.current_stock_tons, f.wholesale_price
        FROM storage_tanks t
        JOIN fuel_types f ON f.fuel_id = t.fuel_id
        WHERE t.status = 'Активен'
        ORDER BY t.tank_code;
    rec_tank RECORD;
    rec_fc   RECORD;
BEGIN
    OPEN cur_tanks;
    LOOP
        FETCH cur_tanks INTO rec_tank;
        EXIT WHEN NOT FOUND;

        SELECT * INTO rec_fc
        FROM fn_forecast_tank_stock(rec_tank.tank_id, p_horizon_days, 30);

        IF rec_fc.recommended_order > 0 THEN
            tank_code      := rec_tank.tank_code;
            fuel_code      := rec_tank.fuel_code;
            current_tons   := rec_tank.current_stock_tons;
            order_tons     := rec_fc.recommended_order;
            estimated_cost := ROUND(rec_fc.recommended_order * rec_tank.wholesale_price, 2);
            risk_level     := rec_fc.risk_level;
            RETURN NEXT;
        END IF;
    END LOOP;
    CLOSE cur_tanks;
END;
$$;

CREATE OR REPLACE FUNCTION fn_audit_unclosed_alerts(p_tank_type VARCHAR(30))
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    cur_alerts CURSOR (v_type VARCHAR) FOR
        SELECT t.tank_code, a.alert_time, a.alert_type, a.message
        FROM stock_alerts a
        JOIN storage_tanks t ON t.tank_id = a.tank_id
        WHERE a.is_resolved = FALSE
          AND t.tank_type = v_type
        ORDER BY a.alert_time DESC;
    rec_a    RECORD;
    v_report TEXT := '';
    v_cnt    INTEGER := 0;
BEGIN
    OPEN cur_alerts(p_tank_type);
    LOOP
        FETCH cur_alerts INTO rec_a;
        EXIT WHEN NOT FOUND;
        v_cnt := v_cnt + 1;
        v_report := v_report || FORMAT(
            '%s) [%s] %s (%s): %s' || E'\n',
            v_cnt, TO_CHAR(rec_a.alert_time, 'DD.MM.YYYY HH24:MI'),
            rec_a.tank_code, rec_a.alert_type, rec_a.message
        );
    END LOOP;
    CLOSE cur_alerts;

    IF v_cnt = 0 THEN
        RETURN 'Активные инциденты для резервуаров типа ' || p_tank_type || ' отсутствуют.';
    END IF;
    RETURN v_report;
END;
$$;
