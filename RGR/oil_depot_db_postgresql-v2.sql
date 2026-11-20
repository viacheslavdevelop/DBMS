-- =============================================================================

-- РГР по СУБД (Вариант 17): База данных учета и прогнозирования запасов

-- нефтепродуктов нефтебазы (oil_depot_db) — PostgreSQL 16

-- Полный исполняемый скрипт: DDL, индексы, наполнение (127 записей),

-- материализованные представления, функции, процедура, курсоры, триггеры

-- и 23 аналитических SQL-запроса.

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


-- 3. НАПОЛНЕНИЕ ТАБЛИЦ ТЕСТОВЫМИ ДАННЫМИ (127 ЗАПИСЕЙ, ДО АКТИВАЦИИ ТРИГГЕРОВ)

-- DML-скрипт наполнения таблиц базы данных oil_depot_db (127 записей)
-- Примечание: наполнение выполняется до активации триггеров пересчета остатков

INSERT INTO fuel_types (fuel_code, fuel_name, category, eco_class, std_density, wholesale_price, shelf_life_months) VALUES
('AI-92-K5', 'Бензин автомобильный АИ-92-К5', 'Бензин', 'К5', 0.7350, 56800.00, 12),
('AI-95-K5', 'Бензин автомобильный АИ-95-К5', 'Бензин', 'К5', 0.7450, 61200.00, 12),
('AI-98-K5', 'Бензин автомобильный АИ-98-К5', 'Бензин', 'К5', 0.7520, 68500.00, 12),
('AI-100-K5', 'Бензин автомобильный АИ-100-К5', 'Бензин', 'К5', 0.7560, 74200.00, 12),
('DT-L-K5', 'Топливо дизельное летнее ДТ-Л-К5', 'Дизельное топливо', 'К5', 0.8350, 60400.00, 12),
('DT-E-K5', 'Топливо дизельное межсезонное ДТ-Е-К5', 'Дизельное топливо', 'К5', 0.8300, 63100.00, 12),
('DT-Z-K5', 'Топливо дизельное зимнее ДТ-З-К5', 'Дизельное топливо', 'К5', 0.8220, 67800.00, 12),
('DT-A-K5', 'Топливо дизельное арктическое ДТ-А-К5', 'Дизельное топливо', 'К5', 0.8150, 75600.00, 12),
('TS-1', 'Топливо для реактивных двигателей ТС-1', 'Авиатопливо', 'К5', 0.7800, 72500.00, 24),
('RT-AV', 'Топливо авиационное РТ', 'Авиатопливо', 'К5', 0.7850, 76900.00, 24),
('M-100', 'Мазут топочный М-100 малосернистый', 'Мазут', 'Нет', 0.9650, 31400.00, 36),
('M-40', 'Мазут топочный М-40', 'Мазут', 'Нет', 0.9450, 34200.00, 36),
('SMT-1', 'Топливо судовое маловязкое СМТ', 'Спецтопливо', 'К4', 0.8550, 52900.00, 18),
('NEFRAS-S2', 'Нефрас С2-80/120 технический', 'Спецтопливо', 'Нет', 0.7000, 81000.00, 24),
('AI-92-K4', 'Бензин автомобильный АИ-92-К4 (резерв)', 'Бензин', 'К4', 0.7340, 53200.00, 12);

INSERT INTO storage_tanks (tank_code, fuel_id, tank_type, max_capacity_m3, min_reserve_tons, current_stock_tons, status, last_calibration_date) VALUES
('РВС-01', 1, 'РВС', 2000.000, 250.000, 1120.500, 'Активен', '2025-06-15'),
('РВС-02', 1, 'РВС', 2000.000, 250.000, 210.400, 'Активен', '2025-06-15'),
('РВС-03', 2, 'РВСП', 3000.000, 350.000, 1680.250, 'Активен', '2025-08-20'),
('РВС-04', 2, 'РВСП', 2000.000, 280.000, 245.800, 'Активен', '2025-08-20'),
('РВС-05', 3, 'РВСП', 1000.000, 120.000, 485.600, 'Активен', '2025-09-10'),
('РВС-06', 4, 'РГС', 500.000, 80.000, 290.150, 'Активен', '2025-10-01'),
('РВС-07', 5, 'РВС', 3000.000, 400.000, 1850.000, 'Активен', '2025-05-12'),
('РВС-08', 6, 'РВС', 2500.000, 300.000, 940.750, 'Активен', '2025-05-12'),
('РВС-09', 7, 'РВС', 3000.000, 450.000, 390.200, 'Активен', '2025-07-04'),
('РВС-10', 8, 'РВС', 1500.000, 200.000, 720.400, 'Активен', '2025-07-04'),
('РВС-11', 9, 'РВСП', 2000.000, 300.000, 1240.000, 'Активен', '2025-04-18'),
('РВС-12', 10, 'РВСП', 1000.000, 150.000, 130.500, 'Активен', '2025-04-18'),
('РВС-13', 11, 'РВС', 5000.000, 600.000, 3120.000, 'Активен', '2024-11-22'),
('РВС-14', 12, 'РВС', 2000.000, 250.000, 0.000, 'Ремонт', '2024-09-10'),
('РВС-15', 13, 'РГС', 800.000, 100.000, 415.300, 'Активен', '2025-03-14'),
('РВС-16', 14, 'РГС', 400.000, 50.000, 0.000, 'Зачистка', '2025-02-28');

