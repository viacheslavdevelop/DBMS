-- =============================================================================
-- 11. Проверка результатов развертывания базы данных
-- РГР по СУБД, вариант 17. База данных oil_depot_db (PostgreSQL)
-- =============================================================================

-- Количество записей в таблицах (всего должно быть 127)
WITH counts AS (
    SELECT 'fuel_types' AS table_name, COUNT(*) AS row_count FROM fuel_types
    UNION ALL SELECT 'storage_tanks', COUNT(*) FROM storage_tanks
    UNION ALL SELECT 'counterparties', COUNT(*) FROM counterparties
    UNION ALL SELECT 'employees', COUNT(*) FROM employees
    UNION ALL SELECT 'stock_operations', COUNT(*) FROM stock_operations
    UNION ALL SELECT 'stock_forecasts', COUNT(*) FROM stock_forecasts
    UNION ALL SELECT 'stock_alerts', COUNT(*) FROM stock_alerts
)
SELECT table_name, row_count FROM counts
UNION ALL
SELECT 'ИТОГО', SUM(row_count) FROM counts
ORDER BY table_name;

-- Материализованные представления и их наполнение
SELECT matviewname, ispopulated
FROM pg_matviews
WHERE schemaname = 'public'
ORDER BY matviewname;

SELECT 'mv_tank_inventory_summary' AS matview, COUNT(*) AS row_count
FROM mv_tank_inventory_summary
UNION ALL
SELECT 'mv_monthly_fuel_turnover', COUNT(*) FROM mv_monthly_fuel_turnover;

-- Функции и процедуры
SELECT p.proname,
       CASE p.prokind WHEN 'f' THEN 'function' WHEN 'p' THEN 'procedure' END AS kind
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'fn_forecast_tank_stock',
      'sp_register_operation_and_forecast',
      'fn_generate_reorder_plan',
      'fn_audit_unclosed_alerts',
      'fn_trg_validate_and_update_stock',
      'fn_trg_monitor_stock_threshold'
  )
ORDER BY p.proname;

-- Пользовательские триггеры
SELECT tgname
FROM pg_trigger
WHERE NOT tgisinternal
ORDER BY tgname;

-- Дополнительные индексы (созданные в скрипте 02 и индексы материализованных представлений)
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND (indexname LIKE 'idx_%' OR indexname LIKE 'uq_mv_%')
ORDER BY indexname;
