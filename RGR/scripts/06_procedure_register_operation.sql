-- =============================================================================
-- 06. Хранимая процедура регистрации операции и пересчета прогноза
-- РГР по СУБД, вариант 17. База данных oil_depot_db (PostgreSQL)
-- =============================================================================

-- 6. ХРАНИМАЯ ПРОЦЕДУРА РЕГИСТРАЦИИ ОПЕРАЦИИ И ПЕРЕСЧЕТА ПРОГНОЗА

CREATE OR REPLACE PROCEDURE sp_register_operation_and_forecast(
    p_operation_type   VARCHAR(20),
    p_tank_id          INTEGER,
    p_counterparty_id  INTEGER,
    p_employee_id      INTEGER,
    p_volume_m3        NUMERIC(10, 3),
    p_measured_density NUMERIC(6, 4),
    p_measured_temp_c  NUMERIC(5, 2),
    p_unit_price       NUMERIC(12, 2),
    p_document_number  VARCHAR(40)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_mass NUMERIC(10, 3);
    v_fc   RECORD;
BEGIN
    v_mass := ROUND(p_volume_m3 * p_measured_density, 3);

    INSERT INTO stock_operations (
        operation_type, tank_id, counterparty_id, employee_id,
        volume_m3, measured_density, measured_temp_c, mass_tons,
        unit_price, document_number
    ) VALUES (
        p_operation_type, p_tank_id, p_counterparty_id, p_employee_id,
        p_volume_m3, p_measured_density, p_measured_temp_c, v_mass,
        p_unit_price, p_document_number
    );

    SELECT * INTO v_fc FROM fn_forecast_tank_stock(p_tank_id, 14::SMALLINT, 30);

    INSERT INTO stock_forecasts (
        tank_id, forecast_date, horizon_days, avg_daily_demand_tons,
        predicted_end_stock_tons, reorder_point_tons,
        recommended_order_tons, risk_level, created_by
    ) VALUES (
        p_tank_id, CURRENT_DATE, 14, v_fc.avg_daily_demand,
        v_fc.predicted_stock, v_fc.reorder_point,
        v_fc.recommended_order, v_fc.risk_level, p_employee_id
    )
    ON CONFLICT (tank_id, forecast_date, horizon_days)
    DO UPDATE SET
        avg_daily_demand_tons    = EXCLUDED.avg_daily_demand_tons,
        predicted_end_stock_tons = EXCLUDED.predicted_end_stock_tons,
        reorder_point_tons       = EXCLUDED.reorder_point_tons,
        recommended_order_tons   = EXCLUDED.recommended_order_tons,
        risk_level               = EXCLUDED.risk_level,
        created_by               = EXCLUDED.created_by;
END;
$$;
