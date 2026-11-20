SET client_encoding = 'UTF8';

DROP TABLE IF EXISTS reserve_forecasts CASCADE;
DROP TABLE IF EXISTS tank_measurements CASCADE;
DROP TABLE IF EXISTS stock_movements CASCADE;
DROP TABLE IF EXISTS shipment_items CASCADE;
DROP TABLE IF EXISTS shipments CASCADE;
DROP TABLE IF EXISTS delivery_items CASCADE;
DROP TABLE IF EXISTS deliveries CASCADE;
DROP TABLE IF EXISTS price_history CASCADE;
DROP TABLE IF EXISTS tanks CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS products CASCADE;

CREATE TABLE products (
    id_product      SERIAL PRIMARY KEY,
    product_code    VARCHAR(10) NOT NULL UNIQUE,
    name            VARCHAR(60) NOT NULL,
    category        VARCHAR(30) NOT NULL
                    CHECK (category IN ('бензин', 'дизельное топливо', 'мазут', 'масло')),
    octane_rating   SMALLINT CHECK (octane_rating BETWEEN 80 AND 100),
    density         NUMERIC(6,2) NOT NULL CHECK (density BETWEEN 700 AND 950),
    min_reserve     NUMERIC(12,3) NOT NULL CHECK (min_reserve >= 0),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (category <> 'бензин' OR octane_rating IS NOT NULL)
);

