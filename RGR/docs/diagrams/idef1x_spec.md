# Спецификация концептуальной модели IDEF1X

**Вариант 17.** База данных автоматизации учёта и прогноза запасов нефтепродуктов, реализуемых нефтебазой.

Модель содержит 12 независимых и зависимых сущностей. Первичные ключи — суррогатные (`SERIAL`/`BIGSERIAL`), естественные идентификаторы объявлены уникальными. Все связи — неидентифицирующие (линия с точкой на стороне «один» и символом `N` на стороне «многие»); дочерняя сущность не входит в первичный ключ родителя.

**Инструмент:** draw.io (файл `docs/diagrams/idef1x.drawio`), экспорт `docs/diagrams/idef1x.png`; в отчёте — рисунок 1.

## 1. Перечень сущностей

| Сущность | Назначение | Первичный ключ | Естественный ключ |
|---|---|---|---|
| `products` | Справочник нефтепродуктов | `id_product` | product_code |
| `suppliers` | Справочник поставщиков | `id_supplier` | inn, name |
| `clients` | Справочник клиентов (оптовых и розничных) | `id_client` | inn, contract_number |
| `tanks` | Резервуары и их учётные остатки | `id_tank` | tank_number |
| `price_history` | История закупочных и розничных цен | `id_price` | (id_product, effective_date) |
| `deliveries` | Документы поставки (прихода) | `id_delivery` | delivery_number |
| `delivery_items` | Позиции документа поставки | `id_delivery_item` | (id_delivery, line_no) |
| `shipments` | Документы отгрузки (расхода) | `id_shipment` | shipment_number |
| `shipment_items` | Позиции документа отгрузки | `id_shipment_item` | (id_shipment, line_no) |
| `stock_movements` | Журнал движений топлива (приход, расход, корректировка) | `id_movement` | — (записи журнала) |
| `tank_measurements` | Замеры объёма, температуры и плотности | `id_measurement` | (id_tank, measured_at) |
| `reserve_forecasts` | Прогнозы остатков по продуктам | `id_forecast` | (id_product, forecast_date, horizon_days) |

## 2. Атрибуты сущностей

### 2.1 `products`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_product` | SERIAL | PK | Суррогатный ключ продукта |
| `product_code` | VARCHAR(10) | UNIQUE, NOT NULL | Код марки (АИ-92, ДТ-Л и т. п.) |
| `name` | VARCHAR(60) | NOT NULL | Полное наименование |
| `category` | VARCHAR(30) | CHECK, NOT NULL | бензин / дизельное топливо / мазут / масло |
| `octane_rating` | SMALLINT | CHECK 80–100 | Октановое число бензина |
| `density` | NUMERIC(6,2) | CHECK 700–950 | Плотность, кг/м³ |
| `min_reserve` | NUMERIC(12,3) | CHECK >= 0 | Минимальный нормативный запас, л |
| `is_active` | BOOLEAN | DEFAULT TRUE | Признак актуальности |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Дата создания записи |

### 2.2 `suppliers`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_supplier` | SERIAL | PK | Суррогатный ключ поставщика |
| `name` | VARCHAR(100) | UNIQUE, NOT NULL | Наименование организации |
| `inn` | VARCHAR(12) | UNIQUE, CHECK regexp | ИНН: 10 или 12 цифр |
| `phone` | VARCHAR(20) | NOT NULL | Контактный телефон |
| `contact_person` | VARCHAR(100) | — | Контактное лицо |
| `is_active` | BOOLEAN | DEFAULT TRUE | Признак действующего договора |

### 2.3 `clients`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_client` | SERIAL | PK | Суррогатный ключ клиента |
| `name` | VARCHAR(100) | NOT NULL | Наименование клиента |
| `client_type` | VARCHAR(20) | CHECK, NOT NULL | оптовый / розничный |
| `inn` | VARCHAR(12) | UNIQUE, CHECK regexp | ИНН клиента |
| `phone` | VARCHAR(20) | — | Телефон |
| `contract_number` | VARCHAR(30) | UNIQUE, NOT NULL | Номер договора |
| `contract_date` | DATE | NOT NULL | Дата договора |
| `is_active` | BOOLEAN | DEFAULT TRUE | Признак активности |

