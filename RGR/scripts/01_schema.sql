-- =============================================================================
-- 01. Создание таблиц (DDL)
-- РГР по СУБД, вариант 17. База данных oil_depot_db (PostgreSQL)
-- =============================================================================

-- 1. СОЗДАНИЕ ТАБЛИЦ (DDL)

-- DDL-скрипт создания базы данных учета и прогноза запасов нефтепродуктов
CREATE TABLE fuel_types (
    fuel_id           SERIAL PRIMARY KEY,
    fuel_code         VARCHAR(20) NOT NULL UNIQUE,
    fuel_name         VARCHAR(120) NOT NULL,
    category          VARCHAR(40) NOT NULL
        CHECK (category IN ('Бензин', 'Дизельное топливо', 'Авиатопливо', 'Мазут', 'Спецтопливо')),
    eco_class         VARCHAR(10) NOT NULL DEFAULT 'К5'
        CHECK (eco_class IN ('К3', 'К4', 'К5', 'Нет')),
    std_density       NUMERIC(6, 4) NOT NULL
        CHECK (std_density > 0.5000 AND std_density < 1.2000),
    wholesale_price   NUMERIC(12, 2) NOT NULL CHECK (wholesale_price > 0),
    shelf_life_months SMALLINT NOT NULL CHECK (shelf_life_months > 0)
);

CREATE TABLE storage_tanks (
    tank_id               SERIAL PRIMARY KEY,
    tank_code             VARCHAR(20) NOT NULL UNIQUE,
    fuel_id               INTEGER NOT NULL
        REFERENCES fuel_types(fuel_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    tank_type             VARCHAR(30) NOT NULL CHECK (tank_type IN ('РВС', 'РГС', 'РВСП')),
    max_capacity_m3       NUMERIC(10, 3) NOT NULL CHECK (max_capacity_m3 > 0),
    min_reserve_tons      NUMERIC(10, 3) NOT NULL CHECK (min_reserve_tons >= 0),
    current_stock_tons    NUMERIC(10, 3) NOT NULL DEFAULT 0.000
        CHECK (current_stock_tons >= 0),
    status                VARCHAR(20) NOT NULL DEFAULT 'Активен'
        CHECK (status IN ('Активен', 'Ремонт', 'Зачистка', 'Консервация')),
    last_calibration_date DATE NOT NULL
);

CREATE TABLE counterparties (
    counterparty_id SERIAL PRIMARY KEY,
    company_name    VARCHAR(150) NOT NULL,
    inn             CHAR(10) NOT NULL UNIQUE CHECK (inn ~ '^[0-9]{10}$'),
    cp_type         VARCHAR(20) NOT NULL CHECK (cp_type IN ('Поставщик', 'Покупатель')),
    region          VARCHAR(80) NOT NULL,
    contact_phone   VARCHAR(25) NOT NULL,
    lead_time_days  SMALLINT NOT NULL DEFAULT 3 CHECK (lead_time_days BETWEEN 1 AND 60),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE employees (
    employee_id  SERIAL PRIMARY KEY,
    full_name    VARCHAR(120) NOT NULL,
    position     VARCHAR(80) NOT NULL,
    shift_number SMALLINT NOT NULL CHECK (shift_number BETWEEN 1 AND 4),
    hire_date    DATE NOT NULL,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE stock_operations (
    operation_id     BIGSERIAL PRIMARY KEY,
    operation_date   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    operation_type   VARCHAR(20) NOT NULL CHECK (operation_type IN ('Приход', 'Расход', 'Списание')),
    tank_id          INTEGER NOT NULL
        REFERENCES storage_tanks(tank_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    counterparty_id  INTEGER
        REFERENCES counterparties(counterparty_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    employee_id      INTEGER NOT NULL
        REFERENCES employees(employee_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    volume_m3        NUMERIC(10, 3) NOT NULL CHECK (volume_m3 > 0),
    measured_density NUMERIC(6, 4) NOT NULL
        CHECK (measured_density > 0.5000 AND measured_density < 1.2000),
    measured_temp_c  NUMERIC(5, 2) NOT NULL CHECK (measured_temp_c BETWEEN -50.00 AND 80.00),
    mass_tons        NUMERIC(10, 3) NOT NULL CHECK (mass_tons > 0),
    unit_price       NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    document_number  VARCHAR(40) NOT NULL UNIQUE,
    CONSTRAINT chk_op_counterparty CHECK (
        (operation_type = 'Списание' AND counterparty_id IS NULL)
        OR (operation_type IN ('Приход', 'Расход') AND counterparty_id IS NOT NULL)
    )
);

CREATE TABLE stock_forecasts (
    forecast_id              SERIAL PRIMARY KEY,
    tank_id                  INTEGER NOT NULL
        REFERENCES storage_tanks(tank_id) ON UPDATE CASCADE ON DELETE CASCADE,
    forecast_date            DATE NOT NULL DEFAULT CURRENT_DATE,
    horizon_days             SMALLINT NOT NULL CHECK (horizon_days BETWEEN 1 AND 90),
    avg_daily_demand_tons    NUMERIC(10, 3) NOT NULL CHECK (avg_daily_demand_tons >= 0),
    predicted_end_stock_tons NUMERIC(10, 3) NOT NULL,
    reorder_point_tons       NUMERIC(10, 3) NOT NULL CHECK (reorder_point_tons >= 0),
    recommended_order_tons   NUMERIC(10, 3) NOT NULL DEFAULT 0.000
        CHECK (recommended_order_tons >= 0),
    risk_level               VARCHAR(20) NOT NULL
        CHECK (risk_level IN ('Низкий', 'Средний', 'Высокий', 'Критический')),
    created_by               INTEGER NOT NULL
        REFERENCES employees(employee_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_forecast_tank_date_hor UNIQUE (tank_id, forecast_date, horizon_days)
);

CREATE TABLE stock_alerts (
    alert_id    BIGSERIAL PRIMARY KEY,
    tank_id     INTEGER NOT NULL
        REFERENCES storage_tanks(tank_id) ON UPDATE CASCADE ON DELETE CASCADE,
    alert_time  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    alert_type  VARCHAR(30) NOT NULL
        CHECK (alert_type IN ('Ниже минимума', 'Дефицит по прогнозу', 'Переполнение', 'Просрочка калибровки')),
    message     TEXT NOT NULL,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE
);