INSERT INTO counterparties (company_name, inn, cp_type, region, contact_phone, lead_time_days, is_active) VALUES
('АО «Газпромнефть-ОНПЗ»', '5501041234', 'Поставщик', 'Омская область', '+7 (3812) 69-01-10', 2, TRUE),
('ООО «ЛУКОЙЛ-Пермнефтеоргсинтез»', '5905000123', 'Поставщик', 'Пермский край', '+7 (342) 220-14-50', 5, TRUE),
('АО «Антипинский НПЗ»', '7204084412', 'Поставщик', 'Тюменская область', '+7 (3452) 54-22-11', 3, TRUE),
('ООО «КИНЕФ»', '4708007120', 'Поставщик', 'Ленинградская область', '+7 (81368) 9-20-00', 7, TRUE),
('АО «Ачинский НПЗ ВНК»', '2443001980', 'Поставщик', 'Красноярский край', '+7 (39151) 5-33-40', 4, TRUE),
('ПАО «АНК Башнефть»', '0274051582', 'Поставщик', 'Республика Башкортостан', '+7 (347) 261-61-61', 5, TRUE),
('ООО «СибТопливо Сеть АЗС»', '5503112233', 'Покупатель', 'Омская область', '+7 (3812) 45-67-89', 1, TRUE),
('ООО «ОмскТрансНефть»', '5504223344', 'Покупатель', 'Омская область', '+7 (3812) 32-18-90', 1, TRUE),
('АО «НовосибАЗС-Сервис»', '5406334455', 'Покупатель', 'Новосибирская область', '+7 (383) 211-45-12', 2, TRUE),
('ООО «АгроСнаб-Сибирь»', '5507445566', 'Покупатель', 'Омская область', '+7 (3812) 55-12-30', 2, TRUE),
('ООО «ТюменьАвтоЛогистика»', '7202556677', 'Покупатель', 'Тюменская область', '+7 (3452) 40-11-22', 2, TRUE),
('АО «АвиаСервис Омск»', '5501667788', 'Покупатель', 'Омская область', '+7 (3812) 51-73-00', 1, TRUE),
('ООО «ТомскЭнергоТепло»', '7017778899', 'Покупатель', 'Томская область', '+7 (3822) 65-43-21', 3, TRUE),
('ООО «ЗапСибАЗС»', '5405889900', 'Покупатель', 'Новосибирская область', '+7 (383) 340-19-88', 2, TRUE),
('МУП «Пассажирское АТП-8»', '5506990011', 'Покупатель', 'Омская область', '+7 (3812) 77-88-10', 1, TRUE),
('ООО «СеверТрансОйл»', '8602110099', 'Покупатель', 'ХМАО-Югра', '+7 (3462) 50-10-10', 4, FALSE);

INSERT INTO employees (full_name, position, shift_number, hire_date, is_active) VALUES
('Соколов Андрей Викторович', 'Начальник нефтебазы', 1, '2018-03-12', TRUE),
('Морозова Елена Сергеевна', 'Ведущий аналитик запасов', 1, '2020-05-18', TRUE),
('Козлов Дмитрий Игоревич', 'Начальник смены', 1, '2019-07-01', TRUE),
('Волков Сергей Павлович', 'Начальник смены', 2, '2019-11-15', TRUE),
('Николаев Артем Олегович', 'Начальник смены', 3, '2021-02-10', TRUE),
('Федоров Михаил Андреевич', 'Начальник смены', 4, '2021-08-22', TRUE),
('Петрова Анна Владимировна', 'Оператор товарный 5 разряда', 1, '2022-01-14', TRUE),
('Иванов Максим Алексеевич', 'Оператор товарный 5 разряда', 2, '2022-04-05', TRUE),
('Смирнова Ольга Дмитриевна', 'Оператор товарный 4 разряда', 3, '2023-03-20', TRUE),
('Кузнецов Илья Николаевич', 'Оператор товарный 4 разряда', 4, '2023-06-11', TRUE),
('Лебедева Татьяна Юрьевна', 'Диспетчер отгрузки', 1, '2021-09-01', TRUE),
('Павлов Роман Евгеньевич', 'Диспетчер отгрузки', 2, '2022-10-17', TRUE),
('Семенов Виктор Петрович', 'Инженер-метролог', 1, '2017-12-04', TRUE),
('Васильева Мария Игоревна', 'Аналитик по планированию', 1, '2024-02-01', TRUE),
('Орлов Денис Станиславович', 'Оператор товарный 4 разряда', 3, '2022-07-19', FALSE);