CREATE TABLE suppliers (
    id_supplier     SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL UNIQUE,
    inn             VARCHAR(12) NOT NULL UNIQUE
                    CHECK (inn ~ '^[0-9]{10}([0-9]{2})?$'),
    phone           VARCHAR(20) NOT NULL,
    contact_person  VARCHAR(100),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE clients (
    id_client       SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    client_type     VARCHAR(20) NOT NULL
                    CHECK (client_type IN ('оптовый', 'розничный')),
    inn             VARCHAR(12) NOT NULL UNIQUE
                    CHECK (inn ~ '^[0-9]{10}([0-9]{2})?$'),
    phone           VARCHAR(20),
    contract_number VARCHAR(30) NOT NULL UNIQUE,
    contract_date   DATE NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE tanks (
    id_tank          SERIAL PRIMARY KEY,
    tank_number      VARCHAR(10) NOT NULL UNIQUE,
    capacity         NUMERIC(12,3) NOT NULL CHECK (capacity > 0),
    current_volume   NUMERIC(12,3) NOT NULL DEFAULT 0 CHECK (current_volume >= 0),
    id_product       INTEGER NOT NULL REFERENCES products(id_product)
                     ON DELETE RESTRICT ON UPDATE CASCADE,
    status           VARCHAR(20) NOT NULL DEFAULT 'в эксплуатации'
                     CHECK (status IN ('в эксплуатации', 'на ремонте', 'выведен')),
    commissioned_date DATE NOT NULL,
    CHECK (current_volume <= capacity)
);

CREATE TABLE price_history (
    id_price        BIGSERIAL PRIMARY KEY,
    id_product      INTEGER NOT NULL REFERENCES products(id_product)
                    ON DELETE RESTRICT ON UPDATE CASCADE,
    effective_date  DATE NOT NULL,
    purchase_price  NUMERIC(10,2) NOT NULL CHECK (purchase_price >= 0),
    retail_price    NUMERIC(10,2) NOT NULL CHECK (retail_price >= 0),
    UNIQUE (id_product, effective_date),
    CHECK (retail_price >= purchase_price)
);

CREATE TABLE deliveries (
    id_delivery     SERIAL PRIMARY KEY,
    delivery_number VARCHAR(20) NOT NULL UNIQUE,
    id_supplier     INTEGER NOT NULL REFERENCES suppliers(id_supplier)
                    ON DELETE RESTRICT ON UPDATE CASCADE,
    delivery_date   DATE NOT NULL,
    invoice_number  VARCHAR(30) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'оформлена'
                    CHECK (status IN ('оформлена', 'принята', 'отменена')),
    total_amount    NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (status <> 'принята' OR total_amount > 0),
    CHECK (status <> 'отменена' OR total_amount = 0)
);

CREATE TABLE delivery_items (
    id_delivery_item BIGSERIAL PRIMARY KEY,
    id_delivery      INTEGER NOT NULL REFERENCES deliveries(id_delivery)
                     ON DELETE RESTRICT ON UPDATE CASCADE,
    line_no          SMALLINT NOT NULL CHECK (line_no > 0),
    id_product       INTEGER NOT NULL REFERENCES products(id_product)
                     ON DELETE RESTRICT ON UPDATE CASCADE,
    id_tank          INTEGER NOT NULL REFERENCES tanks(id_tank)
                     ON DELETE RESTRICT ON UPDATE CASCADE,
    volume           NUMERIC(12,3) NOT NULL CHECK (volume > 0),
    price_per_liter  NUMERIC(10,2) NOT NULL CHECK (price_per_liter >= 0),
    total_cost       NUMERIC(14,2) GENERATED ALWAYS AS (ROUND(volume * price_per_liter, 2)) STORED,
    UNIQUE (id_delivery, line_no)
);

CREATE TABLE shipments (
    id_shipment     SERIAL PRIMARY KEY,
    shipment_number VARCHAR(20) NOT NULL UNIQUE,
    id_client       INTEGER NOT NULL REFERENCES clients(id_client)
                    ON DELETE RESTRICT ON UPDATE CASCADE,
    shipment_date   DATE NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'оформлена'
                    CHECK (status IN ('оформлена', 'отгружена', 'отменена')),
    payment_type    VARCHAR(20) NOT NULL
                    CHECK (payment_type IN ('безналичный', 'наличный')),
    total_amount    NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (status <> 'отгружена' OR total_amount > 0),
    CHECK (status <> 'отменена' OR total_amount = 0)
);

CREATE TABLE shipment_items (
    id_shipment_item BIGSERIAL PRIMARY KEY,
    id_shipment      INTEGER NOT NULL REFERENCES shipments(id_shipment)
                     ON DELETE RESTRICT ON UPDATE CASCADE,
    line_no          SMALLINT NOT NULL CHECK (line_no > 0),
    id_product       INTEGER NOT NULL REFERENCES products(id_product)
                     ON DELETE RESTRICT ON UPDATE CASCADE,
    id_tank          INTEGER NOT NULL REFERENCES tanks(id_tank)
                     ON DELETE RESTRICT ON UPDATE CASCADE,
    volume           NUMERIC(12,3) NOT NULL CHECK (volume > 0),
    price_per_liter  NUMERIC(10,2) NOT NULL CHECK (price_per_liter >= 0),
    total_cost       NUMERIC(14,2) GENERATED ALWAYS AS (ROUND(volume * price_per_liter, 2)) STORED,
    UNIQUE (id_shipment, line_no)
);

CREATE TABLE stock_movements (
    id_movement      BIGSERIAL PRIMARY KEY,
    movement_date    TIMESTAMPTZ NOT NULL DEFAULT now(),
    id_product       INTEGER NOT NULL REFERENCES products(id_product)
                     ON DELETE RESTRICT ON UPDATE CASCADE,
    id_tank          INTEGER NOT NULL REFERENCES tanks(id_tank)
                     ON DELETE RESTRICT ON UPDATE CASCADE,
    movement_type    VARCHAR(20) NOT NULL
                     CHECK (movement_type IN ('приход', 'расход', 'корректировка')),
    volume           NUMERIC(12,3) NOT NULL CHECK (volume <> 0),
    id_delivery_item BIGINT REFERENCES delivery_items(id_delivery_item)
                     ON DELETE SET NULL ON UPDATE CASCADE,
    id_shipment_item BIGINT REFERENCES shipment_items(id_shipment_item)
                     ON DELETE SET NULL ON UPDATE CASCADE,
    comment          VARCHAR(200),
    CHECK (num_nonnulls(id_delivery_item, id_shipment_item) <= 1),
    CHECK (
        (movement_type = 'приход' AND volume > 0) OR
        (movement_type = 'расход' AND volume < 0) OR
        (movement_type = 'корректировка' AND volume <> 0)
    )
);

CREATE TABLE tank_measurements (
    id_measurement  BIGSERIAL PRIMARY KEY,
    id_tank         INTEGER NOT NULL REFERENCES tanks(id_tank)
                    ON DELETE RESTRICT ON UPDATE CASCADE,
    measured_at     TIMESTAMPTZ NOT NULL,
    volume          NUMERIC(12,3) NOT NULL CHECK (volume >= 0),
    temperature     NUMERIC(5,2) CHECK (temperature BETWEEN -50 AND 60),
    density         NUMERIC(6,2) CHECK (density BETWEEN 700 AND 950),
    UNIQUE (id_tank, measured_at)
);

CREATE TABLE reserve_forecasts (
    id_forecast     BIGSERIAL PRIMARY KEY,
    id_product      INTEGER NOT NULL REFERENCES products(id_product)
                    ON DELETE RESTRICT ON UPDATE CASCADE,
    forecast_date   DATE NOT NULL,
    horizon_days    SMALLINT NOT NULL CHECK (horizon_days BETWEEN 1 AND 365),
    current_stock   NUMERIC(12,3) NOT NULL CHECK (current_stock >= 0),
    avg_daily_consumption NUMERIC(12,3) NOT NULL CHECK (avg_daily_consumption >= 0),
    predicted_consumption NUMERIC(12,3) NOT NULL CHECK (predicted_consumption >= 0),
    predicted_reserve     NUMERIC(12,3) NOT NULL,
    method          VARCHAR(40) NOT NULL DEFAULT 'средний расход за 30 дней',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (id_product, forecast_date, horizon_days)
);