### 2.4 `tanks`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_tank` | SERIAL | PK | Суррогатный ключ резервуара |
| `tank_number` | VARCHAR(10) | UNIQUE, NOT NULL | Инвентарный номер (Р-01) |
| `capacity` | NUMERIC(12,3) | CHECK > 0 | Полная ёмкость, л |
| `current_volume` | NUMERIC(12,3) | CHECK 0..capacity | Текущий учётный остаток, л |
| `id_product` | INTEGER | FK → products | Хранимый продукт |
| `status` | VARCHAR(20) | CHECK, DEFAULT | в эксплуатации / на ремонте / выведен |
| `commissioned_date` | DATE | NOT NULL | Дата ввода в эксплуатацию |

### 2.5 `price_history`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_price` | BIGSERIAL | PK | Суррогатный ключ записи цены |
| `id_product` | INTEGER | FK → products | Продукт |
| `effective_date` | DATE | UNIQUE(product,date) | Дата действия цены |
| `purchase_price` | NUMERIC(10,2) | CHECK >= 0 | Закупочная цена, руб./л |
| `retail_price` | NUMERIC(10,2) | CHECK >= purchase | Розничная цена, руб./л |

### 2.6 `deliveries`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_delivery` | SERIAL | PK | Суррогатный ключ поставки |
| `delivery_number` | VARCHAR(20) | UNIQUE, NOT NULL | Номер документа |
| `id_supplier` | INTEGER | FK → suppliers | Поставщик |
| `delivery_date` | DATE | NOT NULL | Дата поставки |
| `invoice_number` | VARCHAR(30) | NOT NULL | Номер счёта-фактуры |
| `status` | VARCHAR(20) | CHECK, DEFAULT | оформлена / принята / отменена |
| `total_amount` | NUMERIC(14,2) | CHECK >= 0 | Сумма документа, поддерживается триггером |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Дата создания |

### 2.7 `delivery_items`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_delivery_item` | BIGSERIAL | PK | Ключ позиции |
| `id_delivery` | INTEGER | FK → deliveries | Документ поставки |
| `line_no` | SMALLINT | UNIQUE(delivery,line), CHECK > 0 | Номер строки |
| `id_product` | INTEGER | FK → products | Продукт |
| `id_tank` | INTEGER | FK → tanks | Резервуар приёмки |
| `volume` | NUMERIC(12,3) | CHECK > 0 | Объём, л |
| `price_per_liter` | NUMERIC(10,2) | CHECK >= 0 | Цена, руб./л |
| `total_cost` | NUMERIC(14,2) | GENERATED STORED | Стоимость позиции |

### 2.8 `shipments`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_shipment` | SERIAL | PK | Суррогатный ключ отгрузки |
| `shipment_number` | VARCHAR(20) | UNIQUE, NOT NULL | Номер документа |
| `id_client` | INTEGER | FK → clients | Клиент |
| `shipment_date` | DATE | NOT NULL | Дата отгрузки |
| `status` | VARCHAR(20) | CHECK, DEFAULT | оформлена / отгружена / отменена |
| `payment_type` | VARCHAR(20) | CHECK, NOT NULL | безналичный / наличный |
| `total_amount` | NUMERIC(14,2) | CHECK >= 0 | Сумма документа |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Дата создания |

### 2.9 `shipment_items`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_shipment_item` | BIGSERIAL | PK | Ключ позиции |
| `id_shipment` | INTEGER | FK → shipments | Документ отгрузки |
| `line_no` | SMALLINT | UNIQUE(shipment,line), CHECK > 0 | Номер строки |
| `id_product` | INTEGER | FK → products | Продукт |
| `id_tank` | INTEGER | FK → tanks | Резервуар отгрузки |
| `volume` | NUMERIC(12,3) | CHECK > 0 | Объём, л |
| `price_per_liter` | NUMERIC(10,2) | CHECK >= 0 | Цена, руб./л |
| `total_cost` | NUMERIC(14,2) | GENERATED STORED | Стоимость позиции |

### 2.10 `stock_movements`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_movement` | BIGSERIAL | PK | Ключ движения |
| `movement_date` | TIMESTAMPTZ | DEFAULT now() | Дата и время операции |
| `id_product` | INTEGER | FK → products | Продукт |
| `id_tank` | INTEGER | FK → tanks | Резервуар |
| `movement_type` | VARCHAR(20) | CHECK | приход / расход / корректировка |
| `volume` | NUMERIC(12,3) | CHECK <> 0 | Объём со знаком |
| `id_delivery_item` | BIGINT | FK → delivery_items, SET NULL | Ссылка на позицию поставки |
| `id_shipment_item` | BIGINT | FK → shipment_items, SET NULL | Ссылка на позицию отгрузки |
| `comment` | VARCHAR(200) | — | Комментарий |