INSERT INTO stock_operations (operation_date, operation_type, tank_id, counterparty_id, employee_id, volume_m3, measured_density, measured_temp_c, mass_tons, unit_price, document_number) VALUES
('2026-10-02 08:30:00', 'Приход', 1, 1, 7, 450.000, 0.7360, 12.50, 331.200, 56500.00, 'ЖДН-2026-001'),
('2026-10-04 10:15:00', 'Приход', 3, 2, 8, 520.000, 0.7460, 11.80, 387.920, 61000.00, 'ЖДН-2026-002'),
('2026-10-06 09:00:00', 'Приход', 7, 3, 9, 600.000, 0.8360, 10.20, 501.600, 60100.00, 'ЖДН-2026-003'),
('2026-10-08 14:20:00', 'Приход', 9, 5, 10, 480.000, 0.8230, 8.40, 395.040, 67500.00, 'ЖДН-2026-004'),
('2026-10-10 07:45:00', 'Приход', 11, 1, 7, 400.000, 0.7810, 9.00, 312.400, 72200.00, 'ЖДН-2026-005'),
('2026-10-12 11:30:00', 'Приход', 13, 6, 8, 700.000, 0.9640, 18.00, 674.800, 31200.00, 'ЖДН-2026-006'),
('2026-10-14 08:10:00', 'Приход', 8, 4, 9, 350.000, 0.8310, 7.50, 290.850, 62900.00, 'ЖДН-2026-007'),
('2026-10-16 15:00:00', 'Приход', 5, 2, 10, 220.000, 0.7530, 6.80, 165.660, 68300.00, 'ЖДН-2026-008'),
('2026-10-11 09:20:00', 'Расход', 1, 7, 11, 120.000, 0.7355, 10.00, 88.260, 56800.00, 'ТТН-2026-101'),
('2026-10-13 13:40:00', 'Расход', 1, 9, 12, 145.000, 0.7365, 9.20, 106.793, 56800.00, 'ТТН-2026-102'),
('2026-10-15 10:05:00', 'Расход', 2, 7, 11, 160.000, 0.7370, 8.10, 117.920, 56800.00, 'ТТН-2026-103'),
('2026-10-17 16:30:00', 'Расход', 3, 14, 12, 180.000, 0.7460, 7.40, 134.280, 61200.00, 'ТТН-2026-104'),
('2026-10-19 08:50:00', 'Расход', 4, 8, 11, 155.000, 0.7470, 6.20, 115.785, 61200.00, 'ТТН-2026-105'),
('2026-10-21 11:15:00', 'Расход', 7, 10, 12, 210.000, 0.8370, 5.50, 175.770, 60400.00, 'ТТН-2026-106'),
('2026-10-23 14:00:00', 'Расход', 9, 11, 11, 190.000, 0.8240, 2.30, 156.560, 67800.00, 'ТТН-2026-107'),
('2026-10-25 09:45:00', 'Расход', 9, 15, 12, 175.000, 0.8250, 1.10, 144.375, 67800.00, 'ТТН-2026-108'),
('2026-10-27 12:10:00', 'Расход', 11, 12, 11, 130.000, 0.7820, 0.50, 101.660, 72500.00, 'ТТН-2026-109'),
('2026-10-29 15:25:00', 'Расход', 12, 12, 12, 95.000, 0.7860, -1.20, 74.670, 76900.00, 'ТТН-2026-110'),
('2026-10-31 10:30:00', 'Расход', 13, 13, 11, 240.000, 0.9660, 16.50, 231.840, 31400.00, 'ТТН-2026-111'),
('2026-11-02 08:40:00', 'Расход', 1, 7, 11, 135.000, 0.7380, -2.40, 99.630, 56800.00, 'ТТН-2026-112'),
('2026-11-04 11:00:00', 'Расход', 2, 9, 12, 150.000, 0.7385, -3.10, 110.775, 56800.00, 'ТТН-2026-113'),
('2026-11-06 13:20:00', 'Расход', 3, 7, 11, 165.000, 0.7480, -4.00, 123.420, 61200.00, 'ТТН-2026-114'),
('2026-11-08 09:15:00', 'Расход', 4, 14, 12, 140.000, 0.7485, -5.20, 104.790, 61200.00, 'ТТН-2026-115'),
('2026-11-10 14:50:00', 'Расход', 8, 10, 11, 125.000, 0.8330, -6.00, 104.125, 63100.00, 'ТТН-2026-116'),
('2026-11-12 10:10:00', 'Расход', 9, 8, 12, 205.000, 0.8260, -7.50, 169.330, 67800.00, 'ТТН-2026-117'),
('2026-11-14 16:00:00', 'Расход', 10, 11, 11, 110.000, 0.8180, -9.20, 89.980, 75600.00, 'ТТН-2026-118'),
('2026-11-16 09:30:00', 'Расход', 1, 15, 12, 115.000, 0.7390, -10.50, 84.985, 56800.00, 'ТТН-2026-119'),
('2026-11-18 11:45:00', 'Расход', 15, 13, 11, 85.000, 0.8580, -8.00, 72.930, 52900.00, 'ТТН-2026-120'),
('2026-10-20 17:00:00', 'Списание', 1, NULL, 13, 1.850, 0.7360, 8.00, 1.362, 56800.00, 'АКТ-2026-001'),
('2026-10-30 17:30:00', 'Списание', 7, NULL, 13, 2.400, 0.8370, 2.00, 2.009, 60400.00, 'АКТ-2026-002'),
('2026-11-11 16:45:00', 'Списание', 13, NULL, 13, 3.100, 0.9650, 15.00, 2.992, 31400.00, 'АКТ-2026-003'),
('2026-11-17 17:15:00', 'Списание', 3, NULL, 13, 1.500, 0.7475, -6.50, 1.121, 61200.00, 'АКТ-2026-004');

