#!/usr/bin/env bash
# =============================================================================
# Последовательный запуск всех SQL-скриптов РГР (вариант 17) в PostgreSQL.
# Использование: ./run_all.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
DB_NAME="oil_depot_db"

mkdir -p "$LOG_DIR"

run_sql() {
    local db="$1"
    local file="$2"
    local base
    base="$(basename "$file" .sql)"

    echo "==> ${base}.sql (база: ${db})"
    psql -X -v ON_ERROR_STOP=1 -d "$db" -f "$SCRIPT_DIR/$file" \
        2>&1 | tee "$LOG_DIR/${base}.log"
}

# 00 — создание базы данных (подключение к служебной базе postgres)
run_sql postgres 00_create_database.sql

# 01–11 — последовательное развертывание и проверка в oil_depot_db
for file in \
    01_schema.sql \
    02_indexes.sql \
    03_seed_data.sql \
    04_materialized_views.sql \
    05_function_forecast.sql \
    06_procedure_register_operation.sql \
    07_cursors.sql \
    08_triggers.sql \
    09_queries.sql \
    10_test_server_objects.sql \
    11_verify.sql
do
    run_sql "$DB_NAME" "$file"
done

echo
echo "Все скрипты выполнены успешно. Логи: $LOG_DIR"
