-- =============================================================================
-- 04. Материализованные представления
-- РГР по СУБД, вариант 17. База данных oil_depot_db (PostgreSQL)
-- =============================================================================

-- 4. МАТЕРИАЛИЗОВАННЫЕ ПРЕДСТАВЛЕНИЯ

CREATE MATERIALIZED VIEW mv_tank_inventory_summary AS
SELECT t.tank_id,
       t.tank_code,
       f.fuel_code,
       f.fuel_name,
       f.category,
       t.status,
       t.current_stock_tons,
       t.min_reserve_tons,
       ROUND((t.current_stock_tons / (t.max_capacity_m3 * f.std_density)) * 100.0, 2) AS fill_pct,
       ROUND(t.current_stock_tons * f.wholesale_price, 2) AS stock_value_rub,
       sf.avg_daily_demand_tons,
       sf.predicted_end_stock_tons,
       sf.recommended_order_tons,
       sf.risk_level,
       f.wholesale_price
FROM storage_tanks t
JOIN fuel_types f ON f.fuel_id = t.fuel_id
LEFT JOIN LATERAL (
    SELECT avg_daily_demand_tons, predicted_end_stock_tons,
           recommended_order_tons, risk_level
    FROM stock_forecasts
    WHERE tank_id = t.tank_id AND horizon_days = 14
    ORDER BY forecast_date DESC
    LIMIT 1
) sf ON TRUE;

CREATE UNIQUE INDEX uq_mv_tank_inv_id ON mv_tank_inventory_summary (tank_id);
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tank_inventory_summary;

CREATE MATERIALIZED VIEW mv_monthly_fuel_turnover AS
SELECT DATE_TRUNC('month', o.operation_date)::DATE AS turnover_month,
       f.category,
       f.fuel_code,
       ROUND(SUM(CASE WHEN o.operation_type = 'Приход' THEN o.mass_tons ELSE 0 END), 3) AS inflow_tons,
       ROUND(SUM(CASE WHEN o.operation_type = 'Расход' THEN o.mass_tons ELSE 0 END), 3) AS outflow_tons,
       ROUND(SUM(CASE WHEN o.operation_type = 'Списание' THEN o.mass_tons ELSE 0 END), 3) AS writeoff_tons,
       ROUND(SUM(CASE WHEN o.operation_type = 'Расход'
                      THEN o.mass_tons * o.unit_price ELSE 0 END), 2) AS sales_revenue_rub
FROM stock_operations o
JOIN storage_tanks t ON t.tank_id = o.tank_id
JOIN fuel_types f ON f.fuel_id = t.fuel_id
GROUP BY DATE_TRUNC('month', o.operation_date)::DATE, f.category, f.fuel_code
ORDER BY turnover_month DESC, sales_revenue_rub DESC;

CREATE UNIQUE INDEX uq_mv_monthly_turn
    ON mv_monthly_fuel_turnover (turnover_month, fuel_code);