INSERT INTO stock_forecasts (tank_id, forecast_date, horizon_days, avg_daily_demand_tons, predicted_end_stock_tons, reorder_point_tons, recommended_order_tons, risk_level, created_by) VALUES
(1, '2026-11-19', 14, 38.500, 581.500, 404.000, 0.000, 'Низкий', 2),
(2, '2026-11-19', 14, 29.400, -201.200, 367.600, 650.000, 'Критический', 2),
(3, '2026-11-19', 14, 42.100, 1090.850, 560.500, 0.000, 'Низкий', 2),
(4, '2026-11-19', 14, 31.800, -199.400, 439.000, 700.000, 'Критический', 2),
(5, '2026-11-19', 14, 14.200, 286.800, 191.000, 0.000, 'Низкий', 14),
(6, '2026-11-19', 14, 9.600, 155.750, 128.000, 0.000, 'Средний', 14),
(7, '2026-11-19', 14, 52.000, 1122.000, 608.000, 0.000, 'Низкий', 2),
(8, '2026-11-19', 14, 34.500, 457.750, 472.500, 200.000, 'Средний', 14),
(9, '2026-11-19', 14, 48.200, -284.600, 642.800, 950.000, 'Критический', 2),
(10, '2026-11-19', 14, 24.000, 384.400, 320.000, 0.000, 'Средний', 14),
(11, '2026-11-19', 14, 36.400, 730.400, 409.200, 0.000, 'Низкий', 2),
(12, '2026-11-19', 14, 18.500, -128.500, 224.000, 400.000, 'Критический', 2),
(13, '2026-11-19', 14, 64.000, 2224.000, 920.000, 0.000, 'Низкий', 14),
(15, '2026-11-19', 14, 16.800, 180.100, 184.000, 150.000, 'Высокий', 14),
(1, '2026-11-19', 30, 38.500, -34.500, 404.000, 450.000, 'Высокий', 2),
(3, '2026-11-19', 30, 42.100, 417.250, 560.500, 300.000, 'Средний', 2),
(8, '2026-11-19', 30, 34.500, -94.250, 472.500, 600.000, 'Высокий', 14),
(10, '2026-11-19', 30, 24.000, 0.400, 320.000, 350.000, 'Высокий', 14);

INSERT INTO stock_alerts (tank_id, alert_time, alert_type, message, is_resolved) VALUES
(2, '2026-11-04 11:05:00', 'Ниже минимума', 'Остаток в РВС-02 (210.400 т) ниже страхового запаса (250.000 т).', FALSE),
(4, '2026-11-08 09:20:00', 'Ниже минимума', 'Остаток в РВС-04 (245.800 т) ниже страхового запаса (280.000 т).', FALSE),
(9, '2026-11-12 10:15:00', 'Ниже минимума', 'Остаток в РВС-09 (390.200 т) ниже страхового запаса (450.000 т).', FALSE),
(12, '2026-10-29 15:30:00', 'Ниже минимума', 'Остаток в РВС-12 (130.500 т) ниже страхового запаса (150.000 т).', FALSE),
(2, '2026-11-19 08:00:00', 'Дефицит по прогнозу', 'Прогнозируется дефицит АИ-92-К5 в РВС-02 через 14 дн.: -201.200 т.', FALSE),
(4, '2026-11-19 08:00:00', 'Дефицит по прогнозу', 'Прогнозируется дефицит АИ-95-К5 в РВС-04 через 14 дн.: -199.400 т.', FALSE),
(9, '2026-11-19 08:00:00', 'Дефицит по прогнозу', 'Прогнозируется дефицит ДТ-З-К5 в РВС-09 через 14 дн.: -284.600 т.', FALSE),
(12, '2026-11-19 08:00:00', 'Дефицит по прогнозу', 'Прогнозируется дефицит РТ в РВС-12 через 14 дн.: -128.500 т.', FALSE),
(1, '2026-10-01 09:00:00', 'Ниже минимума', 'Кратковременное снижение остатка в РВС-01 до планового прихода.', TRUE),
(3, '2026-10-03 14:10:00', 'Ниже минимума', 'Остаток в РВС-03 снижался до 310 т, пополнено по ЖДН-2026-002.', TRUE),
(13, '2026-11-01 09:00:00', 'Просрочка калибровки', 'Приближается срок очередной градуировки резервуара РВС-13.', FALSE),
(14, '2026-09-15 10:00:00', 'Просрочка калибровки', 'Требуется внеочередная калибровка РВС-14 после завершения ремонта.', FALSE),
(7, '2026-10-06 09:05:00', 'Переполнение', 'Уровень налива РВС-07 приближался к 90% номинала при приемке.', TRUE),
(8, '2026-11-19 08:05:00', 'Дефицит по прогнозу', 'На горизонте 30 дней по РВС-08 ожидается дефицит -94.250 т.', FALSE),
(15, '2026-11-19 08:10:00', 'Дефицит по прогнозу', 'Резервуар РВС-15 достиг точки дозаказа (184.000 т).', FALSE);


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