### 2.11 `tank_measurements`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_measurement` | BIGSERIAL | PK | Ключ замера |
| `id_tank` | INTEGER | FK → tanks | Резервуар |
| `measured_at` | TIMESTAMPTZ | UNIQUE(tank,time) | Момент измерения |
| `volume` | NUMERIC(12,3) | CHECK >= 0 | Измеренный объём, л |
| `temperature` | NUMERIC(5,2) | CHECK -50..60 | Температура, °C |
| `density` | NUMERIC(6,2) | CHECK 700..950 | Плотность, кг/м³ |

### 2.12 `reserve_forecasts`

| Атрибут | Тип | Ограничения | Назначение |
|---|---|---|---|
| `id_forecast` | BIGSERIAL | PK | Ключ прогноза |
| `id_product` | INTEGER | FK → products | Продукт |
| `forecast_date` | DATE | UNIQUE(product,date,horizon) | Дата расчёта |
| `horizon_days` | SMALLINT | CHECK 1..365 | Горизонт прогноза |
| `current_stock` | NUMERIC(12,3) | CHECK >= 0 | Остаток на дату расчёта |
| `avg_daily_consumption` | NUMERIC(12,3) | CHECK >= 0 | Среднесуточный расход |
| `predicted_consumption` | NUMERIC(12,3) | CHECK >= 0 | Ожидаемый расход за горизонт |
| `predicted_reserve` | NUMERIC(12,3) | — | Прогнозный остаток (может быть < 0) |
| `method` | VARCHAR(40) | DEFAULT | Методика расчёта |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Дата создания записи |

## 3. Связи и кардинальности

| № | Родительская сущность | Дочерняя сущность | Внешний ключ | Кардинальность | ON DELETE |
|---|---|---|---|---|---|
| 1 | `products` | `tanks` | `id_product` | 1:N | RESTRICT |
| 2 | `products` | `price_history` | `id_product` | 1:N | RESTRICT |
| 3 | `products` | `delivery_items` | `id_product` | 1:N | RESTRICT |
| 4 | `products` | `shipment_items` | `id_product` | 1:N | RESTRICT |
| 5 | `products` | `stock_movements` | `id_product` | 1:N | RESTRICT |
| 6 | `products` | `reserve_forecasts` | `id_product` | 1:N | RESTRICT |
| 7 | `suppliers` | `deliveries` | `id_supplier` | 1:N | RESTRICT |
| 8 | `clients` | `shipments` | `id_client` | 1:N | RESTRICT |
| 9 | `tanks` | `delivery_items` | `id_tank` | 1:N | RESTRICT |
| 10 | `tanks` | `shipment_items` | `id_tank` | 1:N | RESTRICT |
| 11 | `tanks` | `stock_movements` | `id_tank` | 1:N | RESTRICT |
| 12 | `tanks` | `tank_measurements` | `id_tank` | 1:N | RESTRICT |
| 13 | `deliveries` | `delivery_items` | `id_delivery` | 1:N | RESTRICT |
| 14 | `shipments` | `shipment_items` | `id_shipment` | 1:N | RESTRICT |
| 15 | `delivery_items` | `stock_movements` | `id_delivery_item` | 1:0..N | SET NULL |
| 16 | `shipment_items` | `stock_movements` | `id_shipment_item` | 1:0..N | SET NULL |

Связи `1:N` означают, что одной записи родителя соответствует ноль или несколько записей дочерней сущности; для обязательных связей дочерняя запись не может существовать без родителя. Связи `delivery_items → stock_movements` и `shipment_items → stock_movements` имеют кардинальность `1:0..N`: корректировочное движение может не ссылаться на позицию документа, поэтому внешний ключ допускает `NULL`, а при удалении позиции устанавливается `SET NULL`.

## 4. Предполагаемая раскладка диаграммы

Сетка 3 × 4 (слева направо, сверху вниз):

| Колонка 1 | Колонка 2 | Колонка 3 |
|---|---|---|
| `suppliers` | `products` | `clients` |
| `deliveries` | `tanks` | `shipments` |
| `delivery_items` | `price_history` | `shipment_items` |
| `stock_movements` | `reserve_forecasts` | `tank_measurements` |

Связи проводятся ортогонально: вертикальные — между соседними ярусами, длинные — по свободным промежуткам между колонками. Точка ставится у родительского конца, символ `N` — у дочернего. Подпись рисунка в отчёте: «Рисунок 1 – Концептуальная модель IDEF1X (диаграмма подготовлена в нотации IDEF1X; исходный файл — docs/diagrams/idef1x.drawio)».
