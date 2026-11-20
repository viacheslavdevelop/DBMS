-- =============================================================================
-- 05. Пользовательская функция прогнозирования
-- РГР по СУБД, вариант 17. База данных oil_depot_db (PostgreSQL)
-- =============================================================================

-- 5. ПОЛЬЗОВАТЕЛЬСКАЯ ФУНКЦИЯ ПРОГНОЗИРОВАНИЯ

CREATE OR REPLACE FUNCTION fn_forecast_tank_stock(
    p_tank_id       INTEGER,
    p_horizon_days  SMALLINT,
    p_lookback_days INTEGER DEFAULT 30
)
RETURNS TABLE (
    avg_daily_demand   NUMERIC(10, 3),
    predicted_stock    NUMERIC(10, 3),
    reorder_point      NUMERIC(10, 3),
    recommended_order  NUMERIC(10, 3),
    risk_level         VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cur_stock     NUMERIC(10, 3);
    v_min_reserve   NUMERIC(10, 3);
    v_max_mass      NUMERIC(10, 3);
    v_avg_lead      NUMERIC(6, 2);
    v_total_outflow NUMERIC(12, 3);
BEGIN
    SELECT t.current_stock_tons, t.min_reserve_tons,
           ROUND(t.max_capacity_m3 * f.std_density, 3)
    INTO v_cur_stock, v_min_reserve, v_max_mass
    FROM storage_tanks t
    JOIN fuel_types f ON f.fuel_id = t.fuel_id
    WHERE t.tank_id = p_tank_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Резервуар с ID=% не найден', p_tank_id;
    END IF;

    SELECT COALESCE(SUM(mass_tons), 0)
    INTO v_total_outflow
    FROM stock_operations
    WHERE tank_id = p_tank_id
      AND operation_type = 'Расход'
      AND operation_date >= CURRENT_TIMESTAMP - make_interval(days => p_lookback_days);

    SELECT COALESCE(AVG(lead_time_days), 3)
    INTO v_avg_lead
    FROM counterparties
    WHERE cp_type = 'Поставщик' AND is_active = TRUE;

    avg_daily_demand := ROUND(v_total_outflow / GREATEST(p_lookback_days, 1), 3);
    predicted_stock  := ROUND(v_cur_stock - avg_daily_demand * p_horizon_days, 3);
    reorder_point    := ROUND(avg_daily_demand * v_avg_lead + v_min_reserve, 3);

    IF predicted_stock < v_min_reserve THEN
        recommended_order := ROUND(
            LEAST(v_max_mass * 0.90 - v_cur_stock,
                  (v_min_reserve - predicted_stock) + avg_daily_demand * v_avg_lead), 3);
        recommended_order := GREATEST(recommended_order, 0.000);
    ELSE
        recommended_order := 0.000;
    END IF;

    IF predicted_stock < 0 THEN
        risk_level := 'Критический';
    ELSIF predicted_stock < v_min_reserve THEN
        risk_level := 'Высокий';
    ELSIF v_cur_stock <= reorder_point THEN
        risk_level := 'Средний';
    ELSE
        risk_level := 'Низкий';
    END IF;

    RETURN NEXT;
END;
$$;