-- 8. ТРИГГЕРЫ КОНТРОЛЯ ОСТАТКОВ И АВТОМАТИЧЕСКОГО ОПОВЕЩЕНИЯ

CREATE OR REPLACE FUNCTION fn_trg_validate_and_update_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status    VARCHAR(20);
    v_cur_stock NUMERIC(10, 3);
    v_max_mass  NUMERIC(10, 3);
BEGIN
    SELECT t.status, t.current_stock_tons,
           ROUND(t.max_capacity_m3 * f.std_density, 3)
    INTO v_status, v_cur_stock, v_max_mass
    FROM storage_tanks t
    JOIN fuel_types f ON f.fuel_id = t.fuel_id
    WHERE t.tank_id = NEW.tank_id
    FOR UPDATE;

    IF v_status <> 'Активен' THEN
        RAISE EXCEPTION 'Операция запрещена: резервуар ID=% имеет статус %', NEW.tank_id, v_status;
    END IF;

    NEW.mass_tons := ROUND(NEW.volume_m3 * NEW.measured_density, 3);

    IF NEW.operation_type = 'Приход' THEN
        IF v_cur_stock + NEW.mass_tons > v_max_mass THEN
            RAISE EXCEPTION 'Превышена вместимость резервуара ID=% (макс. % т)', NEW.tank_id, v_max_mass;
        END IF;
        UPDATE storage_tanks
        SET current_stock_tons = current_stock_tons + NEW.mass_tons
        WHERE tank_id = NEW.tank_id;
    ELSE
        IF v_cur_stock < NEW.mass_tons THEN
            RAISE EXCEPTION 'Недостаточно топлива в резервуаре ID=% (остаток % т)', NEW.tank_id, v_cur_stock;
        END IF;
        UPDATE storage_tanks
        SET current_stock_tons = current_stock_tons - NEW.mass_tons
        WHERE tank_id = NEW.tank_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_and_update_stock
BEFORE INSERT ON stock_operations
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validate_and_update_stock();


CREATE OR REPLACE FUNCTION fn_trg_monitor_stock_threshold()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'Активен' AND NEW.current_stock_tons < NEW.min_reserve_tons THEN
        INSERT INTO stock_alerts (tank_id, alert_type, message)
        VALUES (
            NEW.tank_id,
            'Ниже минимума',
            FORMAT('Остаток в %s (%s т) ниже страхового запаса (%s т).',
                   NEW.tank_code, NEW.current_stock_tons, NEW.min_reserve_tons)
        );
    ELSIF NEW.current_stock_tons >= NEW.min_reserve_tons
      AND OLD.current_stock_tons < OLD.min_reserve_tons THEN
        UPDATE stock_alerts
        SET is_resolved = TRUE
        WHERE tank_id = NEW.tank_id
          AND alert_type = 'Ниже минимума'
          AND is_resolved = FALSE;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_monitor_stock_threshold
AFTER UPDATE OF current_stock_tons ON storage_tanks
FOR EACH ROW
EXECUTE FUNCTION fn_trg_monitor_stock_threshold();


-- 9. АНАЛИТИЧЕСКИЕ SQL-ЗАПРОСЫ (23 ЗАПРОСА)


-- Запрос 1.A: Однотабличный запрос с простым условием: вывести резервуары, текущий остаток в которых ниже установленного страхового запаса.
SELECT tank_code, tank_type, current_stock_tons, min_reserve_tons
FROM storage_tanks
WHERE current_stock_tons < min_reserve_tons
ORDER BY current_stock_tons;


-- Запрос 1.B (b1): Однотабличный запрос со сложным условием (*AND*, *AND*, *NOT*): выбрать нефтепродукты с оптовой ценой выше 55000 руб./т, плотностью не ниже 0.7400 т/м³, не относящиеся к категории «Авиатопливо».
SELECT fuel_code, fuel_name, category, std_density, wholesale_price
FROM fuel_types
WHERE wholesale_price > 55000
  AND std_density >= 0.7400
  AND NOT (category = 'Авиатопливо')
