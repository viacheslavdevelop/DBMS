-- =============================================================================
-- 10. Проверка серверных объектов (функция, процедура, курсоры, триггеры)
-- РГР по СУБД, вариант 17. База данных oil_depot_db (PostgreSQL)
-- =============================================================================
-- Все вызовы выполняются в одной транзакции и затем откатываются,
-- чтобы не изменять эталонный набор тестовых данных (127 записей).
-- =============================================================================

BEGIN;

-- 1. Пользовательская функция прогнозирования запасов
SELECT * FROM fn_forecast_tank_stock(9, 14::SMALLINT, 30);

-- 2. Курсор формирования плана дозаказа
SELECT * FROM fn_generate_reorder_plan(14::SMALLINT);

-- 3. Параметризованный курсор аудита нерешенных уведомлений
SELECT fn_audit_unclosed_alerts('РВС') AS alert_report;

-- 4. Хранимая процедура регистрации операции и пересчета прогноза
CALL sp_register_operation_and_forecast(
    'Расход', 1, 7, 11, 95.000, 0.7385, -8.50, 56800.00, 'ТТН-2026-121'
);

-- 5. Контроль результатов работы процедуры и триггеров
SELECT document_number, operation_type, tank_id, mass_tons
FROM stock_operations
WHERE document_number = 'ТТН-2026-121';

SELECT tank_id, forecast_date, horizon_days,
       avg_daily_demand_tons, predicted_end_stock_tons,
       reorder_point_tons, recommended_order_tons, risk_level
FROM stock_forecasts
WHERE tank_id = 1
  AND forecast_date = CURRENT_DATE
  AND horizon_days = 14;

SELECT tank_code, current_stock_tons
FROM storage_tanks
WHERE tank_id = 1;

ROLLBACK;
