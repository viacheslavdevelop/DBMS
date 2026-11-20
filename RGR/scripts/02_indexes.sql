-- =============================================================================
-- 02. Создание индексов
-- РГР по СУБД, вариант 17. База данных oil_depot_db (PostgreSQL)
-- =============================================================================

-- 2. СОЗДАНИЕ ИНДЕКСОВ

-- DDL-скрипт создания индексов
CREATE INDEX idx_tanks_fuel_id ON storage_tanks (fuel_id);
CREATE INDEX idx_tanks_active_stock ON storage_tanks (current_stock_tons)
    WHERE status = 'Активен';
CREATE INDEX idx_ops_tank_date ON stock_operations (tank_id, operation_date DESC);
CREATE INDEX idx_ops_type_date ON stock_operations (operation_type, operation_date DESC);
CREATE INDEX idx_ops_counterparty_id ON stock_operations (counterparty_id)
    WHERE counterparty_id IS NOT NULL;
CREATE INDEX idx_forecasts_tank_hor ON stock_forecasts (tank_id, horizon_days, forecast_date DESC);
CREATE INDEX idx_forecasts_high_risk ON stock_forecasts (risk_level, predicted_end_stock_tons)
    WHERE risk_level IN ('Высокий', 'Критический');
CREATE INDEX idx_alerts_unresolved ON stock_alerts (tank_id, alert_time DESC)
    WHERE is_resolved = FALSE;