ORDER BY wholesale_price DESC;


-- Запрос 1.B (b2): Однотабличный запрос со сложным условием (*AND*, *OR*): выбрать контрагентов-покупателей из Омской или Новосибирской области.
SELECT company_name, inn, region, lead_time_days
FROM counterparties
WHERE cp_type = 'Покупатель'
  AND (region = 'Омская область' OR region = 'Новосибирская область')
ORDER BY region, company_name;


-- Запрос 1.B (b3): Однотабличный запрос со сложным условием (*AND*, *AND*): выбрать активные резервуары с текущим остатком свыше 500 т и неснижаемым запасом не более 350 т.
SELECT tank_code, tank_type, max_capacity_m3, current_stock_tons, min_reserve_tons
FROM storage_tanks
WHERE status = 'Активен'
  AND current_stock_tons > 500
  AND min_reserve_tons <= 350
ORDER BY current_stock_tons DESC;


-- Запрос 1.C: Многотабличный запрос с вычисляемым полем и простым условием: рассчитать текущую оптовую стоимость запасов нефтепродуктов в активных резервуарах.
SELECT t.tank_code, f.fuel_name, t.current_stock_tons,
       ROUND(t.current_stock_tons * f.wholesale_price, 2) AS stock_value_rub
FROM storage_tanks t
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE t.status = 'Активен'
ORDER BY stock_value_rub DESC
LIMIT 8;


-- Запрос 1.D (d1): Многотабличный запрос со сложным условием (*OR*, *AND*, *NOT*): выбрать операции с бензином или дизельным топливом массой свыше 140 т, исключая списания.
SELECT o.document_number, o.operation_date, o.operation_type,
       t.tank_code, f.fuel_code, o.mass_tons
FROM stock_operations o
JOIN storage_tanks t ON t.tank_id = o.tank_id
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE (f.category = 'Бензин' OR f.category = 'Дизельное топливо')
  AND o.mass_tons > 140
  AND NOT (o.operation_type = 'Списание')
ORDER BY o.mass_tons DESC
LIMIT 8;


-- Запрос 1.D (d2): Многотабличный запрос со сложным условием (*AND*, *AND*): выбрать крупные отгрузки (объемом свыше 160 м³) нефтепродуктов экологического класса «К5» с указанием диспетчера.
SELECT o.document_number, o.operation_date, t.tank_code,
       f.fuel_code, o.volume_m3, o.mass_tons, e.full_name
FROM stock_operations o
JOIN storage_tanks t ON t.tank_id = o.tank_id
JOIN fuel_types f ON f.fuel_id = t.fuel_id
JOIN employees e ON e.employee_id = o.employee_id
WHERE o.operation_type = 'Расход'
  AND f.eco_class = 'К5'
  AND o.volume_m3 > 160
ORDER BY o.volume_m3 DESC;


-- Запрос 1.D (d3): Многотабличный запрос со сложным условием (*AND*, оператор *BETWEEN*): выбрать отгрузки нефтепродуктов за период с 15.10.2026 по 31.10.2026 включительно.
SELECT o.document_number, o.operation_date, c.company_name,
       f.fuel_code, o.mass_tons
FROM stock_operations o
JOIN storage_tanks t ON t.tank_id = o.tank_id
JOIN fuel_types f ON f.fuel_id = t.fuel_id
JOIN counterparties c ON c.counterparty_id = o.counterparty_id
WHERE o.operation_type = 'Расход'
  AND o.operation_date BETWEEN '2026-10-15 00:00:00' AND '2026-10-31 23:59:59'
ORDER BY o.operation_date;


-- Запрос 1.D (d4): Многотабличный запрос со сложным условием (*AND*, оператор *NOT BETWEEN*): выбрать активные резервуары, текущий остаток в которых выходит за пределы среднего диапазона от 400 до 1200 т.
SELECT t.tank_code, f.fuel_code, t.current_stock_tons, t.min_reserve_tons
FROM storage_tanks t
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE t.status = 'Активен'
  AND t.current_stock_tons NOT BETWEEN 400 AND 1200
ORDER BY t.current_stock_tons;


-- Запрос 1.D (d5): Многотабличный запрос с оператором *IN*: вывести прогнозы запасов с высоким и критическим уровнями риска дефицита.
SELECT t.tank_code, f.fuel_code, sf.horizon_days,
       sf.predicted_end_stock_tons, sf.recommended_order_tons, sf.risk_level
FROM stock_forecasts sf
JOIN storage_tanks t ON t.tank_id = sf.tank_id
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE sf.risk_level IN ('Высокий', 'Критический')
ORDER BY sf.predicted_end_stock_tons ASC;


-- Запрос 1.D (d6): Многотабличный запрос с оператором *NOT IN*: вывести приемку нефтепродуктов от иногородних поставщиков за пределами Омской и Тюменской областей.
SELECT o.document_number, o.operation_date, c.company_name,
       c.region, f.fuel_code, o.mass_tons
