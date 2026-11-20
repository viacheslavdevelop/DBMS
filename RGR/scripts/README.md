# Скрипты развертывания БД oil_depot_db

РГР по СУБД, вариант 17: учет и прогнозирование запасов нефтепродуктов нефтебазы.
Целевая СУБД — PostgreSQL 16+ (проверено на PostgreSQL 18.6).

Исходный монолитный скрипт `../oil_depot_db_postgresql-v2.sql` разделен на части
в порядке, соответствующем разделам пояснительной записки и приложению А.
Содержимое сверено с `../RGR_SUBD_Variant17_PostgreSQL.docx`: все 7 таблиц,
8 индексов, 127 тестовых записей, 2 материализованных представления, функция,
процедура, 2 курсора, 2 триггера и 23 запроса присутствуют.

## Состав

| Файл | Содержание |
| :--- | :--- |
| `00_create_database.sql` | Удаление (если есть) и создание базы `oil_depot_db` |
| `01_schema.sql` | DDL: 7 таблиц, первичные/внешние ключи, CHECK/UNIQUE-ограничения |
| `02_indexes.sql` | 8 дополнительных индексов (составные и частичные) |
| `03_seed_data.sql` | Наполнение 127 записями (до создания триггеров) |
| `04_materialized_views.sql` | `mv_tank_inventory_summary`, `mv_monthly_fuel_turnover` |
| `05_function_forecast.sql` | `fn_forecast_tank_stock` |
| `06_procedure_register_operation.sql` | `sp_register_operation_and_forecast` |
| `07_cursors.sql` | `fn_generate_reorder_plan`, `fn_audit_unclosed_alerts` |
| `08_triggers.sql` | `trg_validate_and_update_stock`, `trg_monitor_stock_threshold` |
| `09_queries.sql` | 23 аналитических запроса (разделы 5.1–5.6) |
| `10_test_server_objects.sql` | Вызовы функции, процедуры и курсоров в транзакции с ROLLBACK |
| `11_verify.sql` | Проверка количества записей и наличия объектов БД |
| `run_all.sh` | Последовательный запуск всех скриптов с записью логов |

## Запуск

```bash
cd scripts
chmod +x run_all.sh
./run_all.sh
```

Или вручную:

```bash
psql -d postgres -f 00_create_database.sql
psql -v ON_ERROR_STOP=1 -d oil_depot_db -f 01_schema.sql
# ... далее по порядку до 11_verify.sql
```

## Примечания

- `00_create_database.sql` пересоздает базу `oil_depot_db` (используется
  `DROP DATABASE IF EXISTS ... WITH (FORCE)`); существующие данные этой базы
  будут потеряны. Другие базы не затрагиваются.
- Скрипт `03_seed_data.sql` должен выполняться строго до `08_triggers.sql`:
  тестовые остатки уже заложены в `storage_tanks`, а триггеры пересчета
  остатков при наполнении не должны срабатывать.
- `10_test_server_objects.sql` выполняет вызовы в транзакции и завершает ее
  `ROLLBACK`, поэтому эталонные 127 записей остаются неизменными.
- Логи каждого запуска сохраняются в `scripts/logs/`.