FROM stock_operations o
JOIN storage_tanks t ON t.tank_id = o.tank_id
JOIN fuel_types f ON f.fuel_id = t.fuel_id
JOIN counterparties c ON c.counterparty_id = o.counterparty_id
WHERE o.operation_type = 'Приход'
  AND c.region NOT IN ('Омская область', 'Тюменская область')
ORDER BY o.operation_date;


-- Запрос 2.1: Ранжирование активных резервуаров по величине остатка внутри каждой категории нефтепродуктов (*DENSE_RANK*) с расчетом доли резервуара в общем запасе категории.
SELECT f.category, t.tank_code, t.current_stock_tons,
       DENSE_RANK() OVER (PARTITION BY f.category ORDER BY t.current_stock_tons DESC) AS cat_rank,
       ROUND(t.current_stock_tons * 100.0
             / SUM(t.current_stock_tons) OVER (PARTITION BY f.category), 2) AS cat_share_pct
FROM storage_tanks t
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE t.status = 'Активен'
ORDER BY f.category, cat_rank;


-- Запрос 2.2: Расчет накопительного итога отгрузок и скользящего среднего по трем последним операциям расхода для резервуаров РВС-01 и РВС-09.
SELECT t.tank_code, o.operation_date, o.document_number, o.mass_tons,
       ROUND(SUM(o.mass_tons) OVER (
           PARTITION BY o.tank_id ORDER BY o.operation_date
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 3) AS cum_mass_tons,
       ROUND(AVG(o.mass_tons) OVER (
           PARTITION BY o.tank_id ORDER BY o.operation_date
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 3) AS mov_avg_3
FROM stock_operations o
JOIN storage_tanks t ON t.tank_id = o.tank_id
WHERE o.operation_type = 'Расход'
  AND t.tank_code IN ('РВС-01', 'РВС-09')
ORDER BY t.tank_code, o.operation_date;


-- Запрос 2.3: Анализ динамики последовательных отгрузок с помощью оконной функции смещения *LAG* и вычислением отклонения массы от предыдущей партии.
SELECT t.tank_code, o.operation_date, o.mass_tons,
       LAG(o.mass_tons) OVER (PARTITION BY o.tank_id ORDER BY o.operation_date) AS prev_mass_tons,
       ROUND(o.mass_tons - LAG(o.mass_tons) OVER (
           PARTITION BY o.tank_id ORDER BY o.operation_date), 3) AS delta_tons
FROM stock_operations o
JOIN storage_tanks t ON t.tank_id = o.tank_id
WHERE o.operation_type = 'Расход'
  AND t.tank_code IN ('РВС-01', 'РВС-03', 'РВС-09')
ORDER BY t.tank_code, o.operation_date;


-- Запрос 3.1: Расчет максимальной массовой вместимости, свободной емкости в тоннах и процента заполнения активных резервуаров с учетом стандартной плотности нефтепродукта.
SELECT t.tank_code, f.fuel_code, t.current_stock_tons,
       ROUND(t.max_capacity_m3 * f.std_density, 3) AS max_mass_tons,
       ROUND((t.max_capacity_m3 * f.std_density) - t.current_stock_tons, 3) AS free_mass_tons,
       ROUND((t.current_stock_tons / (t.max_capacity_m3 * f.std_density)) * 100.0, 2) AS fill_pct
FROM storage_tanks t
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE t.status = 'Активен'
ORDER BY fill_pct DESC
LIMIT 8;


-- Запрос 3.2: Расчет запаса автономности (количества суток до достижения страхового минимума) и требуемого бюджета на пополнение по 14-дневному прогнозу.
SELECT t.tank_code, f.fuel_code, t.current_stock_tons, sf.avg_daily_demand_tons,
       ROUND((t.current_stock_tons - t.min_reserve_tons) / sf.avg_daily_demand_tons, 1) AS days_to_min,
       sf.recommended_order_tons,
       ROUND(sf.recommended_order_tons * f.wholesale_price, 2) AS order_budget_rub
FROM stock_forecasts sf
JOIN storage_tanks t ON t.tank_id = sf.tank_id
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE sf.horizon_days = 14 AND sf.recommended_order_tons > 0
ORDER BY days_to_min ASC;


-- Запрос 4.1: Группировка данных и простая сортировка: подсчет количества активных резервуаров, суммарного запаса и средней оптовой цены по категориям нефтепродуктов.
SELECT f.category,
       COUNT(t.tank_id) AS tank_count,
       ROUND(SUM(t.current_stock_tons), 3) AS total_stock_tons,
       ROUND(AVG(f.wholesale_price), 2) AS avg_price_rub
FROM storage_tanks t
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE t.status = 'Активен'
GROUP BY f.category
ORDER BY total_stock_tons DESC;


-- Запрос 4.2: Группировка с условием (*HAVING*) и многоуровневой сортировкой по трем полям: итоги операций прихода и расхода по категориям и маркам топлива с объемом свыше 150 т.
SELECT f.category, o.operation_type, f.fuel_code,
       COUNT(o.operation_id) AS op_count,
       ROUND(SUM(o.mass_tons), 3) AS total_mass_tons,
       ROUND(SUM(o.mass_tons * o.unit_price), 2) AS total_sum_rub
FROM stock_operations o
JOIN storage_tanks t ON t.tank_id = o.tank_id
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE o.operation_type IN ('Приход', 'Расход')
GROUP BY f.category, o.operation_type, f.fuel_code
HAVING SUM(o.mass_tons) > 150
ORDER BY f.category ASC, o.operation_type ASC, total_mass_tons DESC;


-- Запрос 5.1: Запрос со скалярным подзапросом: выбрать активные резервуары, текущий остаток в которых превышает средний остаток по всем активным резервуарам нефтебазы.
SELECT t.tank_code, f.fuel_code, t.current_stock_tons
FROM storage_tanks t
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE t.status = 'Активен'
  AND t.current_stock_tons > (
      SELECT AVG(current_stock_tons)
      FROM storage_tanks
      WHERE status = 'Активен'
  )
ORDER BY t.current_stock_tons DESC;


-- Запрос 5.2: Запрос с операциями *IN* и *NOT IN*: выбрать марки нефтепродуктов, размещенные в активных резервуарах, но не имеющие зарегистрированных актов списания.
SELECT fuel_code, fuel_name, category, wholesale_price
FROM fuel_types
WHERE fuel_id IN (
      SELECT DISTINCT fuel_id
      FROM storage_tanks
      WHERE status = 'Активен'
  )
  AND fuel_id NOT IN (
      SELECT DISTINCT t.fuel_id
      FROM stock_operations o
      JOIN storage_tanks t ON t.tank_id = o.tank_id
      WHERE o.operation_type = 'Списание'
  )
ORDER BY fuel_code;


-- Запрос 5.3: Запрос с ключевыми словами *ALL* и *ANY*: выбрать отгрузки, масса которых превышает массу всех операций списания (*> ALL*), а цена за тонну ниже цены хотя бы одного вида авиатоплива (*< ANY*).
SELECT o.document_number, f.fuel_code, o.mass_tons, o.unit_price
FROM stock_operations o
JOIN storage_tanks t ON t.tank_id = o.tank_id
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE o.operation_type = 'Расход'
  AND o.mass_tons > ALL (
      SELECT mass_tons
      FROM stock_operations
      WHERE operation_type = 'Списание'
  )
  AND o.unit_price < ANY (
      SELECT wholesale_price
      FROM fuel_types
      WHERE category = 'Авиатопливо'
  )
ORDER BY o.mass_tons DESC
LIMIT 8;


-- Запрос 5.4: Запрос с операциями *EXISTS* и *NOT EXISTS*: выбрать резервуары, для которых выявлен высокий или критический риск дефицита, но отсутствуют активные уведомления о переполнении.
SELECT t.tank_code, f.fuel_code, t.current_stock_tons, t.min_reserve_tons
FROM storage_tanks t
JOIN fuel_types f ON f.fuel_id = t.fuel_id
WHERE EXISTS (
      SELECT 1
      FROM stock_forecasts sf
      WHERE sf.tank_id = t.tank_id
        AND sf.risk_level IN ('Высокий', 'Критический')
  )
  AND NOT EXISTS (
      SELECT 1
      FROM stock_alerts sa
      WHERE sa.tank_id = t.tank_id
        AND sa.alert_type = 'Переполнение'
        AND sa.is_resolved = FALSE
  )
ORDER BY t.current_stock_tons;


-- Запрос 6.1: Выборка из материализованного представления *mv_tank_inventory_summary* (описанного в разделе 6.1) для получения сводки резервуаров с высоким и критическим риском дефицита и стоимости их пополнения.
SELECT tank_code, fuel_code, current_stock_tons, fill_pct,
       predicted_end_stock_tons, recommended_order_tons, risk_level,
       ROUND(recommended_order_tons * wholesale_price, 2) AS order_cost_rub
FROM mv_tank_inventory_summary
WHERE risk_level IN ('Высокий', 'Критический')
ORDER BY predicted_end_stock_tons ASC;


-- 10. ПРИМЕРЫ ВЫЗОВА СЕРВЕРНЫХ ОБЪЕКТОВ (РАСКОММЕНТИРОВАТЬ ДЛЯ ТЕСТИРОВАНИЯ)
-- SELECT * FROM fn_forecast_tank_stock(9, 14::SMALLINT, 30);
-- SELECT * FROM fn_generate_reorder_plan(14::SMALLINT);
-- SELECT fn_audit_unclosed_alerts('РВС');
-- CALL sp_register_operation_and_forecast('Расход', 1, 7, 11, 95.000, 0.7385, -8.50, 56800.00, 'ТТН-2026-121');

