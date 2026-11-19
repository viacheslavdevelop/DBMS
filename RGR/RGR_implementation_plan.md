# План реализации РГР по СУБД

## Вариант 17. Автоматизация учёта и прогноза запасов нефтепродуктов, реализуемых нефтебазой

**Документ предназначен для ИИ-агента, который будет выполнять работу под контролем пользователя.**
План описывает целевую модель данных, порядок действий, проверки и критерии приёмки. Все решения, отмеченные как «по умолчанию», можно изменить после согласования с пользователем.

---

## 0. Паспорт плана

| Параметр | Значение |
| :--- | :--- |
| Дисциплина | Системы управления базами данных |
| Вариант | 17 |
| Тема | База данных автоматизации учёта и прогноза запасов нефтепродуктов, реализуемых нефтебазой |
| СУБД | PostgreSQL 18.6 (Homebrew), macOS |
| Рабочая папка | `/Users/admin/University/DBMS/RGR` |
| Имя БД | `oildepotdb` (строчными буквами, как принято в PostgreSQL) |
| Пользователь PostgreSQL | `admin` (суперпользователь, проверено) |
| Источник требований | `RGR_task.md` |
| Пример оформления | `РГР_БД_Сахань.pdf`, `Lab2/Task2/ReportLab2.docx`, `Lab8/ReportLab8.docx` |
| Учебное пособие | `Учебное пособие  #Работа с СУБД PostgreSQL#.pdf` |
| Итоговый отчёт | `docs/ReportRGR.docx` + `docs/ReportRGR.pdf` |
| Исходник отчёта | `docs/ReportRGR.md` |
| Статус | План; реализация ещё не начата |

### 0.1. Важное расхождение, которое нужно проверить перед стартом

В `RGR_task.md` явно указан **вариант 17 — нефтебаза и нефтепродукты**.
При этом существующая БД в `Lab2/Task2` — `CinemaDB` (кинотеатр), а в PostgreSQL уже есть база `cinemadb`.

**Решение по умолчанию:** реализовывать именно вариант 17 (`oildepotdb`), не изменяя `cinemadb` и папки `Lab*`.
**Стоп-условие:** если пользователь скажет, что его фактический вариант — кинотеатр, работу остановить и пересогласовать план, так как весь документ построен вокруг нефтебазы.

### 0.2. Что считается готовым результатом

1. Развёрнутая БД `oildepotdb` в PostgreSQL.
2. Не менее 12 таблиц (требование — не менее 5), не менее 15 записей в каждой таблице.
3. Диаграмма IDEF1X (PNG + исходник) и физическая ER-диаграмма БД.
4. SQL-скрипты DDL, индексов, наполнения, запросов, объектов и тестов.
5. 23 запроса по таблице 1 задания, каждый — с формулировкой, SQL и скриншотом.
6. 2 материализованных представления, 2 курсора, 1 функция, 1 процедура, 2 триггера.
7. Отчёт `ReportRGR.docx`/`.pdf` со всеми разделами, рисунками, таблицами и приложениями.
8. Скрипт приёмки `99_acceptance.sql`, который завершается сообщением об успешной проверке.

---

## 1. Цель и общая стратегия

**Цель:** реализовать учебную БД нефтебазы, которая автоматизирует учёт поступления, хранения и отгрузки нефтепродуктов, контроль минимальных запасов и прогнозирование расхода, а также подготовить полный отчёт по РГР.

**Стратегия:**

1. Сначала зафиксировать предметную область и бизнес-правила, чтобы схема не переделывалась на этапе запросов.
2. Спроектировать нормализованную модель (3НФ/BCNF) с осознанной контролируемой избыточностью: `tanks.current_volume` и `deliveries.total_amount`/`shipments.total_amount` — кэшируемые агрегаты, которые поддерживаются триггерами.
3. Реализовать схему в PostgreSQL с ограничениями целостности, индексами и генерацией данных.
4. Сначала создать объекты БД и триггеры, затем наполнять таблицы — чтобы движения топлива и итоговые суммы документов формировались автоматически.
5. Каждый запрос сохранять отдельным файлом и сразу фиксировать результат, чтобы к концу работы не собирать скриншоты задним числом.
6. Отчёт собирать параллельно с реализацией: после каждого этапа добавлять соответствующий раздел и рисунки.

**Порядок выполнения фаз:**

```
P0 Подготовка → P1 Предметная область → P2 IDEF1X → P3 Логическая модель и нормализация
→ P4 DDL и индексы → P5 Объекты БД и триггеры → P6 Наполнение → P7 Запросы
→ P8 Целостность и точность → P9 Тестирование → P10 Отчёт и упаковка
```

---

## 2. Требования задания и трассировка

### 2.1. Таблица соответствия требованиям

| № | Требование `RGR_task.md` | Что делаем | Где проверяется |
| :--- | :--- | :--- | :--- |
| 1 | Краткое описание предметной области | Раздел 1 отчёта: процессы, участники, документы, бизнес-правила | Раздел 1 отчёта |
| 2 | Концептуальное проектирование | IDEF1X-диаграмма, сущности, атрибуты, связи, кардинальности | `docs/diagrams/idef1x.png`, раздел 2 |
| 3 | Логическое проектирование | Реляционная схема, словарь данных, нормализация до 3НФ/BCNF | Раздел 3 отчёта |
| 4 | Реализация в PostgreSQL | DDL 12 таблиц, типы, PK/FK, CHECK, ER-диаграмма | `sql/01_schema.sql`, раздел 4 |
| 5 | Индексы | 16+ индексов с обоснованием, `EXPLAIN ANALYZE` | `sql/02_indexes.sql`, раздел 4 |
| 6 | Данные | Не менее 15 записей в каждой из 12 таблиц | `sql/05_seed.sql`, проверочные запросы |
| 7 | Запросы | 23 запроса по таблице 1 | `sql/queries/q01.sql` … `q23.sql`, раздел 5 |
| 8 | Ссылочная и семантическая целостность | PK, FK, UNIQUE, CHECK, NOT NULL, триггеры, негативные тесты | `sql/01_schema.sql`, `sql/04_triggers.sql`, раздел 6 |
| 9 | Точность расчётных данных | NUMERIC с явной точностью/масштабом, ROUND, запрет FLOAT для денег и объёмов | Раздел 6.4 |
| 10 | Объекты БД | 2 materialized view, 2 курсора, 1 функция, 1 процедура, 2 триггера | `sql/03_functions.sql`, `sql/04_triggers.sql`, `sql/06_matviews.sql`, раздел 7 |
| 11 | Формулировки и SQL объектов | Описание каждого объекта + скрипт + скриншот | Раздел 7 отчёта |
| 12 | Оформление | DOCX/PDF, титульный лист, рисунки, таблицы, приложения | `docs/ReportRGR.docx` |

### 2.2. Обязательные количественные минимумы

| Показатель | Требование | План | Запас |
| :--- | :---: | :---: | :---: |
| Таблицы | ≥ 5 | 12 | +7 |
| Записи в каждой таблице | ≥ 15 | ≥ 15 | — |
| Запросы | 23 (по таблице 1) | 23 | — |
| Материализованные представления | 2 | 2 | — |
| Курсоры | 2 | 2 | — |
| Функции | 1 | 1 | — |
| Процедуры | 1 | 1 | — |
| Триггеры | 2 | 2 | — |
| Индексы | не задано | 16+ | — |

---

## 3. Допущения, решения по умолчанию и открытые вопросы

### 3.1. Решения по умолчанию

| Вопрос | Решение по умолчанию | Почему |
| :--- | :--- | :--- |
| Вариант | Нефтебаза, вариант 17 | Так указано в `RGR_task.md` |
| Имя БД | `oildepotdb` | Строчные буквы, не конфликтует с `cinemadb` |
| Схема | `public` | Проще для учебного отчёта и скриншотов |
| Идентификаторы | Английские `snake_case`, данные — русские | Как в `Lab2`: `Clients`, `id_client`, статусы на русском |
| Суррогатные ключи | `SERIAL`/`BIGSERIAL` + `UNIQUE` на естественные ключи | Соответствует стилю предыдущих лабораторных |
| Даты | `DATE` для бизнес-дат, `TIMESTAMPTZ` для событий | Разделение учётной и технической дат |
| Деньги | `NUMERIC(14,2)` | Точность до копейки, без ошибок FLOAT |
| Объёмы | `NUMERIC(12,3)` | Точность до 0,001 л |
| Плотность | `NUMERIC(6,2)` | 0,01 кг/м³ |
| Отчёт | `ReportRGR.docx` + PDF, исходник Markdown | Как в предыдущих работах |
| Скриншоты | pgAdmin 4 Query Tool + терминал | Установлен pgAdmin 4; показывает SQL и результат |
| IDEF1X | Visual Paradigm (установлен) или draw.io | Нужен инструмент, поддерживающий IDEF1X; см. риск R-06 |
| Титульный лист | Взять шаблон из `ReportLab2.docx` | Сохранить стиль и данные студента |

### 3.2. Что нужно уточнить у пользователя до начала P1

1. **Вариант.** Подтвердить, что нужен именно вариант 17 (нефтебаза), а не кинотеатр из `cinemadb`.
2. **Титульный лист.** ФИО преподавателя, полное название вуза/кафедры, номер группы (в шаблоне есть `Сахань В.С.`, `ФИТ-242`).
3. **Формат отчёта.** DOCX + PDF достаточно? Нужен ли конкретный объём страниц?
4. **Скриншоты.** Делать в pgAdmin 4 или в терминале `psql`? От этого зависит единый стиль рисунков.
5. **IDEF1X.** Есть ли требование к конкретной среде (ERwin, Visual Paradigm, draw.io)? Если нет — использовать Visual Paradigm.
6. **Данные.** Нужны ли реальные названия поставщиков/клиентов или вымышленные допустимы? По умолчанию — вымышленные, но правдоподобные.
7. **Дедлайн и приоритет.** Если времени мало, сначала обязательный минимум, затем «улучшения» (дополнительные запросы, concurrency-тест).

### 3.3. Стоп-условия для агента

Агент обязан остановиться и задать вопрос, если:

- обнаружилось, что вариант в задании не соответствует варианту 17;
- требуется изменить существующие папки `Lab*` или базу `cinemadb`;
- преподаватель требует другую нотацию/СУБД/формат отчёта;
- для выполнения нужны права, которых нет у пользователя `admin`;
- данные из примера (`РГР_БД_Сахань.pdf`) противоречат заданию.

---

## 4. Архитектура решения и структура файлов

### 4.1. Схема работы

```
PostgreSQL 18.6
  └── oildepotdb
        ├── 12 таблиц (справочники, документы, регистр движений, прогнозы)
        ├── 16+ индексов
        ├── 2 материализованных представления
        ├── 1 функция + 1 процедура (в каждой — курсор)
        ├── 2 триггера (приход/расход, контроль остатков)
        └── тесты и скрипт приёмки

RGR/
  ├── RGR_task.md
  ├── RGR_implementation_plan.md      ← этот файл
  ├── sql/
  │   ├── 00_create_db.sql
  │   ├── 01_schema.sql
  │   ├── 02_indexes.sql
  │   ├── 03_functions.sql
  │   ├── 04_triggers.sql
  │   ├── 05_seed.sql
  │   ├── 06_matviews.sql
  │   ├── 07_queries.sql
  │   ├── 08_tests.sql
  │   ├── 99_acceptance.sql
  │   └── queries/
  │       ├── q01.sql … q23.sql
  ├── docs/
  │   ├── ReportRGR.md
  │   ├── ReportRGR.docx
  │   ├── ReportRGR.pdf
  │   ├── build_report.py
  │   ├── PROGRESS.md
  │   ├── diagrams/
  │   │   ├── idef1x.png
  │   │   ├── idef1x.drawio
  │   │   ├── physical_erd.png
  │   │   └── idef1x_spec.md
  │   └── screenshots/
  │       ├── fig_01_idef1x.png
  │       ├── fig_q01.png … fig_q23.png
  │       ├── fig_mv_product_stock.png, fig_mv_monthly_sales.png, fig_refresh_mv.png
  │       ├── fig_fn_forecast.png, fig_proc_forecasts.png
  │       └── fig_trigger_ok.png, fig_trigger_err.png
  ├── results/
  │   ├── q01.txt … q23.txt
  │   ├── tests.txt
  │   └── acceptance.txt
  └── templates/
      └── ReportTemplate.docx          ← копия ReportLab2.docx для стиля
```

### 4.2. Соглашения об именовании

- Таблицы — во множественном числе, `snake_case`: `products`, `delivery_items`.
- Первичные ключи — `id_<сущность>`: `id_product`, `id_delivery`.
- Внешние ключи — совпадают с PK родителя: `id_product`, `id_tank`.
- Булевы — `is_active`.
- Даты — `_date`, моменты времени — `_at`.
- Статусы и категории — `VARCHAR` + `CHECK`, значения на русском.
- SQL-файлы — с префиксами порядка выполнения.
- Рисунки — `fig_<номер>_<краткое_имя>.png`; подписи в отчёте — `Рисунок N – ...`.

### 4.3. Команды выполнения

```bash
cd /Users/admin/University/DBMS/RGR

psql -d postgres -v ON_ERROR_STOP=1 -f sql/00_create_db.sql
psql -d oildepotdb -v ON_ERROR_STOP=1 -f sql/01_schema.sql
psql -d oildepotdb -v ON_ERROR_STOP=1 -f sql/02_indexes.sql
psql -d oildepotdb -v ON_ERROR_STOP=1 -f sql/03_functions.sql
psql -d oildepotdb -v ON_ERROR_STOP=1 -f sql/04_triggers.sql
psql -d oildepotdb -v ON_ERROR_STOP=1 -f sql/05_seed.sql
psql -d oildepotdb -v ON_ERROR_STOP=1 -f sql/06_matviews.sql
psql -d oildepotdb -v ON_ERROR_STOP=1 -f sql/07_queries.sql
psql -d oildepotdb -f sql/08_tests.sql   # ошибки ожидаемы; см. 10.5
psql -d oildepotdb -v ON_ERROR_STOP=1 -f sql/99_acceptance.sql
```

Для скриншотов:

```bash
psql -d oildepotdb -P pager=off -P border=2 -P null='(null)' -f sql/queries/q01.sql
```

### 4.4. Правила работы агента

1. Работать только в `/Users/admin/University/DBMS/RGR`; не менять `Lab*` и `cinemadb`.
2. Все изменения схемы — только через файлы в `sql/`; не «дописывать» БД вручную без обновления скрипта.
3. Каждый скрипт запускать с `ON_ERROR_STOP=1`; при ошибке — исправлять скрипт и перезапускать с чистой БД, а не маскировать ошибку.
4. SQL-скрипты — без пояснительных комментариев (как в предыдущих лабораторных); все пояснения — в отчёте.
5. Русские строковые значения — в UTF-8; перед запуском `SET client_encoding = 'UTF8';`.
6. После каждой фазы обновлять `docs/PROGRESS.md` и показывать пользователю краткий отчёт: что сделано, какие файлы, какие проверки прошли.
7. Не выдумывать результаты и скриншоты: все рисунки — из реального выполнения SQL.
8. Если запрос возвращает пустой результат, сначала проверить данные; калибровать наполнение, а не подменять условие запроса.
9. Для негативных тестов использовать транзакцию с `ROLLBACK`, чтобы не портить данные.
10. Перед финальной сдачей — прогнать `99_acceptance.sql` на чистой БД с нуля.

### 4.5. Формат `docs/PROGRESS.md`

```markdown
# Прогресс реализации РГР

| Фаза | Статус | Артефакты | Проверки | Замечания |
| :--- | :--- | :--- | :--- | :--- |
| P0 | ✅ | план, структура папок | psql доступен | — |
| P1 | ⏳ | раздел 1 отчёта | бизнес-правила согласованы | — |
```

Статусы: `⏳` — в работе, `✅` — готово, `⚠️` — есть риск, `⛔` — заблокировано.
---

## 5. Целевая модель данных

### 5.1. Состав таблиц

| № | Таблица | Назначение | Тип |
| :---: | :--- | :--- | :--- |
| 1 | `products` | Справочник нефтепродуктов: марка, категория, плотность, минимальный запас | Справочник |
| 2 | `tanks` | Резервуары: номер, ёмкость, текущий остаток, закреплённый продукт | Справочник/состояние |
| 3 | `suppliers` | Поставщики нефтепродуктов | Справочник |
| 4 | `clients` | Покупатели (оптовые и розничные) | Справочник |
| 5 | `price_history` | История закупочных и розничных цен по продуктам | История |
| 6 | `deliveries` | Документы поступления (прихода) | Документ |
| 7 | `delivery_items` | Позиции поставки: продукт, резервуар, объём, цена | Документ |
| 8 | `shipments` | Документы отгрузки (расхода) | Документ |
| 9 | `shipment_items` | Позиции отгрузки: продукт, резервуар, объём, цена | Документ |
| 10 | `stock_movements` | Регистр движений топлива (приход/расход/корректировка) | Регистр |
| 11 | `tank_measurements` | Замеры остатков и параметров топлива в резервуарах | История |
| 12 | `reserve_forecasts` | Прогнозы расхода и остатка по продуктам | Расчёт |

### 5.2. Словарь данных

#### 5.2.1. `products` — нефтепродукты

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_product` | `SERIAL` | `PRIMARY KEY` | Идентификатор |
| `product_code` | `VARCHAR(10)` | `NOT NULL`, `UNIQUE` | Код марки: `АИ-92`, `АИ-95`, `ДТ-Л`, `М-100` |
| `name` | `VARCHAR(60)` | `NOT NULL` | Полное наименование |
| `category` | `VARCHAR(30)` | `NOT NULL`, `CHECK (category IN ('бензин','дизельное топливо','мазут','масло'))` | Категория |
| `octane_rating` | `SMALLINT` | `NULL`, `CHECK (octane_rating BETWEEN 80 AND 100)` | Октановое число; обязательно для бензина |
| `density` | `NUMERIC(6,2)` | `NOT NULL`, `CHECK (density BETWEEN 700 AND 950)` | Плотность, кг/м³ |
| `min_reserve` | `NUMERIC(12,3)` | `NOT NULL`, `CHECK (min_reserve >= 0)` | Минимальный нормативный запас, л |
| `is_active` | `BOOLEAN` | `NOT NULL DEFAULT TRUE` | Признак актуальности |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Дата создания записи |

Дополнительное ограничение:

```sql
CHECK (category <> 'бензин' OR octane_rating IS NOT NULL)
```

#### 5.2.2. `tanks` — резервуары

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_tank` | `SERIAL` | `PRIMARY KEY` | Идентификатор |
| `tank_number` | `VARCHAR(10)` | `NOT NULL`, `UNIQUE` | Номер резервуара: `Р-01` |
| `capacity` | `NUMERIC(12,3)` | `NOT NULL`, `CHECK (capacity > 0)` | Полная ёмкость, л |
| `current_volume` | `NUMERIC(12,3)` | `NOT NULL DEFAULT 0`, `CHECK (current_volume >= 0)` | Текущий остаток, л |
| `id_product` | `INTEGER` | `NOT NULL`, FK → `products` | Хранимый продукт |
| `status` | `VARCHAR(20)` | `NOT NULL DEFAULT 'в эксплуатации'`, `CHECK (status IN ('в эксплуатации','на ремонте','выведен'))` | Состояние |
| `commissioned_date` | `DATE` | `NOT NULL` | Дата ввода в эксплуатацию |

Дополнительное ограничение:

```sql
CHECK (current_volume <= capacity)
```

#### 5.2.3. `suppliers` — поставщики

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_supplier` | `SERIAL` | `PRIMARY KEY` | Идентификатор |
| `name` | `VARCHAR(100)` | `NOT NULL`, `UNIQUE` | Наименование организации |
| `inn` | `VARCHAR(12)` | `NOT NULL`, `UNIQUE`, `CHECK (inn ~ '^[0-9]{10}([0-9]{2})?$')` | ИНН: 10 или 12 цифр |
| `phone` | `VARCHAR(20)` | `NOT NULL` | Телефон |
| `contact_person` | `VARCHAR(100)` | `NULL` | Контактное лицо |
| `is_active` | `BOOLEAN` | `NOT NULL DEFAULT TRUE` | Признак актуальности |

#### 5.2.4. `clients` — покупатели

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_client` | `SERIAL` | `PRIMARY KEY` | Идентификатор |
| `name` | `VARCHAR(100)` | `NOT NULL` | Наименование |
| `client_type` | `VARCHAR(20)` | `NOT NULL`, `CHECK (client_type IN ('оптовый','розничный'))` | Тип покупателя |
| `inn` | `VARCHAR(12)` | `NOT NULL`, `UNIQUE`, `CHECK (inn ~ '^[0-9]{10}([0-9]{2})?$')` | ИНН |
| `phone` | `VARCHAR(20)` | `NULL` | Телефон |
| `contract_number` | `VARCHAR(30)` | `NOT NULL`, `UNIQUE` | Номер договора |
| `contract_date` | `DATE` | `NOT NULL` | Дата договора |
| `is_active` | `BOOLEAN` | `NOT NULL DEFAULT TRUE` | Признак актуальности |

#### 5.2.5. `price_history` — история цен

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_price` | `BIGSERIAL` | `PRIMARY KEY` | Идентификатор |
| `id_product` | `INTEGER` | `NOT NULL`, FK → `products` | Продукт |
| `effective_date` | `DATE` | `NOT NULL` | Дата действия цены |
| `purchase_price` | `NUMERIC(10,2)` | `NOT NULL`, `CHECK (purchase_price >= 0)` | Закупочная цена, руб./л |
| `retail_price` | `NUMERIC(10,2)` | `NOT NULL`, `CHECK (retail_price >= 0)` | Розничная цена, руб./л |

Ограничения:

```sql
UNIQUE (id_product, effective_date)
CHECK (retail_price >= purchase_price)
```

#### 5.2.6. `deliveries` — поставки

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_delivery` | `SERIAL` | `PRIMARY KEY` | Идентификатор |
| `delivery_number` | `VARCHAR(20)` | `NOT NULL`, `UNIQUE` | Номер документа |
| `id_supplier` | `INTEGER` | `NOT NULL`, FK → `suppliers` | Поставщик |
| `delivery_date` | `DATE` | `NOT NULL` | Дата поставки |
| `invoice_number` | `VARCHAR(30)` | `NOT NULL` | Номер счёта-фактуры |
| `status` | `VARCHAR(20)` | `NOT NULL DEFAULT 'оформлена'`, `CHECK (status IN ('оформлена','принята','отменена'))` | Статус |
| `total_amount` | `NUMERIC(14,2)` | `NOT NULL DEFAULT 0`, `CHECK (total_amount >= 0)` | Сумма документа (кэш) |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Дата создания |

Дополнительные ограничения:

```sql
CHECK (status <> 'принята' OR total_amount > 0)
CHECK (status <> 'отменена' OR total_amount = 0)
```

#### 5.2.7. `delivery_items` — позиции поставки

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_delivery_item` | `BIGSERIAL` | `PRIMARY KEY` | Идентификатор |
| `id_delivery` | `INTEGER` | `NOT NULL`, FK → `deliveries` | Документ |
| `line_no` | `SMALLINT` | `NOT NULL`, `CHECK (line_no > 0)` | Номер строки |
| `id_product` | `INTEGER` | `NOT NULL`, FK → `products` | Продукт |
| `id_tank` | `INTEGER` | `NOT NULL`, FK → `tanks` | Резервуар |
| `volume` | `NUMERIC(12,3)` | `NOT NULL`, `CHECK (volume > 0)` | Объём, л |
| `price_per_liter` | `NUMERIC(10,2)` | `NOT NULL`, `CHECK (price_per_liter >= 0)` | Цена, руб./л |
| `total_cost` | `NUMERIC(14,2)` | `GENERATED ALWAYS AS (ROUND(volume * price_per_liter, 2)) STORED` | Стоимость строки |

Ограничение:

```sql
UNIQUE (id_delivery, line_no)
```

#### 5.2.8. `shipments` — отгрузки

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_shipment` | `SERIAL` | `PRIMARY KEY` | Идентификатор |
| `shipment_number` | `VARCHAR(20)` | `NOT NULL`, `UNIQUE` | Номер документа |
| `id_client` | `INTEGER` | `NOT NULL`, FK → `clients` | Покупатель |
| `shipment_date` | `DATE` | `NOT NULL` | Дата отгрузки |
| `status` | `VARCHAR(20)` | `NOT NULL DEFAULT 'оформлена'`, `CHECK (status IN ('оформлена','отгружена','отменена'))` | Статус |
| `payment_type` | `VARCHAR(20)` | `NOT NULL`, `CHECK (payment_type IN ('безналичный','наличный'))` | Форма оплаты |
| `total_amount` | `NUMERIC(14,2)` | `NOT NULL DEFAULT 0`, `CHECK (total_amount >= 0)` | Сумма документа (кэш) |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Дата создания |

Дополнительные ограничения:

```sql
CHECK (status <> 'отгружена' OR total_amount > 0)
CHECK (status <> 'отменена' OR total_amount = 0)
```

#### 5.2.9. `shipment_items` — позиции отгрузки

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_shipment_item` | `BIGSERIAL` | `PRIMARY KEY` | Идентификатор |
| `id_shipment` | `INTEGER` | `NOT NULL`, FK → `shipments` | Документ |
| `line_no` | `SMALLINT` | `NOT NULL`, `CHECK (line_no > 0)` | Номер строки |
| `id_product` | `INTEGER` | `NOT NULL`, FK → `products` | Продукт |
| `id_tank` | `INTEGER` | `NOT NULL`, FK → `tanks` | Резервуар |
| `volume` | `NUMERIC(12,3)` | `NOT NULL`, `CHECK (volume > 0)` | Объём, л |
| `price_per_liter` | `NUMERIC(10,2)` | `NOT NULL`, `CHECK (price_per_liter >= 0)` | Цена, руб./л |
| `total_cost` | `NUMERIC(14,2)` | `GENERATED ALWAYS AS (ROUND(volume * price_per_liter, 2)) STORED` | Стоимость строки |

Ограничение:

```sql
UNIQUE (id_shipment, line_no)
```

#### 5.2.10. `stock_movements` — регистр движений

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_movement` | `BIGSERIAL` | `PRIMARY KEY` | Идентификатор |
| `movement_date` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Момент движения |
| `id_product` | `INTEGER` | `NOT NULL`, FK → `products` | Продукт |
| `id_tank` | `INTEGER` | `NOT NULL`, FK → `tanks` | Резервуар |
| `movement_type` | `VARCHAR(20)` | `NOT NULL`, `CHECK (movement_type IN ('приход','расход','корректировка'))` | Тип |
| `volume` | `NUMERIC(12,3)` | `NOT NULL`, `CHECK (volume <> 0)` | Знаковый объём: `+` приход, `−` расход |
| `id_delivery_item` | `BIGINT` | `NULL`, FK → `delivery_items` `ON DELETE SET NULL` | Ссылка на позицию поставки |
| `id_shipment_item` | `BIGINT` | `NULL`, FK → `shipment_items` `ON DELETE SET NULL` | Ссылка на позицию отгрузки |
| `comment` | `VARCHAR(200)` | `NULL` | Комментарий |

Ограничения:

```sql
CHECK (num_nonnulls(id_delivery_item, id_shipment_item) <= 1)
CHECK (
    (movement_type = 'приход' AND volume > 0) OR
    (movement_type = 'расход' AND volume < 0) OR
    (movement_type = 'корректировка' AND volume <> 0)
)
```

#### 5.2.11. `tank_measurements` — замеры

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_measurement` | `BIGSERIAL` | `PRIMARY KEY` | Идентификатор |
| `id_tank` | `INTEGER` | `NOT NULL`, FK → `tanks` | Резервуар |
| `measured_at` | `TIMESTAMPTZ` | `NOT NULL` | Момент замера |
| `volume` | `NUMERIC(12,3)` | `NOT NULL`, `CHECK (volume >= 0)` | Измеренный объём, л |
| `temperature` | `NUMERIC(5,2)` | `NULL`, `CHECK (temperature BETWEEN -50 AND 60)` | Температура, °C |
| `density` | `NUMERIC(6,2)` | `NULL`, `CHECK (density BETWEEN 700 AND 950)` | Плотность, кг/м³ |

Ограничение:

```sql
UNIQUE (id_tank, measured_at)
```

#### 5.2.12. `reserve_forecasts` — прогнозы

| Поле | Тип | Ограничения | Назначение |
| :--- | :--- | :--- | :--- |
| `id_forecast` | `BIGSERIAL` | `PRIMARY KEY` | Идентификатор |
| `id_product` | `INTEGER` | `NOT NULL`, FK → `products` | Продукт |
| `forecast_date` | `DATE` | `NOT NULL` | Дата расчёта |
| `horizon_days` | `SMALLINT` | `NOT NULL`, `CHECK (horizon_days BETWEEN 1 AND 365)` | Горизонт прогноза |
| `current_stock` | `NUMERIC(12,3)` | `NOT NULL`, `CHECK (current_stock >= 0)` | Остаток на дату расчёта |
| `avg_daily_consumption` | `NUMERIC(12,3)` | `NOT NULL`, `CHECK (avg_daily_consumption >= 0)` | Средний суточный расход |
| `predicted_consumption` | `NUMERIC(12,3)` | `NOT NULL`, `CHECK (predicted_consumption >= 0)` | Прогноз расхода |
| `predicted_reserve` | `NUMERIC(12,3)` | `NOT NULL` | Прогноз остатка (может быть отрицательным) |
| `method` | `VARCHAR(40)` | `NOT NULL DEFAULT 'средний расход за 30 дней'` | Метод |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Дата создания |

Ограничение:

```sql
UNIQUE (id_product, forecast_date, horizon_days)
```

### 5.3. Бизнес-правила

| Код | Правило | Где реализуется |
| :--- | :--- | :--- |
| BR-01 | Каждый резервуар хранит ровно один продукт; продукт может храниться в нескольких резервуарах | FK `tanks.id_product`, проверка в триггерах |
| BR-02 | Объём в резервуаре не может быть отрицательным или превышать ёмкость | `CHECK`, триггеры |
| BR-03 | Поставка зачисляется только в резервуар, закреплённый за этим продуктом | Триггер прихода |
| BR-04 | Отгрузка возможна только из резервуара с этим продуктом и при достаточном остатке | Триггер расхода, `FOR UPDATE` |
| BR-05 | Цены неотрицательны; розничная цена не ниже закупочной | `CHECK` |
| BR-06 | Стоимость строки = объём × цена; сумма документа = сумма строк | Генерируемый столбец, триггеры |
| BR-07 | Регистр движений append-only: приложение не редактирует старые строки, исправления оформляются новой строкой; при удалении позиции ссылка обнуляется (`SET NULL`) | Регламент, `ON DELETE SET NULL`, тесты |
| BR-08 | Позиции можно добавлять/менять только у документа в статусе `оформлена` | Триггеры |
| BR-09 | Документы с позициями не удаляются; сначала удаляются позиции | FK `ON DELETE RESTRICT` |
| BR-10 | Дефицит — остаток продукта ниже `min_reserve` | Запросы, материализованное представление |
| BR-11 | Прогноз строится по среднему расходу за последние 30 дней на горизонт 1–365 дней | Функция, процедура |
| BR-12 | Точность объёмов — 0,001 л, денег — 0,01 руб. | Типы `NUMERIC` |
| BR-13 | ИНН содержит 10 или 12 цифр | `CHECK` с регулярным выражением |
| BR-14 | Для бензина обязательно указано октановое число | `CHECK` |
| BR-15 | Статусы документов ограничены перечислениями | `CHECK` |
| BR-16 | Отмена документа допускается только из статуса `оформлена` и только после удаления всех позиций; проведённые документы (`принята`/`отгружена`) не отменяются — исправление оформляется новым документом | BR-09, `CHECK` статуса/суммы, триггеры позиций |
| BR-17 | Все движения фиксируются с привязкой к позиции документа или как корректировка | `stock_movements` |
| BR-18 | Остаток в резервуаре должен совпадать с суммой движений | Проверка сходимости |
| BR-19 | Замеры не влияют на учётный остаток; расхождения анализируются отдельно | `tank_measurements` |
| BR-20 | Продукты и контрагенты не удаляются, а деактивируются (`is_active = FALSE`) | `ON DELETE RESTRICT`, `is_active` |

### 5.4. Связи и ссылочные действия

| Родитель | Дочерняя таблица | Кардинальность | FK | `ON DELETE` | `ON UPDATE` |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `products` | `tanks` | 1 : 0..N | `id_product` | `RESTRICT` | `CASCADE` |
| `products` | `price_history` | 1 : 0..N | `id_product` | `RESTRICT` | `CASCADE` |
| `products` | `delivery_items` | 1 : 0..N | `id_product` | `RESTRICT` | `CASCADE` |
| `products` | `shipment_items` | 1 : 0..N | `id_product` | `RESTRICT` | `CASCADE` |
| `products` | `stock_movements` | 1 : 0..N | `id_product` | `RESTRICT` | `CASCADE` |
| `products` | `reserve_forecasts` | 1 : 0..N | `id_product` | `RESTRICT` | `CASCADE` |
| `suppliers` | `deliveries` | 1 : 0..N | `id_supplier` | `RESTRICT` | `CASCADE` |
| `clients` | `shipments` | 1 : 0..N | `id_client` | `RESTRICT` | `CASCADE` |
| `tanks` | `delivery_items` | 1 : 0..N | `id_tank` | `RESTRICT` | `CASCADE` |
| `tanks` | `shipment_items` | 1 : 0..N | `id_tank` | `RESTRICT` | `CASCADE` |
| `tanks` | `stock_movements` | 1 : 0..N | `id_tank` | `RESTRICT` | `CASCADE` |
| `tanks` | `tank_measurements` | 1 : 0..N | `id_tank` | `RESTRICT` | `CASCADE` |
| `deliveries` | `delivery_items` | 1 : 1..N | `id_delivery` | `RESTRICT` | `CASCADE` |
| `shipments` | `shipment_items` | 1 : 1..N | `id_shipment` | `RESTRICT` | `CASCADE` |
| `delivery_items` | `stock_movements` | 0..1 : 0..N | `id_delivery_item` | `SET NULL` | `CASCADE` |
| `shipment_items` | `stock_movements` | 0..1 : 0..N | `id_shipment_item` | `SET NULL` | `CASCADE` |

**Почему `RESTRICT`, а не `CASCADE` для документов:** удаление поставки/отгрузки с позициями должно сначала вернуть топливо в резервуар (через удаление позиций и триггеры). Каскадное удаление позиций могло бы выполнить триггеры в момент удаления родителя и создать трудноуловимые эффекты. Политика «сначала позиции, потом документ» описана в BR-09 и проверяется тестом.

**Почему `SET NULL` для движений:** регистр движений — аудит. Если позиция документа удаляется, историческое движение должно остаться, но ссылка на удалённую строку обнуляется. Это осознанное исключение; в отчёте оно объясняется.

### 5.5. Контролируемая избыточность

В схеме есть три кэшируемых агрегата:

| Агрегат | Источник истины | Кто поддерживает | Проверка |
| :--- | :--- | :--- | :--- |
| `tanks.current_volume` | `SUM(stock_movements.volume)` по резервуару | Триггеры прихода/расхода + начальные корректировки | Запрос сходимости |
| `deliveries.total_amount` | `SUM(delivery_items.total_cost)` | Триггер позиций поставки | Сверка сумм |
| `shipments.total_amount` | `SUM(shipment_items.total_cost)` | Триггер позиций отгрузки | Сверка сумм |

Это **не нарушение 3НФ**, а осознанная материализация агрегатов для производительности отчётов и удобства запросов. Условия корректности:

1. Прямые `INSERT/UPDATE` этих полей вручную запрещены (кроме начального наполнения и служебных скриптов).
2. Все изменения объёмов идут через позиции документов и триггеры.
3. В `08_tests.sql` есть запросы сходимости, которые должны возвращать 0 строк.
4. В отчёте раздел нормализации явно называет эти поля «контролируемой избыточностью» и обосновывает её.

Запрос сходимости остатков:

```sql
SELECT t.id_tank, t.tank_number, t.current_volume,
       COALESCE(SUM(m.volume), 0) AS ledger_volume,
       t.current_volume - COALESCE(SUM(m.volume), 0) AS diff
FROM tanks t
LEFT JOIN stock_movements m ON m.id_tank = t.id_tank
GROUP BY t.id_tank, t.tank_number, t.current_volume
HAVING t.current_volume <> COALESCE(SUM(m.volume), 0);
```

### 5.6. Жизненный цикл документов

**Поставка:**

```
оформлена → (добавляются позиции, остаток растёт, движения «приход») → принята
     ↓
  отменена (только из «оформлена», после удаления всех позиций)
```

**Отгрузка:**

```
оформлена → (добавляются позиции, остаток уменьшается, движения «расход») → отгружена
     ↓
  отменена (только из «оформлена», после удаления всех позиций)
```

Правила:

- Пока документ в статусе `оформлена`, позиции можно добавлять, изменять и удалять.
- В статусах `принята`/`отгружена` позиции read-only; триггеры выбрасывают исключение.
- Отмена — административная операция только для `оформлена`: сначала удаляются позиции (триггеры возвращают остаток), затем статус меняется на `отменена`. `CHECK` не даст отменить документ с ненулевой суммой, то есть с позициями.
- Проведённые документы не удаляются и не отменяются; исправление оформляется новым документом (сторно или корректировка). Документ с позициями нельзя перевести в `отменена`, а проведённый документ не может иметь нулевую сумму.
- Для демонстрации в данных будет хотя бы одна отменённая отгрузка без позиций и один клиент без отменённых отгрузок (для запросов с `NOT EXISTS`).
---

## 6. Этап P2. Концептуальное проектирование (IDEF1X)

### 6.1. Сущности и связи

**Сущности:**

| Сущность | Тип по IDEF1X | Ключ | Комментарий |
| :--- | :--- | :--- | :--- |
| `products` | Независимая | `id_product` | Справочник марок топлива |
| `suppliers` | Независимая | `id_supplier` | Поставщики |
| `clients` | Независимая | `id_client` | Покупатели |
| `tanks` | Независимая | `id_tank` | Резервуары; FK на продукт не входит в PK |
| `price_history` | Зависимая (по смыслу) / независимая по PK | `id_price` | История цен |
| `deliveries` | Независимая | `id_delivery` | Заголовок поставки |
| `delivery_items` | Зависимая (по смыслу) / независимая по PK | `id_delivery_item` | Позиции поставки |
| `shipments` | Независимая | `id_shipment` | Заголовок отгрузки |
| `shipment_items` | Зависимая (по смыслу) / независимая по PK | `id_shipment_item` | Позиции отгрузки |
| `stock_movements` | Независимая | `id_movement` | Регистр движений |
| `tank_measurements` | Независимая | `id_measurement` | Замеры |
| `reserve_forecasts` | Независимая | `id_forecast` | Прогнозы |

**Связи:**

| Связь | Кардинальность | Обязательность | Тип связи |
| :--- | :---: | :--- | :--- |
| `products` — `tanks` | 1 : 0..N | Продукт у резервуара обязателен | Неидентифицирующая |
| `products` — `price_history` | 1 : 0..N | Продукт обязателен | Неидентифицирующая |
| `suppliers` — `deliveries` | 1 : 0..N | Поставщик обязателен | Неидентифицирующая |
| `clients` — `shipments` | 1 : 0..N | Клиент обязателен | Неидентифицирующая |
| `deliveries` — `delivery_items` | 1 : 1..N | Позиция без поставки невозможна | Неидентифицирующая (суррогатный PK) |
| `shipments` — `shipment_items` | 1 : 1..N | Позиция без отгрузки невозможна | Неидентифицирующая (суррогатный PK) |
| `products` — `delivery_items` | 1 : 0..N | Продукт обязателен | Неидентифицирующая |
| `tanks` — `delivery_items` | 1 : 0..N | Резервуар обязателен | Неидентифицирующая |
| `products` — `shipment_items` | 1 : 0..N | Продукт обязателен | Неидентифицирующая |
| `tanks` — `shipment_items` | 1 : 0..N | Резервуар обязателен | Неидентифицирующая |
| `products` — `stock_movements` | 1 : 0..N | Продукт обязателен | Неидентифицирующая |
| `tanks` — `stock_movements` | 1 : 0..N | Резервуар обязателен | Неидентифицирующая |
| `delivery_items` — `stock_movements` | 0..1 : 0..N | Ссылка необязательна (корректировки) | Неидентифицирующая |
| `shipment_items` — `stock_movements` | 0..1 : 0..N | Ссылка необязательна (корректировки) | Неидентифицирующая |
| `tanks` — `tank_measurements` | 1 : 0..N | Резервуар обязателен | Неидентифицирующая |
| `products` — `reserve_forecasts` | 1 : 0..N | Продукт обязателен | Неидентифицирующая |

### 6.2. Решение по IDEF1X и суррогатным ключам

В модели используются суррогатные первичные ключи (`id_*`) и `UNIQUE`-ограничения на естественные ключи:

- `products.product_code`;
- `tanks.tank_number`;
- `suppliers.name`, `suppliers.inn`;
- `clients.inn`, `clients.contract_number`;
- `price_history (id_product, effective_date)`;
- `deliveries.delivery_number`;
- `delivery_items (id_delivery, line_no)`;
- `shipments.shipment_number`;
- `shipment_items (id_shipment, line_no)`;
- `tank_measurements (id_tank, measured_at)`;
- `reserve_forecasts (id_product, forecast_date, horizon_days)`.

**Как это отражать в IDEF1X:** дочерние сущности существуют только при наличии родителя, но их PK не включает FK родителя, поэтому формально связи неидентифицирующие (пунктирная линия, точка на дочернем конце). Это допустимое проектное решение; в отчёте нужно явно написать, что естественные ключи защищены `UNIQUE`, а суррогатные ключи выбраны для стабильности связей и удобства запросов.

**Альтернатива, если преподаватель требует идентифицирующие связи:** сделать PK позиций составными — `(id_delivery, line_no)`, `(id_shipment, line_no)`, `(id_product, effective_date)`, `(id_tank, measured_at)`, `(id_product, forecast_date, horizon_days)`. Тогда в IDEF1X дочерние сущности будут зависимыми (скруглённые углы), а связи — идентифицирующими (сплошная линия). Менять схему на этом варианте нужно до начала P4; после наполнения — дорого. Решение по умолчанию — суррогатные ключи.

### 6.3. Инструмент и порядок построения диаграммы

**Основной инструмент:** Visual Paradigm (установлен в `/Applications/Visual Paradigm.app`), поддерживает IDEF1X. Если в конкретной версии нотация недоступна — draw.io (diagrams.net) с фигурой IDEF1X, ERwin или другой инструмент, поддерживающий IDEF1X.

**Порядок:**

1. Агент создаёт `docs/diagrams/idef1x_spec.md` — перечень сущностей, атрибутов, связей, кардинальностей и предполагаемую раскладку.
2. Агент создаёт `docs/diagrams/idef1x.drawio` (XML) с 12 сущностями и связями. Это исходник для draw.io/Visual Paradigm.
3. Пользователь открывает файл в выбранном инструменте, проверяет читаемость, при необходимости двигает блоки и экспортирует PNG 300 dpi в `docs/diagrams/idef1x.png`.
4. Если GUI-шаг недоступен, агент строит предварительную SVG/HTML-схему по спецификации, а пользователь переносит её в инструмент. **Не выдавать Mermaid ER-диаграмму за IDEF1X:** Mermaid использует «вороньи лапки», а не IDEF1X.
5. В подписи рисунка указать среду: «Рисунок 2 – Концептуальная модель БД в нотации IDEF1X (Visual Paradigm)».

**Требования к диаграмме:**

- Все 12 сущностей, ключевые атрибуты, связи и кардинальности.
- Читаемость на A4/A3; при необходимости — два листа: «Учёт» (продукты, резервуары, поставки, отгрузки, движения) и «Прогнозирование» (продукты, замеры, прогнозы, цены).
- Отсутствие пересечений линий; ортогональная трассировка.
- Легенда: независимая/зависимая сущность, обязательная/необязательная связь.

### 6.4. Что написать в разделе 2 отчёта

1. Цель концептуального проектирования.
2. Перечень сущностей с назначением.
3. Перечень атрибутов (можно сослаться на словарь данных).
4. Бизнес-правила, влияющие на связи.
5. Описание каждой связи и кардинальности.
6. Скриншот IDEF1X-диаграммы.
7. Указание инструмента и версии.
8. Обоснование суррогатных ключей и неидентифицирующих связей.

---

## 7. Этап P3. Логическое проектирование и нормализация

### 7.1. Реляционная схема (нотация для отчёта)

```
products(id_product PK, product_code UQ, name, category, octane_rating,
         density, min_reserve, is_active, created_at)

tanks(id_tank PK, tank_number UQ, capacity, current_volume,
      id_product FK→products, status, commissioned_date)

suppliers(id_supplier PK, name UQ, inn UQ, phone, contact_person, is_active)

clients(id_client PK, name, client_type, inn UQ, phone,
        contract_number UQ, contract_date, is_active)

price_history(id_price PK, id_product FK→products, effective_date,
              purchase_price, retail_price, UQ(id_product, effective_date))

deliveries(id_delivery PK, delivery_number UQ, id_supplier FK→suppliers,
           delivery_date, invoice_number, status, total_amount, created_at)

delivery_items(id_delivery_item PK, id_delivery FK→deliveries, line_no,
               id_product FK→products, id_tank FK→tanks,
               volume, price_per_liter, total_cost,
               UQ(id_delivery, line_no))

shipments(id_shipment PK, shipment_number UQ, id_client FK→clients,
          shipment_date, status, payment_type, total_amount, created_at)

shipment_items(id_shipment_item PK, id_shipment FK→shipments, line_no,
               id_product FK→products, id_tank FK→tanks,
               volume, price_per_liter, total_cost,
               UQ(id_shipment, line_no))

stock_movements(id_movement PK, movement_date, id_product FK→products,
                id_tank FK→tanks, movement_type, volume,
                id_delivery_item FK→delivery_items NULL,
                id_shipment_item FK→shipment_items NULL, comment)

tank_measurements(id_measurement PK, id_tank FK→tanks, measured_at,
                  volume, temperature, density, UQ(id_tank, measured_at))

reserve_forecasts(id_forecast PK, id_product FK→products, forecast_date,
                  horizon_days, current_stock, avg_daily_consumption,
                  predicted_consumption, predicted_reserve, method, created_at,
                  UQ(id_product, forecast_date, horizon_days))
```

### 7.2. Нормализация

**Исходное (ненормализованное) представление документа поставки:**

```
Поставка(номер, дата, поставщик, ИНН поставщика,
         [продукт, плотность, резервуар, ёмкость резервуара,
          объём, цена, стоимость строки],
         итоговая сумма)
```

Квадратные скобки означают повторяющуюся группу.

#### Первая нормальная форма (1НФ)

- Повторяющаяся группа «позиции поставки» выносится в отдельную таблицу `delivery_items`.
- Каждый атрибут атомарен: нет списков продуктов в одной ячейке, нет составных значений.
- У каждой строки появляется первичный ключ.
- Аналогично поставка и отгрузка разделяются на заголовок и позиции.

**Результат:** `deliveries` + `delivery_items`, `shipments` + `shipment_items`.

#### Вторая нормальная форма (2НФ)

- В `delivery_items` часть атрибутов зависит только от документа, а не от полного ключа `(id_delivery, line_no)`: поставщик, дата поставки, номер счёта. Они переносятся в `deliveries`.
- Атрибуты продукта (название, плотность, категория) зависят от `id_product`, а не от позиции; переносятся в `products`.
- Атрибуты резервуара (номер, ёмкость) зависят от `id_tank`; переносятся в `tanks`.
- Цена и объём зависят от полной строки документа — остаются в позиции.

**Результат:** устранены частичные зависимости.

#### Третья нормальная форма (3НФ)

Устраняются транзитивные зависимости:

- `delivery_items.id_product → products.name, products.density, products.category` — вынесено в `products`.
- `delivery_items.id_tank → tanks.tank_number, tanks.capacity` — вынесено в `tanks`.
- `deliveries.id_supplier → suppliers.name, suppliers.inn` — вынесено в `suppliers`.
- `shipments.id_client → clients.name, clients.client_type, clients.inn` — вынесено в `clients`.
- `delivery_items.id_delivery → deliveries.delivery_date, deliveries.id_supplier` — заголовок отдельно.
- Стоимость строки — вычисляемая (`volume × price`), не является независимым фактом; хранится как генерируемый столбец.
- Итоговая сумма документа — агрегат по строкам; хранится как контролируемый кэш (см. 5.5).

**Результат:** все неключевые атрибуты зависят от ключа целиком и ни от чего, кроме ключа.

#### BCNF

Проверка: каждый детерминант функциональных зависимостей является кандидатным ключом.

- `id_product → ...` — PK.
- `product_code → ...` — `UNIQUE`, кандидатный ключ.
- `id_delivery, line_no → ...` — `UNIQUE`, кандидатный ключ.
- `id_product, effective_date → ...` — `UNIQUE`, кандидатный ключ.
- `id_tank, measured_at → ...` — `UNIQUE`, кандидатный ключ.
- `id_product, forecast_date, horizon_days → ...` — `UNIQUE`, кандидатный ключ.
- `id_delivery → id_supplier, delivery_date...` — PK.
- `current_volume`, `total_amount` — не детерминанты, а материализованные агрегаты.

**Вывод:** схема находится в BCNF; контролируемая избыточность агрегатов описана отдельно и не создаёт аномалий, так как обновляется только триггерами.

### 7.3. Что написать в разделе 3 отчёта

1. Реляционная схема в компактной нотации.
2. Словарь данных по каждой таблице (можно перенести из 5.2).
3. Исходное ненормализованное представление.
4. Пошаговый переход 1НФ → 2НФ → 3НФ → BCNF.
5. Список функциональных зависимостей.
6. Обоснование контролируемой избыточности.
7. Матрица ссылочных действий.
8. Вывод о соответствии схемы 3НФ/BCNF.

---

## 8. Этап P4. Реализация в PostgreSQL и индексы

### 8.1. Порядок DDL

`01_schema.sql` создаёт таблицы в порядке, исключающем конфликты внешних ключей:

1. `products`
2. `suppliers`
3. `clients`
4. `tanks` (FK → products)
5. `price_history` (FK → products)
6. `deliveries` (FK → suppliers)
7. `delivery_items` (FK → deliveries, products, tanks)
8. `shipments` (FK → clients)
9. `shipment_items` (FK → shipments, products, tanks)
10. `stock_movements` (FK → products, tanks, delivery_items, shipment_items)
11. `tank_measurements` (FK → tanks)
12. `reserve_forecasts` (FK → products)

Для повторного запуска: `01_schema.sql` начинается с `DROP TABLE IF EXISTS ... CASCADE` (в обратном порядке), `02_indexes.sql` использует `CREATE INDEX IF NOT EXISTS`, а `06_matviews.sql` — `DROP MATERIALIZED VIEW IF EXISTS ... CASCADE` перед созданием. Это делает прогон воспроизводимым.

Пример стиля DDL:

```sql
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
```

Ключевые особенности PostgreSQL, которые нужно описать в отчёте:

| Особенность | Где используется | Что написать |
| :--- | :--- | :--- |
| `SERIAL`/`BIGSERIAL` | Все PK | Автоинкремент через последовательности; не стандарт SQL, но удобен в PostgreSQL |
| `GENERATED ALWAYS AS ... STORED` | `total_cost` | Генерируемый столбец; значение вычисляется при записи и хранится |
| `NUMERIC(p,s)` | Объёмы, деньги, плотность | Точная арифметика, в отличие от `FLOAT` |
| `TIMESTAMPTZ` | `movement_date`, `created_at`, `measured_at` | Хранение с часовым поясом, корректные сравнения |
| `CHECK` | Статусы, диапазоны, ИНН | Декларативная семантическая целостность |
| `UNIQUE` | Естественные ключи | Кандидатные ключи, защита от дублей |
| `ON DELETE RESTRICT` | Справочники и документы | Запрет удаления связанных записей |
| `ON DELETE SET NULL` | Ссылки движений на позиции | Сохранение аудита при удалении строки |
| `num_nonnulls()` | `stock_movements` | Проверка, что заполнена не более одной ссылки |
| `FOR UPDATE` | Триггеры | Блокировка резервуара от конкурентного расхода |
| `ON CONFLICT ... DO UPDATE` | Процедура прогноза | Идемпотентная запись прогноза |
| `REFRESH MATERIALIZED VIEW CONCURRENTLY` | Материализованные представления | Обновление без блокировки чтения; нужен уникальный индекс |

### 8.2. Индексы

| № | Индекс | Таблица / поля | Назначение |
| :---: | :--- | :--- | :--- |
| 1 | `idx_tanks_product` | `tanks(id_product)` | Поиск резервуаров продукта, соединения |
| 2 | `idx_price_product_date` | `price_history(id_product, effective_date)` | История цен, `LAG` |
| 3 | `idx_deliveries_supplier_date` | `deliveries(id_supplier, delivery_date)` | Поставки поставщика за период |
| 4 | `idx_delivery_items_delivery` | `delivery_items(id_delivery)` | Позиции документа |
| 5 | `idx_delivery_items_product` | `delivery_items(id_product)` | Сводки по продукту |
| 6 | `idx_delivery_items_tank` | `delivery_items(id_tank)` | Сводки по резервуару |
| 7 | `idx_shipments_client_date` | `shipments(id_client, shipment_date)` | Отгрузки клиента за период |
| 8 | `idx_shipments_status_date` | `shipments(status, shipment_date)` | Фильтры по статусу и дате |
| 9 | `idx_shipment_items_shipment` | `shipment_items(id_shipment)` | Позиции документа |
| 10 | `idx_shipment_items_product` | `shipment_items(id_product)` | Сводки по продукту |
| 11 | `idx_shipment_items_tank` | `shipment_items(id_tank)` | Сводки по резервуару |
| 12 | `idx_movements_product_date` | `stock_movements(id_product, movement_date)` | Прогноз, история расхода |
| 13 | `idx_movements_tank_date` | `stock_movements(id_tank, movement_date)` | Сходимость остатков |
| 14 | `idx_measurements_tank_date` | `tank_measurements(id_tank, measured_at)` | История замеров |
| 15 | `idx_forecasts_product_date` | `reserve_forecasts(id_product, forecast_date)` | Поиск прогнозов |
| 16 | `idx_forecasts_deficit` | `reserve_forecasts(id_product)` `WHERE predicted_reserve < 0` | Частичный индекс для дефицита |

**Правила:**

- Не создавать индексы на поля, которые уже покрыты `UNIQUE`/`PRIMARY KEY`.
- Для каждого индекса в отчёте указать, какой запрос/операция его использует.
- Показать `EXPLAIN (ANALYZE, BUFFERS)` минимум для 2–3 запросов (до/после индекса или просто план).
- Не индексировать всё подряд: лишние индексы замедляют вставку.

### 8.3. Наполнение данными

**Целевые объёмы:**

| Таблица | Записей | Комментарий |
| :--- | :---: | :--- |
| `products` | 15 | 5 бензинов, 5 дизельных, 3 мазута, 2 масла |
| `suppliers` | 15 | Правдоподобные организации |
| `clients` | 15 | 8 оптовых, 7 розничных |
| `tanks` | 15 | По одному резервуару на продукт |
| `price_history` | 30 | По 2 записи на продукт (2025 и 2026) |
| `deliveries` | 20 | 2025–2026, разные поставщики |
| `delivery_items` | 40 | По 2 позиции на поставку |
| `shipments` | 20 | 2025–2026, разные клиенты |
| `shipment_items` | 38 | 19 документов по 2 позиции; одна отменённая отгрузка без позиций |
| `stock_movements` | 93+ | 15 начальных остатков + 40 приходов + 38 расходов |
| `tank_measurements` | 30 | По 2 замера на резервуар |
| `reserve_forecasts` | 15 | По одной строке на продукт (процедура) |

**Порядок наполнения `05_seed.sql`:**

1. `TRUNCATE` всех таблиц `RESTART IDENTITY CASCADE` — для повторяемости.
2. `products`, `suppliers`, `clients` — справочники.
3. `tanks` — с начальным `current_volume` (30–70 % ёмкости).
4. `stock_movements` — начальные остатки типа `корректировка` с объёмом, равным `current_volume`, и `movement_date = TIMESTAMPTZ '2025-08-31 23:59:00+03'` (до первой поставки; не `now()`, иначе исторический прогноз на 2026-06-30 не увидит начальный остаток).
5. `price_history` — 2 цены на продукт.
6. `deliveries` — заголовки со статусом `оформлена`.
7. `delivery_items` — по 2 позиции; триггеры увеличивают остатки и создают движения `приход`.
8. `shipments` — заголовки со статусом `оформлена`.
9. `shipment_items` — по 2 позиции; триггеры уменьшают остатки и создают движения `расход`.
10. `tank_measurements` — 2 замера на резервуар.
11. Обновление статусов: все 20 поставок → `принята`; все 19 отгрузок с позициями → `отгружена`; одна отгрузка → `отменена` **без позиций**.
12. `CALL sp_build_forecasts(DATE '2026-06-30', 30);` — 15 прогнозов.
13. `setval` для всех последовательностей (если использовались явные ID).
14. Проверка количества строк по каждой таблице.

**Калибровка данных под запросы:**

- 8 оптовых клиентов и 7 розничных — для Q01, Q06, Q09; все 15 резервуаров — `в эксплуатации`, иначе Q12 вернёт меньше 15 строк.
- Минимум 3 бензина с октановым числом ≥ 95 — для Q02; все 15 поставщиков — `is_active = TRUE` для Q03.
- У части поставщиков телефон `+7...`, у части заполнено контактное лицо — для Q03.
- 4–8 резервуаров заполнены менее чем на 50 % при ёмкости ≥ 10 000 л — для Q04.
- 20+ позиций поставок с ценой выше 50 руб./л — для Q05.
- 2–4 поставки `ООО «Нефтеснаб»` в сентябре–декабре 2025 — для Q08.
- 5+ розничных отгрузок вне I квартала 2026 — для Q09.
- 5+ позиций отгруженных отгрузок с объёмом > 1000 л и ценой < 60 руб./л — для Q07.
- Поставки с продуктами `АИ-92`, `АИ-95`, `ДТ-Л` — для Q10; каждый из 15 продуктов встречается хотя бы в одной позиции поставки — для Q17.
- Клиенты, не покупавшие мазут — для Q11 (NOT IN).
- Клиенты, покупавшие `АИ-95`, но не покупавшие `ДТ-Л` — для Q20; 5+ клиентов с суммой отгруженных позиций > 100 000 руб. — для Q18.
- Условия Q21 (ANY/ALL) должны давать непустой результат: ёмкости бензиновых резервуаров больше текущих объёмов, а объёмы части резервуаров больше любого объёма масляных.
- 8+ клиентов с отгруженными и без отменённых отгрузок — для Q22.
- 3–5 продуктов с остатком ниже `min_reserve` — для Q23 и материализованного представления.
- При распределении позиций по резервуарам суммарный приход не должен превышать свободную ёмкость, а расход — текущий остаток; иначе триггеры остановят загрузку.

**Реалистичные данные:**

- Коды: `АИ-80`, `АИ-92`, `АИ-95`, `АИ-98`, `АИ-100`, `ДТ-Л`, `ДТ-З`, `ДТ-Арк`, `ДТ-Евро`, `ДТ-100`, `М-100`, `М-40`, `М-10`, `И-20А`, `И-40А`.
- Поставщики: `ООО «Нефтеснаб»`, `АО «ТопливоТрейд»`, `ООО «Петрол-Логистик»` и т. п.
- Клиенты: `ООО «АвтоТранс»`, `АЗС №12 «Восток»`, `ООО «СтройТехника»` и т. п.
- Резервуары: `Р-01` … `Р-15`.
- Даты: 2025-09-01 … 2026-11-15; прогноз на 2026-06-30.

### 8.4. Проверка схемы и данных

После `01_schema.sql`:

```sql
\dt
\d+ products
\d+ tanks
\d+ stock_movements
```

После `05_seed.sql`:

```sql
SELECT 'products' AS table_name, count(*) FROM products
UNION ALL SELECT 'suppliers', count(*) FROM suppliers
UNION ALL SELECT 'clients', count(*) FROM clients
UNION ALL SELECT 'tanks', count(*) FROM tanks
UNION ALL SELECT 'price_history', count(*) FROM price_history
UNION ALL SELECT 'deliveries', count(*) FROM deliveries
UNION ALL SELECT 'delivery_items', count(*) FROM delivery_items
UNION ALL SELECT 'shipments', count(*) FROM shipments
UNION ALL SELECT 'shipment_items', count(*) FROM shipment_items
UNION ALL SELECT 'stock_movements', count(*) FROM stock_movements
UNION ALL SELECT 'tank_measurements', count(*) FROM tank_measurements
UNION ALL SELECT 'reserve_forecasts', count(*) FROM reserve_forecasts
ORDER BY table_name;
```

Все значения должны быть ≥ 15.

Проверка сходимости:

```sql
SELECT count(*) AS mismatches
FROM (
    SELECT t.id_tank
    FROM tanks t
    LEFT JOIN stock_movements m ON m.id_tank = t.id_tank
    GROUP BY t.id_tank, t.current_volume
    HAVING t.current_volume <> COALESCE(SUM(m.volume), 0)
) x;
```

Ожидается `0`.

Проверка сумм документов:

```sql
SELECT d.id_delivery, d.total_amount, COALESCE(SUM(di.total_cost), 0) AS calc
FROM deliveries d
LEFT JOIN delivery_items di ON di.id_delivery = d.id_delivery
GROUP BY d.id_delivery, d.total_amount
HAVING d.total_amount <> COALESCE(SUM(di.total_cost), 0);

SELECT s.id_shipment, s.total_amount, COALESCE(SUM(si.total_cost), 0) AS calc
FROM shipments s
LEFT JOIN shipment_items si ON si.id_shipment = s.id_shipment
GROUP BY s.id_shipment, s.total_amount
HAVING s.total_amount <> COALESCE(SUM(si.total_cost), 0);
```

Ожидается 0 строк.

### 8.5. Что написать в разделе 4 отчёта

1. Создание БД (`00_create_db.sql`) и пояснение про `CREATE DATABASE`.
2. DDL таблиц с комментариями к типам и ограничениям.
3. Скриншоты `\d+` для 3–4 ключевых таблиц.
4. Физическая ER-диаграмма (pgAdmin ERD или draw.io).
5. Таблица индексов и обоснование.
6. `EXPLAIN ANALYZE` для 2–3 запросов.
7. Скриншот количества строк.
8. Особенности PostgreSQL (таблица из 8.1).
---

## 9. Этап P7. Разработка запросов (23 запроса)

### 9.1. Матрица запросов

| ID | Категория по таблице 1 | Формулировка | Основные таблицы | Ожидаемый результат |
| :--- | :--- | :--- | :--- | :--- |
| Q01 | 1.A — однотабличный, простое условие | Вывести оптовых клиентов | `clients` | 8 строк |
| Q02 | 1.B.b1 — `and`, `and`, `not` | Активные бензины с октановым числом не ниже 95 | `products` | 3–5 строк |
| Q03 | 1.B.b2 — `and`, `or` | Активные поставщики, у которых телефон `+7…` или заполнено контактное лицо | `suppliers` | 15 строк |
| Q04 | 1.B.b3 — `and`, `and` | Резервуары в эксплуатации, заполненные не более чем на 50 %, ёмкостью от 10 000 л | `tanks` | 4–8 строк |
| Q05 | 1.C — многотабличный, вычисляемое поле, простое условие | Стоимость позиций поставок с ценой выше 50 руб./л | `deliveries`, `delivery_items`, `products` | 20+ строк |
| Q06 | 1.D.d1 — `or`, `and`, `not` | Отгрузки оптовым клиентам или на сумму > 100 000, кроме отменённых, с 2025 года | `shipments`, `clients` | 10+ строк |
| Q07 | 1.D.d2 — `and`, `and` | Позиции отгруженных отгрузок объёмом > 1000 л и ценой < 60 руб./л | `shipments`, `shipment_items`, `products` | 5+ строк |
| Q08 | 1.D.d3 — `and`, `BETWEEN` | Поставки `ООО «Нефтеснаб»` за 01.09.2025–31.12.2025 | `deliveries`, `suppliers` | 2–4 строки |
| Q09 | 1.D.d4 — `and`, `NOT BETWEEN` | Розничные отгрузки вне I квартала 2026 года | `shipments`, `clients` | 5+ строк |
| Q10 | 1.D.d5 — `IN` | Поставки продуктов `АИ-92`, `АИ-95`, `ДТ-Л` | `deliveries`, `suppliers`, `delivery_items`, `products` | 10+ строк |
| Q11 | 1.D.d6 — `NOT IN` | Клиенты, которые не покупали мазут | `clients`, `shipments`, `shipment_items`, `products` | 8+ строк |
| Q12 | 2 — оконная функция | Рейтинг резервуаров по текущему объёму внутри категории продукта | `tanks`, `products` | 15 строк |
| Q13 | 2 — оконная функция | Накопительная сумма и скользящее среднее отгрузок | `shipments` | 15+ строк |
| Q14 | 2 — оконная функция | Изменение закупочной цены по сравнению с предыдущей датой | `price_history`, `products` | 30 строк |
| Q15 | 3 — вычисляемое поле | Масса топлива в тоннах и процент заполнения резервуара | `tanks`, `products` | 15 строк |
| Q16 | 3 — вычисляемое поле | Обеспеченность запасом в процентах от минимального норматива | `products`, `tanks` | 15 строк |
| Q17 | 4 — агрегаты, простая сортировка | Суммарный объём и стоимость поставок по продуктам | `products`, `delivery_items` | 15 строк |
| Q18 | 4 — агрегаты, `HAVING`, 3 поля сортировки | Клиенты с суммой отгрузок > 100 000: количество, объём, сумма, средний чек | `clients`, `shipments`, `shipment_items` | 5+ строк |
| Q19 | 5 — скалярный подзапрос | Отклонение суммы отгрузки от средней суммы отгруженных отгрузок | `shipments` | 15+ строк |
| Q20 | 5 — `IN` и `NOT IN` | Клиенты, покупавшие `АИ-95`, но не покупавшие `ДТ-Л` | `clients`, `shipments`, `shipment_items`, `products` | 3+ строки |
| Q21 | 5 — `ANY` и `ALL` | Резервуары, объём которых больше любого масляного и меньше всех бензиновых ёмкостей | `tanks`, `products` | 5+ строк |
| Q22 | 5 — `EXISTS` и `NOT EXISTS` | Клиенты с отгруженными отгрузками с 2025 года и без отменённых | `clients`, `shipments` | 8+ строк |
| Q23 | 6 — материализованное представление | Продукты с дефицитом запаса из `mv_product_stock` | `mv_product_stock` | 3–5 строк |

### 9.2. SQL-скрипты запросов

> Все скрипты — в файлах `sql/queries/q01.sql` … `q23.sql`. Ниже приведены опорные тексты; при калибровке данных условия можно уточнить, но категория запроса и используемые операторы должны сохраниться.

#### Q01 — 1.A. Однотабличный запрос с простым условием

```sql
SELECT id_client, name, client_type, phone, contract_date
FROM clients
WHERE client_type = 'оптовый'
ORDER BY name;
```

#### Q02 — 1.B.b1. Однотабличный, `AND`, `AND`, `NOT`

```sql
SELECT id_product, product_code, name, category, octane_rating, min_reserve
FROM products
WHERE is_active = TRUE
  AND category = 'бензин'
  AND NOT (octane_rating < 95)
ORDER BY octane_rating DESC, product_code;
```

#### Q03 — 1.B.b2. Однотабличный, `AND`, `OR`

```sql
SELECT id_supplier, name, inn, phone, contact_person
FROM suppliers
WHERE is_active = TRUE
  AND (phone LIKE '+7%' OR contact_person IS NOT NULL)
ORDER BY name;
```

#### Q04 — 1.B.b3. Однотабличный, `AND`, `AND`

```sql
SELECT id_tank, tank_number, capacity, current_volume, status
FROM tanks
WHERE status = 'в эксплуатации'
  AND current_volume <= capacity * 0.5
  AND capacity >= 10000
ORDER BY tank_number;
```

#### Q05 — 1.C. Многотабличный, вычисляемое поле, простое условие

```sql
SELECT d.delivery_number,
       d.delivery_date,
       p.product_code,
       p.name AS product_name,
       di.volume,
       di.price_per_liter,
       ROUND(di.volume * di.price_per_liter, 2) AS line_total
FROM deliveries d
JOIN delivery_items di ON di.id_delivery = d.id_delivery
JOIN products p ON p.id_product = di.id_product
WHERE di.price_per_liter > 50
ORDER BY d.delivery_date, d.delivery_number, p.product_code;
```

#### Q06 — 1.D.d1. Многотабличный, `OR`, `AND`, `NOT`

```sql
SELECT s.shipment_number,
       s.shipment_date,
       c.name AS client_name,
       c.client_type,
       s.status,
       s.total_amount
FROM shipments s
JOIN clients c ON c.id_client = s.id_client
WHERE (c.client_type = 'оптовый' OR s.total_amount > 100000)
  AND NOT (s.status = 'отменена')
  AND s.shipment_date >= DATE '2025-01-01'
ORDER BY s.shipment_date DESC, s.shipment_number;
```

#### Q07 — 1.D.d2. Многотабличный, `AND`, `AND`

```sql
SELECT s.shipment_number,
       s.shipment_date,
       p.product_code,
       si.volume,
       si.price_per_liter,
       si.total_cost
FROM shipments s
JOIN shipment_items si ON si.id_shipment = s.id_shipment
JOIN products p ON p.id_product = si.id_product
WHERE s.status = 'отгружена'
  AND si.volume > 1000
  AND si.price_per_liter < 60
ORDER BY s.shipment_date, p.product_code;
```

#### Q08 — 1.D.d3. Многотабличный, `AND`, `BETWEEN`

```sql
SELECT d.delivery_number,
       d.delivery_date,
       s.name AS supplier_name,
       d.total_amount
FROM deliveries d
JOIN suppliers s ON s.id_supplier = d.id_supplier
WHERE s.name = 'ООО «Нефтеснаб»'
  AND d.delivery_date BETWEEN DATE '2025-09-01' AND DATE '2025-12-31'
ORDER BY d.delivery_date, d.delivery_number;
```

#### Q09 — 1.D.d4. Многотабличный, `AND`, `NOT BETWEEN`

```sql
SELECT s.shipment_number,
       s.shipment_date,
       c.name AS client_name,
       s.total_amount
FROM shipments s
JOIN clients c ON c.id_client = s.id_client
WHERE c.client_type = 'розничный'
  AND s.status <> 'отменена'
  AND s.shipment_date NOT BETWEEN DATE '2026-01-01' AND DATE '2026-03-31'
ORDER BY s.shipment_date, s.shipment_number;
```

#### Q10 — 1.D.d5. Многотабличный, `IN`

```sql
SELECT d.delivery_number,
       d.delivery_date,
       s.name AS supplier_name,
       p.product_code,
       di.volume
FROM deliveries d
JOIN suppliers s ON s.id_supplier = d.id_supplier
JOIN delivery_items di ON di.id_delivery = d.id_delivery
JOIN products p ON p.id_product = di.id_product
WHERE p.product_code IN ('АИ-92', 'АИ-95', 'ДТ-Л')
ORDER BY d.delivery_date, p.product_code;
```

#### Q11 — 1.D.d6. Многотабличный, `NOT IN`

```sql
SELECT c.id_client, c.name, c.client_type
FROM clients c
JOIN shipments s ON s.id_client = c.id_client
WHERE c.id_client NOT IN (
    SELECT s2.id_client
    FROM shipments s2
    JOIN shipment_items si ON si.id_shipment = s2.id_shipment
    JOIN products p ON p.id_product = si.id_product
    WHERE p.category = 'мазут'
)
GROUP BY c.id_client, c.name, c.client_type
ORDER BY c.name;
```

#### Q12 — 2. Оконная функция: `RANK()`

```sql
SELECT p.category,
       p.product_code,
       t.tank_number,
       t.current_volume,
       RANK() OVER (PARTITION BY p.category ORDER BY t.current_volume DESC) AS volume_rank,
       ROUND(100.0 * t.current_volume / NULLIF(t.capacity, 0), 2) AS fill_pct
FROM tanks t
JOIN products p ON p.id_product = t.id_product
WHERE t.status = 'в эксплуатации'
ORDER BY p.category, volume_rank;
```

#### Q13 — 2. Оконная функция: накопительная сумма и скользящее среднее

```sql
SELECT s.shipment_date,
       s.shipment_number,
       s.total_amount,
       SUM(s.total_amount) OVER (
           ORDER BY s.shipment_date, s.shipment_number
       ) AS cumulative_amount,
       ROUND(AVG(s.total_amount) OVER (
           ORDER BY s.shipment_date, s.shipment_number
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ), 2) AS moving_avg_3
FROM shipments s
WHERE s.status = 'отгружена'
ORDER BY s.shipment_date, s.shipment_number;
```

#### Q14 — 2. Оконная функция: `LAG()`

```sql
SELECT p.product_code,
       ph.effective_date,
       ph.purchase_price,
       LAG(ph.purchase_price) OVER (
           PARTITION BY ph.id_product ORDER BY ph.effective_date
       ) AS prev_price,
       ROUND(ph.purchase_price - LAG(ph.purchase_price) OVER (
           PARTITION BY ph.id_product ORDER BY ph.effective_date
       ), 2) AS price_change
FROM price_history ph
JOIN products p ON p.id_product = ph.id_product
ORDER BY p.product_code, ph.effective_date;
```

#### Q15 — 3. Вычисляемое поле: масса и заполненность

```sql
SELECT t.tank_number,
       p.product_code,
       p.name,
       t.current_volume,
       p.density,
       ROUND(t.current_volume * p.density / 1000000, 3) AS mass_tons,
       ROUND(100.0 * t.current_volume / NULLIF(t.capacity, 0), 2) AS fill_pct
FROM tanks t
JOIN products p ON p.id_product = t.id_product
ORDER BY mass_tons DESC;
```

#### Q16 — 3. Вычисляемое поле: обеспеченность запасом

```sql
SELECT p.product_code,
       p.name,
       p.min_reserve,
       COALESCE(SUM(t.current_volume), 0) AS current_volume,
       ROUND(COALESCE(SUM(t.current_volume), 0) * 100.0 / NULLIF(p.min_reserve, 0), 2) AS reserve_pct,
       COALESCE(SUM(t.current_volume), 0) - p.min_reserve AS deviation
FROM products p
LEFT JOIN tanks t ON t.id_product = p.id_product
GROUP BY p.id_product, p.product_code, p.name, p.min_reserve
ORDER BY reserve_pct;
```

#### Q17 — 4. Агрегаты: группировка и простая сортировка

```sql
SELECT p.product_code,
       p.name,
       COUNT(di.id_delivery_item) AS delivery_lines,
       SUM(di.volume) AS total_volume,
       ROUND(SUM(di.volume * di.price_per_liter), 2) AS total_cost
FROM products p
JOIN delivery_items di ON di.id_product = p.id_product
GROUP BY p.id_product, p.product_code, p.name
ORDER BY total_volume DESC;
```

#### Q18 — 4. Агрегаты: `HAVING` и многоуровневая сортировка

```sql
SELECT c.client_type,
       c.name AS client_name,
       COUNT(DISTINCT s.id_shipment) AS shipments_count,
       SUM(si.volume) AS total_volume,
       ROUND(SUM(si.total_cost), 2) AS total_amount,
       ROUND(SUM(si.total_cost) / COUNT(DISTINCT s.id_shipment), 2) AS avg_shipment_amount
FROM clients c
JOIN shipments s ON s.id_client = c.id_client
JOIN shipment_items si ON si.id_shipment = s.id_shipment
WHERE s.status = 'отгружена'
GROUP BY c.id_client, c.client_type, c.name
HAVING SUM(si.total_cost) > 100000
ORDER BY c.client_type, total_amount DESC, c.name;
```

#### Q19 — 5. Скалярный подзапрос

```sql
SELECT s.shipment_number,
       s.shipment_date,
       s.total_amount,
       ROUND(
           s.total_amount - (SELECT AVG(total_amount) FROM shipments WHERE status = 'отгружена'),
           2
       ) AS deviation_from_avg
FROM shipments s
WHERE s.status = 'отгружена'
ORDER BY deviation_from_avg DESC;
```

#### Q20 — 5. Подзапросы `IN` и `NOT IN`

```sql
SELECT c.id_client, c.name, c.client_type
FROM clients c
WHERE c.id_client IN (
    SELECT s.id_client
    FROM shipments s
    JOIN shipment_items si ON si.id_shipment = s.id_shipment
    JOIN products p ON p.id_product = si.id_product
    WHERE p.product_code = 'АИ-95'
)
AND c.id_client NOT IN (
    SELECT s.id_client
    FROM shipments s
    JOIN shipment_items si ON si.id_shipment = s.id_shipment
    JOIN products p ON p.id_product = si.id_product
    WHERE p.product_code = 'ДТ-Л'
)
ORDER BY c.name;
```

#### Q21 — 5. Подзапросы `ANY` и `ALL`

```sql
SELECT t.tank_number,
       p.product_code,
       t.current_volume,
       t.capacity
FROM tanks t
JOIN products p ON p.id_product = t.id_product
WHERE t.current_volume > ANY (
        SELECT t2.current_volume
        FROM tanks t2
        JOIN products p2 ON p2.id_product = t2.id_product
        WHERE p2.category = 'масло'
    )
  AND t.current_volume < ALL (
        SELECT t3.capacity
        FROM tanks t3
        JOIN products p3 ON p3.id_product = t3.id_product
        WHERE p3.category = 'бензин'
    )
ORDER BY t.current_volume DESC;
```

#### Q22 — 5. Подзапросы `EXISTS` и `NOT EXISTS`

```sql
SELECT c.id_client, c.name, c.client_type
FROM clients c
WHERE EXISTS (
        SELECT 1
        FROM shipments s
        WHERE s.id_client = c.id_client
          AND s.status = 'отгружена'
          AND s.shipment_date >= DATE '2025-01-01'
    )
  AND NOT EXISTS (
        SELECT 1
        FROM shipments s
        WHERE s.id_client = c.id_client
          AND s.status = 'отменена'
    )
ORDER BY c.name;
```

#### Q23 — 6. Запрос на основе материализованного представления

```sql
SELECT product_code,
       name,
       category,
       total_volume,
       min_reserve,
       deviation,
       reserve_status
FROM mv_product_stock
WHERE reserve_status = 'дефицит'
ORDER BY deviation;
```

### 9.3. Порядок выполнения и оформления запросов

1. Создать 23 файла `sql/queries/q01.sql` … `q23.sql` с шапкой:

```sql
\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q01 — оптовые клиенты'
```

2. Выполнить каждый файл:

```bash
psql -d oildepotdb -v ON_ERROR_STOP=1 -f sql/queries/q01.sql | tee results/q01.txt
```

3. Убедиться, что результат непустой и осмысленный. Если пусто — проверить данные и калибровку (см. 8.3), не менять категорию запроса.
4. Сделать скриншот в pgAdmin 4 Query Tool или терминале. На скриншоте должны быть видны:
   - текст запроса (или его начало);
   - заголовки столбцов;
   - 5–15 строк результата;
   - сообщение о количестве строк, если инструмент его показывает.
5. Сохранить скриншот как `docs/screenshots/fig_qNN.png`.
6. В отчёте для каждого запроса:
   - формулировка на русском;
   - SQL в блоке кода;
   - скриншот;
   - 1–2 предложения анализа результата;
   - указание категории по таблице 1.

### 9.4. Требования к результатам

- Q01–Q04: однотабличные; в SQL не должно быть `JOIN` и подзапросов.
- Q05–Q11: минимум две таблицы в `FROM/JOIN` (для Q11 подзапрос тоже считается, но лучше оставить `JOIN`).
- Q06: обязательно присутствуют `OR`, `AND`, `NOT`.
- Q08: обязательно `BETWEEN`; Q09 — `NOT BETWEEN`.
- Q10: `IN`; Q11: `NOT IN`.
- Q12–Q14: оконные функции `RANK`, `SUM OVER`, `AVG OVER`, `LAG`.
- Q15–Q16: вычисляемые выражения с `ROUND`.
- Q17–Q18: `GROUP BY`; в Q18 — `HAVING` и `ORDER BY` по трём полям.
- Q19: скалярный подзапрос, возвращающий одно значение.
- Q20: `IN` и `NOT IN`; Q21: `ANY` и `ALL`; Q22: `EXISTS` и `NOT EXISTS`.
- Q23: `SELECT` из материализованного представления.
- Во всех запросах с сортировкой — детерминированный `ORDER BY`, чтобы скриншоты воспроизводились.
---

## 10. Этап P8. Ссылочная и семантическая целостность, точность

### 10.1. Уровни целостности

| Уровень | Механизм | Примеры |
| :--- | :--- | :--- |
| Целостность сущностей | `PRIMARY KEY`, `NOT NULL`, `UNIQUE` | `products.id_product`, `deliveries.delivery_number`, `shipments.shipment_number` |
| Ссылочная целостность | `FOREIGN KEY`, `ON DELETE/UPDATE` | `tanks.id_product → products`, `delivery_items.id_delivery → deliveries` |
| Семантическая целостность | `CHECK`, `GENERATED`, триггеры | `volume > 0`, `current_volume <= capacity`, `retail_price >= purchase_price`, контроль остатка |
| Доменная целостность | типы, длины, регулярные выражения | `NUMERIC(12,3)`, `VARCHAR(10)`, ИНН `^[0-9]{10}([0-9]{2})?$` |
| Динамическая целостность | транзакции, блокировки | `BEGIN/COMMIT`, `SELECT … FOR UPDATE` в триггерах |

### 10.2. Ссылочная целостность

Матрица действий — в разделе 5.4. В отчёте нужно:

1. Показать `\d+` или запрос к `pg_constraint`:

```sql
SELECT conrelid::regclass AS table_name,
       conname,
       contype,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
ORDER BY table_name, contype, conname;
```

2. Объяснить, почему для справочников и документов выбрано `ON DELETE RESTRICT`.
3. Объяснить `ON DELETE SET NULL` для ссылок движений на позиции: сохранение аудита.
4. Показать негативный тест: удаление продукта, на который ссылается резервуар, завершается ошибкой FK.

### 10.3. Семантическая целостность

**Декларативные ограничения:**

| Ограничение | Где | Смысл |
| :--- | :--- | :--- |
| `current_volume <= capacity` | `tanks` | Нельзя переполнить резервуар |
| `current_volume >= 0` | `tanks` | Нельзя уйти в минус |
| `volume > 0` | позиции | Объём операции положителен |
| `price_per_liter >= 0` | позиции | Цена неотрицательна |
| `retail_price >= purchase_price` | `price_history` | Нет отрицательной наценки |
| `density BETWEEN 700 AND 950` | `products`, `tank_measurements` | Правдоподобная плотность |
| `octane_rating BETWEEN 80 AND 100` | `products` | Правдоподобное октановое число |
| `category <> 'бензин' OR octane_rating IS NOT NULL` | `products` | У бензина есть октановое число |
| ИНН regex | `suppliers`, `clients` | 10 или 12 цифр |
| `num_nonnulls(...) <= 1` | `stock_movements` | Движение ссылается не более чем на одну позицию |
| Знак объёма по типу движения | `stock_movements` | Приход `+`, расход `−` |
| `horizon_days BETWEEN 1 AND 365` | `reserve_forecasts` | Разумный горизонт |
| `status <> 'принята' OR total_amount > 0`; `status <> 'отменена' OR total_amount = 0` | `deliveries` | Нельзя принять пустую поставку и отменить поставку с позициями |
| `status <> 'отгружена' OR total_amount > 0`; `status <> 'отменена' OR total_amount = 0` | `shipments` | Нельзя отгрузить пустую отгрузку и отменить отгрузку с позициями |

**Триггеры (динамическая семантика):**

- контроль достаточности остатка при отгрузке;
- контроль свободной ёмкости при поставке;
- контроль соответствия продукта резервуару;
- запрет изменения позиций в закрытом документе;
- автоматическое создание движений и обновление итогов.

### 10.4. Точность расчётных данных

| Показатель | Тип | Точность | Почему |
| :--- | :--- | :--- | :--- |
| Объёмы топлива | `NUMERIC(12,3)` | 0,001 л | Учёт в литрах; достаточный запас |
| Денежные суммы | `NUMERIC(14,2)` | 0,01 руб. | Копейки; без двоичных ошибок |
| Цены | `NUMERIC(10,2)` | 0,01 руб. | Цена за литр |
| Плотность | `NUMERIC(6,2)` | 0,01 кг/м³ | Физическая величина |
| Температура | `NUMERIC(5,2)` | 0,01 °C | Замеры |
| Проценты | `NUMERIC` + `ROUND(...,2)` | 0,01 % | Отчёты |
| Средний расход | `NUMERIC(12,3)` | 0,001 л/сут | Прогноз |

**Правила:**

- Не использовать `FLOAT`/`REAL` для денег и объёмов.
- Все вычисления в запросах — с `ROUND(...,2)` или `ROUND(...,3)`.
- В `GENERATED`-столбце `total_cost` округление до копеек.
- В отчёте показать разницу:

```sql
SELECT 0.1::float + 0.2::float AS float_sum,
       0.1::numeric + 0.2::numeric AS numeric_sum;
```

Ожидается `0.30000000000000004` и `0.3`; это обосновывает выбор `NUMERIC`.

- Для средних значений использовать `NULLIF(SUM(volume), 0)`, чтобы избежать деления на ноль.

### 10.5. Негативные тесты

| № | Тест | Действие | Ожидание |
| :---: | :--- | :--- | :--- |
| N01 | Недостаточный остаток | Вставить `shipment_items` с объёмом больше остатка | Исключение триггера, откат |
| N02 | Переполнение резервуара | Вставить `delivery_items` с объёмом больше свободной ёмкости | Исключение триггера |
| N03 | Неверный продукт | Поставить продукт в резервуар другого продукта | Исключение триггера |
| N04 | Отрицательная цена | Вставить позицию с `price_per_liter = -1` | `CHECK` violation |
| N05 | Плотность вне диапазона | Вставить продукт с `density = 100` | `CHECK` violation |
| N06 | Неверный ИНН | Вставить клиента с ИНН из 5 цифр | `CHECK` violation |
| N07 | Дубль номера документа | Вставить поставку с существующим `delivery_number` | `UNIQUE` violation |
| N08 | Удаление продукта с резервуаром | `DELETE FROM products WHERE id_product = 1` | FK violation |
| N09 | Удаление поставки с позициями | `DELETE FROM deliveries WHERE id_delivery = 1` | FK violation (RESTRICT) |
| N10 | Изменение закрытого документа | Вставить позицию в отгрузку со статусом `отгружена` | Исключение триггера |
| N11 | Переполнение прихода | Поставка в резервуар, где свободно меньше объёма | Исключение триггера |
| N12 | Отрицательный остаток | Прямой `UPDATE tanks SET current_volume = -1` | `CHECK` violation |

Каждый тест — в отдельной транзакции:

```sql
BEGIN;
-- действие, которое должно завершиться ошибкой
ROLLBACK;
```

Скриншот ошибки — в отчёте; после `ROLLBACK` данные не меняются.

`08_tests.sql` запускается **без** `ON_ERROR_STOP=1` (или с `\set ON_ERROR_STOP off` в начале файла), потому что ошибки здесь ожидаемы: после ошибки psql должен дойти до `ROLLBACK` и следующего теста. Для приёмочного `99_acceptance.sql`, наоборот, `ON_ERROR_STOP=1` обязателен.

### 10.6. Проверка сходимости и конкурентности

**Сходимость остатков:** запрос из 5.5 должен вернуть 0 строк.

**Сходимость сумм:** запросы из 8.4 должны вернуть 0 строк.

**Конкурентность (опционально, для сильного отчёта):**

1. Открыть две сессии `psql`.
2. В первой: `BEGIN;` и вставить отгрузку, забирающую почти весь остаток, но не commit.
3. Во второй: попытаться вставить отгрузку на остаток; она должна ждать блокировку, затем получить ошибку после commit первой.
4. Показать, что `SELECT … FOR UPDATE` предотвращает «двойную продажу» топлива.

Это можно оформить как дополнительный рисунок; в обязательный минимум не входит.

### 10.7. Что написать в разделе 5/6 отчёта

- Таблицу ограничений и их назначение.
- Скриншот `pg_constraint` или `\d+`.
- Описание триггеров и их роли в семантической целостности.
- Негативные тесты со скриншотами.
- Таблицу точности и пример `FLOAT` vs `NUMERIC`.
- Вывод: целостность обеспечена на уровне схемы и на уровне бизнес-логики.

---

## 11. Этап P5. Объекты БД

### 11.1. Материализованные представления (2)

#### MV1. `mv_product_stock` — текущие запасы по продуктам

Назначение: сводка остатков, отклонение от минимума, статус обеспечения. Используется в Q23 и в отчётах.

```sql
DROP MATERIALIZED VIEW IF EXISTS mv_product_stock CASCADE;

CREATE MATERIALIZED VIEW mv_product_stock AS
WITH stock AS (
    SELECT id_product, SUM(current_volume) AS total_volume
    FROM tanks
    WHERE status <> 'выведен'
    GROUP BY id_product
)
SELECT p.id_product,
       p.product_code,
       p.name,
       p.category,
       COALESCE(s.total_volume, 0) AS total_volume,
       p.min_reserve,
       COALESCE(s.total_volume, 0) - p.min_reserve AS deviation,
       CASE
           WHEN COALESCE(s.total_volume, 0) < p.min_reserve THEN 'дефицит'
           WHEN COALESCE(s.total_volume, 0) < p.min_reserve * 1.2 THEN 'ниже нормы'
           ELSE 'норма'
       END AS reserve_status,
       now() AS refreshed_at
FROM products p
LEFT JOIN stock s ON s.id_product = p.id_product;

CREATE UNIQUE INDEX mv_product_stock_pk ON mv_product_stock (id_product);
```

Обновление:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_stock;
```

#### MV2. `mv_monthly_sales` — продажи по месяцам и продуктам

Назначение: анализ выручки, объёмов и средней цены по месяцам.

```sql
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_sales CASCADE;

CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT date_trunc('month', s.shipment_date)::date AS month,
       p.id_product,
       p.product_code,
       p.name,
       COUNT(DISTINCT s.id_shipment) AS shipments_count,
       SUM(si.volume) AS volume,
       ROUND(SUM(si.total_cost), 2) AS revenue,
       ROUND(SUM(si.total_cost) / NULLIF(SUM(si.volume), 0), 2) AS avg_price
FROM shipments s
JOIN shipment_items si ON si.id_shipment = s.id_shipment
JOIN products p ON p.id_product = si.id_product
WHERE s.status = 'отгружена'
GROUP BY 1, 2, 3, 4;

CREATE UNIQUE INDEX mv_monthly_sales_pk ON mv_monthly_sales (month, id_product);
```

**Требования:**

- После создания — первичное `REFRESH MATERIALIZED VIEW mv_...;` (без `CONCURRENTLY`).
- Для `CONCURRENTLY` обязателен уникальный индекс — он создан.
- В отчёте показать `\dm`, `SELECT * FROM mv_product_stock`, `REFRESH ... CONCURRENTLY`, повторный `SELECT`.
- Объяснить, зачем материализованные представления: тяжёлые агрегаты, отчёты, снижение нагрузки.

### 11.2. Функция с курсором (1)

**`fn_product_forecast`** — прогноз по одному продукту.

```sql
CREATE OR REPLACE FUNCTION fn_product_forecast(
    p_id_product   INTEGER,
    p_horizon_days INTEGER DEFAULT 30,
    p_as_of_date   DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    forecast_date          DATE,
    horizon_days           INTEGER,
    current_stock          NUMERIC,
    avg_daily_consumption  NUMERIC,
    predicted_consumption  NUMERIC,
    predicted_reserve      NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    cur CURSOR FOR
        SELECT m.movement_date::date AS day,
               SUM(-m.volume) AS daily_consumption
        FROM stock_movements m
        WHERE m.id_product = p_id_product
          AND m.movement_type = 'расход'
          AND m.movement_date >= p_as_of_date - INTERVAL '29 days'
          AND m.movement_date <  p_as_of_date + INTERVAL '1 day'
        GROUP BY 1
        ORDER BY 1;
    rec RECORD;
    v_total   NUMERIC := 0;
    v_stock   NUMERIC := 0;
    v_avg     NUMERIC := 0;
    v_pred    NUMERIC := 0;
BEGIN
    IF p_as_of_date IS NULL THEN
        RAISE EXCEPTION 'Дата прогноза не может быть NULL';
    END IF;

    IF p_horizon_days IS NULL OR p_horizon_days NOT BETWEEN 1 AND 365 THEN
        RAISE EXCEPTION 'Горизонт прогноза должен быть от 1 до 365 дней, получено %', p_horizon_days;
    END IF;

    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        v_total := v_total + rec.daily_consumption;
    END LOOP;
    CLOSE cur;

    SELECT COALESCE(SUM(volume), 0)
      INTO v_stock
      FROM stock_movements
     WHERE id_product = p_id_product
       AND movement_date < p_as_of_date + INTERVAL '1 day';

    v_avg  := ROUND(v_total / 30.0, 3);
    v_pred := ROUND(v_avg * p_horizon_days, 3);

    RETURN QUERY
    SELECT p_as_of_date,
           p_horizon_days,
           v_stock,
           v_avg,
           v_pred,
           ROUND(v_stock - v_pred, 3);
END;
$$;
```

**Пояснения для отчёта:**

- Курсор явно объявлен, открыт, прочитан в цикле и закрыт — это выполняет требование «курсор».
- Средний расход считается как сумма расхода за 30 календарных дней (включая дату отсчёта) / 30.
- Остаток на дату считается по регистру движений, а не по текущему кэшу, чтобы прогноз был исторически корректным.
- `STABLE` — функция не меняет данные.

**Проверка:**

```sql
SELECT * FROM fn_product_forecast(1, 30, DATE '2026-06-30');
```

### 11.3. Процедура с курсором (1)

**`sp_build_forecasts`** — пакетный расчёт прогнозов по всем активным продуктам.

```sql
CREATE OR REPLACE PROCEDURE sp_build_forecasts(
    p_as_of_date   DATE DEFAULT CURRENT_DATE,
    p_horizon_days INTEGER DEFAULT 30
)
LANGUAGE plpgsql
AS $$
DECLARE
    cur CURSOR FOR
        SELECT id_product, product_code, name
        FROM products
        WHERE is_active = TRUE
        ORDER BY id_product;
    rec RECORD;
    v_stock NUMERIC;
    v_avg   NUMERIC;
    v_pred  NUMERIC;
BEGIN
    IF p_as_of_date IS NULL THEN
        RAISE EXCEPTION 'Дата прогноза не может быть NULL';
    END IF;

    IF p_horizon_days IS NULL OR p_horizon_days NOT BETWEEN 1 AND 365 THEN
        RAISE EXCEPTION 'Горизонт прогноза должен быть от 1 до 365 дней, получено %', p_horizon_days;
    END IF;

    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;

        SELECT COALESCE(SUM(volume), 0)
          INTO v_stock
          FROM stock_movements
         WHERE id_product = rec.id_product
           AND movement_date < p_as_of_date + INTERVAL '1 day';

        SELECT COALESCE(SUM(-volume), 0) / 30.0
          INTO v_avg
          FROM stock_movements
         WHERE id_product = rec.id_product
           AND movement_type = 'расход'
           AND movement_date >= p_as_of_date - INTERVAL '29 days'
           AND movement_date <  p_as_of_date + INTERVAL '1 day';

        v_avg  := ROUND(v_avg, 3);
        v_pred := ROUND(v_avg * p_horizon_days, 3);

        INSERT INTO reserve_forecasts (
            id_product, forecast_date, horizon_days,
            current_stock, avg_daily_consumption,
            predicted_consumption, predicted_reserve, method
        )
        VALUES (
            rec.id_product, p_as_of_date, p_horizon_days,
            v_stock, v_avg, v_pred, ROUND(v_stock - v_pred, 3),
            'средний расход за 30 дней'
        )
        ON CONFLICT (id_product, forecast_date, horizon_days)
        DO UPDATE SET
            current_stock = EXCLUDED.current_stock,
            avg_daily_consumption = EXCLUDED.avg_daily_consumption,
            predicted_consumption = EXCLUDED.predicted_consumption,
            predicted_reserve = EXCLUDED.predicted_reserve,
            method = EXCLUDED.method,
            created_at = now();
    END LOOP;
    CLOSE cur;

    RAISE NOTICE 'Прогнозы сформированы на % (горизонт % дней)', p_as_of_date, p_horizon_days;
END;
$$;
```

**Проверка:**

```sql
CALL sp_build_forecasts(DATE '2026-06-30', 30);
SELECT * FROM reserve_forecasts ORDER BY id_product;
```

**Пояснения:**

- Курсор перебирает продукты.
- Для каждого продукта считается остаток на дату и средний расход.
- `ON CONFLICT` делает процедуру идемпотентной: повторный вызов обновляет прогноз, а не дублирует.
- 15 активных продуктов → 15 строк прогноза.

### 11.4. Триггеры (2)

#### T1. `trg_shipment_items_stock` — контроль и учёт отгрузки

**Событие:** `AFTER INSERT OR UPDATE OR DELETE ON shipment_items FOR EACH ROW`.
**Функция:** `fn_shipment_items_stock()`.

**Алгоритм:**

1. Для `INSERT`:
   - проверить статус отгрузки (`оформлена`);
   - заблокировать резервуар `SELECT … FOR UPDATE`;
   - проверить, что `tanks.id_product = NEW.id_product`;
   - проверить `current_volume >= NEW.volume`;
   - уменьшить `tanks.current_volume`;
   - вставить `stock_movements` с `movement_type='расход'`, `volume = -NEW.volume`, `movement_date` = дата отгрузки, ссылкой на позицию;
   - увеличить `shipments.total_amount` на `ROUND(NEW.volume * NEW.price_per_liter, 2)`.
2. Для `UPDATE`:
   - запретить менять `id_shipment`, `id_product`, `id_tank`;
   - проверить статус;
   - заблокировать резервуар `SELECT … FOR UPDATE`;
   - вычислить `delta = NEW.volume - OLD.volume`;
   - если `delta > 0`, проверить и списать delta; если `delta < 0`, проверить `current_volume + (-delta) <= capacity` и вернуть `-delta` в резервуар;
   - если `delta <> 0`, вставить корректирующее движение с `movement_date = now()`; если `delta = 0` (меняется только цена или номер строки), движение не создавать;
   - скорректировать сумму документа на `ROUND(NEW.volume * NEW.price_per_liter, 2) - ROUND(OLD.volume * OLD.price_per_liter, 2)`.
3. Для `DELETE`:
   - проверить статус;
   - заблокировать резервуар `SELECT … FOR UPDATE`;
   - проверить `current_volume + OLD.volume <= capacity` и вернуть `OLD.volume` в резервуар;
   - вставить движение `корректировка` с `volume = OLD.volume`, `movement_date = now()` **без FK-ссылки** (`id_shipment_item = NULL`, а `OLD.id_shipment_item` указать в комментарии), потому что строка уже удалена;
   - уменьшить сумму документа на `ROUND(OLD.volume * OLD.price_per_liter, 2)`.

**Ключевые фрагменты:**

```sql
SELECT current_volume, capacity, id_product
  INTO v_stock, v_capacity, v_product
  FROM tanks
 WHERE id_tank = NEW.id_tank
   FOR UPDATE;

IF v_product <> NEW.id_product THEN
    RAISE EXCEPTION 'Продукт не соответствует резервуару %', NEW.id_tank;
END IF;

IF v_stock < NEW.volume THEN
    RAISE EXCEPTION 'Недостаточно топлива в резервуаре %: остаток %, требуется %',
        NEW.id_tank, v_stock, NEW.volume;
END IF;

UPDATE tanks
   SET current_volume = current_volume - NEW.volume
 WHERE id_tank = NEW.id_tank;

INSERT INTO stock_movements (
    movement_date, id_product, id_tank, movement_type, volume, id_shipment_item, comment
) VALUES (
    (SELECT s.shipment_date::timestamptz
       FROM shipments s
      WHERE s.id_shipment = NEW.id_shipment),
    NEW.id_product, NEW.id_tank, 'расход', -NEW.volume,
    NEW.id_shipment_item, 'Отгрузка'
);

UPDATE shipments
   SET total_amount = total_amount + ROUND(NEW.volume * NEW.price_per_liter, 2)
 WHERE id_shipment = NEW.id_shipment;
```

#### T2. `trg_delivery_items_stock` — контроль и учёт поставки

**Событие:** `AFTER INSERT OR UPDATE OR DELETE ON delivery_items FOR EACH ROW`.
**Функция:** `fn_delivery_items_stock()`.

**Алгоритм:**

1. Для `INSERT`:
   - проверить статус поставки (`оформлена`);
   - заблокировать резервуар;
   - проверить соответствие продукта;
   - проверить `current_volume + NEW.volume <= capacity`;
   - увеличить `tanks.current_volume`;
   - вставить движение `приход` с `volume = NEW.volume`, `movement_date` = дата поставки;
   - увеличить `deliveries.total_amount`.
2. Для `UPDATE`: аналогично T1, но с контролем свободной ёмкости; заблокировать резервуар, при `delta > 0` проверить `current_volume + delta <= capacity`, при `delta < 0` — `current_volume >= -delta`; при уменьшении объёма — корректировка с `movement_date = now()`. Если `delta = 0` (меняется только цена или номер строки), движение не создаётся, корректируется только сумма документа.
3. Для `DELETE`: заблокировать резервуар, проверить `current_volume >= OLD.volume`, уменьшить остаток, вставить корректировку с отрицательным объёмом, `movement_date = now()` **без FK-ссылки** (`id_delivery_item = NULL`), уменьшить сумму документа.

**Ключевые фрагменты:**

```sql
SELECT current_volume, capacity, id_product
  INTO v_stock, v_capacity, v_product
  FROM tanks
 WHERE id_tank = NEW.id_tank
   FOR UPDATE;

IF v_product <> NEW.id_product THEN
    RAISE EXCEPTION 'Продукт не соответствует резервуару %', NEW.id_tank;
END IF;

IF v_stock + NEW.volume > v_capacity THEN
    RAISE EXCEPTION 'Переполнение резервуара %: свободно %, требуется %',
        NEW.id_tank, v_capacity - v_stock, NEW.volume;
END IF;

UPDATE tanks
   SET current_volume = current_volume + NEW.volume
 WHERE id_tank = NEW.id_tank;

INSERT INTO stock_movements (
    movement_date, id_product, id_tank, movement_type, volume, id_delivery_item, comment
) VALUES (
    (SELECT d.delivery_date::timestamptz
       FROM deliveries d
      WHERE d.id_delivery = NEW.id_delivery),
    NEW.id_product, NEW.id_tank, 'приход', NEW.volume,
    NEW.id_delivery_item, 'Поставка'
);

UPDATE deliveries
   SET total_amount = total_amount + ROUND(NEW.volume * NEW.price_per_liter, 2)
 WHERE id_delivery = NEW.id_delivery;
```

**Создание триггеров:**

```sql
CREATE TRIGGER trg_shipment_items_stock
AFTER INSERT OR UPDATE OR DELETE ON shipment_items
FOR EACH ROW EXECUTE FUNCTION fn_shipment_items_stock();

CREATE TRIGGER trg_delivery_items_stock
AFTER INSERT OR UPDATE OR DELETE ON delivery_items
FOR EACH ROW EXECUTE FUNCTION fn_delivery_items_stock();
```

**Важно:**

- Триггеры не должны срабатывать на `stock_movements` — иначе будет рекурсия.
- Все изменения остатка идут только через позиции документов.
- `FOR UPDATE` сериализует конкурентные операции по одному резервуару.
- Триггеры — `AFTER`: для `INSERT`/`UPDATE` строка позиции уже существует, поэтому движение может ссылаться на неё. Для `DELETE` строка уже удалена, поэтому сторно-движение создаётся без FK-ссылки; старые движения обнуляют ссылку через `ON DELETE SET NULL`, история сохраняется.
- `movement_date` для прихода/расхода берётся из даты документа, а для корректировок — `now()`; иначе исторический прогноз и скользящие окна будут считать всё на дату наполнения БД.
- `total_cost` — генерируемый столбец; чтобы не зависеть от момента его вычисления, сумму в триггере считаем вручную: `ROUND(NEW.volume * NEW.price_per_liter, 2)`, а не читаем `NEW.total_cost`.

### 11.5. Тесты объектов

| Объект | Позитивный тест | Негативный тест |
| :--- | :--- | :--- |
| `mv_product_stock` | `SELECT *` возвращает 15 строк; `REFRESH … CONCURRENTLY` работает | — |
| `mv_monthly_sales` | `SELECT *` возвращает строки по месяцам; уникальный индекс есть | — |
| `fn_product_forecast` | Возвращает 1 строку с ненулевым средним расходом | Несуществующий продукт → 0/пусто, без ошибки |
| `sp_build_forecasts` | 15 строк в `reserve_forecasts`; повторный вызов не дублирует | Некорректный горизонт → исключение |
| T1 | Отгрузка уменьшает остаток, создаёт расход, увеличивает сумму | Недостаток остатка → исключение |
| T2 | Поставка увеличивает остаток, создаёт приход, увеличивает сумму | Переполнение → исключение |

### 11.6. Что написать в разделе 6 отчёта

1. Назначение каждого объекта.
2. Полный SQL (или ключевые фрагменты + ссылка на приложение).
3. Формулировка требования: «Разработать материализованное представление…».
4. Скриншоты создания и работы.
5. Для курсоров — описание `DECLARE/OPEN/FETCH/CLOSE`.
6. Для триггеров — событие, timing, функция, поведение.
7. Тесты: успешные и ошибочные.
8. Вывод о влиянии объектов на целостность и производительность.
---

## 12. План выполнения по фазам и контрольные точки

### 12.1. Сводная таблица фаз

| Фаза | Название | Основные действия | Артефакты | Критерий готовности |
| :---: | :--- | :--- | :--- | :--- |
| P0 | Подготовка | Проверить окружение, создать структуру папок, скопировать шаблон отчёта | `sql/`, `docs/`, `results/`, `templates/` | `psql --version`, `SELECT version()` работают; папки созданы |
| P1 | Предметная область | Описать процессы, участников, документы, бизнес-правила | `docs/ReportRGR.md`, раздел 1 | 20 бизнес-правил и 12 сущностей согласованы |
| P2 | IDEF1X | Построить концептуальную модель, экспортировать PNG | `docs/diagrams/idef1x.png`, `idef1x.drawio` | 12 сущностей, все связи, кардинальности, читаемость |
| P3 | Логическая модель | Реляционная схема, словарь, нормализация | Раздел 3 отчёта | 1НФ→2НФ→3НФ→BCNF описаны; схема в BCNF |
| P4 | DDL и индексы | Создать БД, 12 таблиц, 16+ индексов | `00_create_db.sql`, `01_schema.sql`, `02_indexes.sql` | `\dt` показывает 12 таблиц; скрипты идемпотентны |
| P5 | Объекты и триггеры | Создать функцию, процедуру, триггеры; подготовить matviews | `03_functions.sql`, `04_triggers.sql`, `06_matviews.sql` | Функция/процедура/триггеры созданы; тестовые вызовы работают |
| P6 | Наполнение | Заполнить таблицы, создать/обновить matviews, проверить сходимость | `05_seed.sql`, `06_matviews.sql` | ≥15 строк в каждой таблице; 0 расхождений; matviews заполнены |
| P7 | Запросы | 23 запроса, результаты, скриншоты | `sql/queries/q01.sql`…`q23.sql`, `results/q*.txt` | Все запросы непустые и соответствуют категориям |
| P8 | Целостность и точность | Негативные тесты, `pg_constraint`, `FLOAT` vs `NUMERIC` | `08_tests.sql`, скриншоты | 12 негативных тестов; 0 расхождений |
| P9 | Тестирование | Прогон с нуля, `99_acceptance.sql`, concurrency (опц.) | `results/acceptance.txt` | Скрипт завершается `ACCEPTANCE PASSED` |
| P10 | Отчёт и упаковка | Собрать DOCX/PDF, проверить рисунки, приложения | `ReportRGR.docx`, `ReportRGR.pdf` | Отчёт соответствует чек-листу; PDF открывается |

### 12.2. Детализация фаз

#### P0. Подготовка (30–60 мин)

- Проверить: `psql --version`, `psql -d postgres -c 'SELECT version();'`.
- Создать папки: `sql/queries`, `docs/diagrams`, `docs/screenshots`, `results`, `templates`.
- Скопировать `Lab2/Task2/ReportLab2.docx` в `templates/ReportTemplate.docx` (только чтение исходника).
- Создать `docs/PROGRESS.md` по шаблону из 4.5.
- Проверить кодировку терминала: `locale`; при необходимости `export LANG=ru_RU.UTF-8` или `en_US.UTF-8`.

**Контрольная точка:** `psql` подключается, папки существуют, шаблон скопирован.

#### P1. Предметная область (1–2 ч)

- Описать нефтебазу: приёмка, хранение, отпуск, контроль остатков, прогноз.
- Перечислить участников: кладовщик, оператор, менеджер, бухгалтер, аналитик.
- Перечислить документы: поставка, отгрузка, замер, прогноз.
- Сформулировать 20 бизнес-правил (BR-01…BR-20).
- Согласовать с пользователем спорные места (типы клиентов, статусы, единицы).

**Контрольная точка:** пользователь подтвердил предметную область и правила.

#### P2. IDEF1X (1–2 ч)

- Создать `idef1x_spec.md` и `idef1x.drawio`.
- Построить диаграмму в Visual Paradigm/draw.io.
- Экспортировать PNG 300 dpi, проверить читаемость.
- Вставить в отчёт с подписью и указанием инструмента.

**Контрольная точка:** диаграмма содержит 12 сущностей и все связи; пользователь подтвердил.

#### P3. Логическая модель (1–2 ч)

- Записать реляционную схему.
- Выполнить нормализацию, зафиксировать функциональные зависимости.
- Проверить BCNF.
- Описать контролируемую избыточность.

**Контрольная точка:** схема согласована; изменения после этой точки только через миграции.

#### P4. DDL и индексы (2–3 ч)

- Написать `00_create_db.sql` (идемпотентное создание БД).
- Написать `01_schema.sql` (12 таблиц, CHECK, FK, GENERATED).
- Написать `02_indexes.sql` (16 индексов).
- Прогнать на чистой БД, проверить `\dt`, `\d+`.
- Снять скриншоты.

**Контрольная точка:** скрипты выполняются с `ON_ERROR_STOP=1` без ошибок; 12 таблиц.

#### P5. Объекты и триггеры (3–4 ч)

- `03_functions.sql`: `fn_product_forecast`, `sp_build_forecasts`.
- `04_triggers.sql`: две функции + два триггера.
- `06_matviews.sql`: подготовить два matview + уникальные индексы; выполнить после наполнения (P6).
- Проверить создание в `pg_proc`, `pg_trigger`; matviews проверить в P6.

**Контрольная точка:** функция, процедура и триггеры созданы; простые вызовы не падают; matviews создаются в P6 после наполнения.

#### P6. Наполнение (2–3 ч)

- `05_seed.sql`: 12 таблиц, ≥15 строк.
- Прогнать, проверить количества.
- Проверить сходимость остатков и сумм.
- Калибровать данные под 23 запроса.
- Вызвать `sp_build_forecasts`.
- Выполнить `06_matviews.sql`; проверить `SELECT *` из обоих matviews.

**Контрольная точка:** все количества ≥15; 0 расхождений; запросы Q01–Q23 непустые (проверка на этом этапе — черновая).

#### P7. Запросы (3–4 ч)

- Создать 23 файла запросов.
- Прогнать, сохранить результаты.
- Сделать скриншоты.
- Вставить в отчёт с формулировками и анализом.

**Контрольная точка:** 23 запроса, каждый соответствует категории; скриншоты читаемы.

#### P8. Целостность и точность (1–2 ч)

- Собрать `08_tests.sql`: 12 негативных тестов, проверки сходимости, `FLOAT` vs `NUMERIC`.
- Снять скриншоты ошибок.
- Описать ограничения в отчёте.

**Контрольная точка:** все негативные тесты дают ожидаемые ошибки; данные не испорчены.

#### P9. Тестирование (1–2 ч)

- Удалить и создать БД с нуля.
- Прогнать все скрипты по порядку.
- Запустить `99_acceptance.sql`.
- Проверить отчёт на соответствие чек-листу.
- Опционально — concurrency-тест.

**Контрольная точка:** `ACCEPTANCE PASSED`; отчёт собран.

#### P10. Отчёт и упаковка (2–4 ч)

- Собрать DOCX по шаблону.
- Конвертировать в PDF (`soffice --headless --convert-to pdf`).
- Проверить нумерацию рисунков/таблиц, оглавление, ссылки.
- Проверить, что все скриншоты на месте и не размыты.
- Сложить исходники в `RGR/`, проверить, что `Lab*` не изменены.

**Контрольная точка:** DOCX и PDF открываются; отчёт готов к сдаче.

### 12.3. Оценка времени

| Фаза | Оценка |
| :--- | :---: |
| P0 | 0,5–1 ч |
| P1 | 1–2 ч |
| P2 | 1–2 ч |
| P3 | 1–2 ч |
| P4 | 2–3 ч |
| P5 | 3–4 ч |
| P6 | 2–3 ч |
| P7 | 3–4 ч |
| P8 | 1–2 ч |
| P9 | 1–2 ч |
| P10 | 2–4 ч |
| **Итого** | **17–29 ч** |

---

## 13. Тестирование и приёмка

### 13.1. Виды тестов

| Вид | Что проверяет | Где |
| :--- | :--- | :--- |
| Дымовые | БД создаётся, таблицы и объекты существуют | `99_acceptance.sql` |
| Функциональные | Запросы возвращают ожидаемые данные | `results/q*.txt` |
| Негативные | Ограничения и триггеры отклоняют некорректные данные | `08_tests.sql` |
| Сходимости | Остатки и суммы совпадают с регистром/позициями | `08_tests.sql` |
| Объектов | Matviews, функция, процедура, триггеры работают | `11_5` |
| Конкурентности (опц.) | Нет двойного списания остатка | две сессии `psql` |
| Регрессии | Повторный прогон с нуля даёт те же результаты | P9 |

### 13.2. Скрипт приёмки `99_acceptance.sql`

```sql
\set ON_ERROR_STOP on
\pset pager off

DO $$
DECLARE
    v_cnt INTEGER;
BEGIN
    SELECT count(*) INTO v_cnt FROM products;
    IF v_cnt < 15 THEN RAISE EXCEPTION 'products: % < 15', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM tanks;
    IF v_cnt < 15 THEN RAISE EXCEPTION 'tanks: % < 15', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM suppliers;
    IF v_cnt < 15 THEN RAISE EXCEPTION 'suppliers: % < 15', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM clients;
    IF v_cnt < 15 THEN RAISE EXCEPTION 'clients: % < 15', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM price_history;
    IF v_cnt < 30 THEN RAISE EXCEPTION 'price_history: % < 30', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM deliveries;
    IF v_cnt < 20 THEN RAISE EXCEPTION 'deliveries: % < 20', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM delivery_items;
    IF v_cnt < 40 THEN RAISE EXCEPTION 'delivery_items: % < 40', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM shipments;
    IF v_cnt < 20 THEN RAISE EXCEPTION 'shipments: % < 20', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM shipment_items;
    IF v_cnt < 38 THEN RAISE EXCEPTION 'shipment_items: % < 38', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM stock_movements;
    IF v_cnt < 93 THEN RAISE EXCEPTION 'stock_movements: % < 93', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM tank_measurements;
    IF v_cnt < 30 THEN RAISE EXCEPTION 'tank_measurements: % < 30', v_cnt; END IF;

    SELECT count(*) INTO v_cnt FROM reserve_forecasts;
    IF v_cnt < 15 THEN RAISE EXCEPTION 'reserve_forecasts: % < 15', v_cnt; END IF;

    IF to_regclass('public.mv_product_stock') IS NULL THEN
        RAISE EXCEPTION 'mv_product_stock отсутствует';
    END IF;

    IF to_regclass('public.mv_monthly_sales') IS NULL THEN
        RAISE EXCEPTION 'mv_monthly_sales отсутствует';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'fn_product_forecast'
          AND pronamespace = 'public'::regnamespace
    ) THEN
        RAISE EXCEPTION 'fn_product_forecast отсутствует';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'sp_build_forecasts'
          AND pronamespace = 'public'::regnamespace
    ) THEN
        RAISE EXCEPTION 'sp_build_forecasts отсутствует';
    END IF;

    SELECT count(*) INTO v_cnt FROM pg_trigger
    WHERE tgname IN ('trg_shipment_items_stock', 'trg_delivery_items_stock');
    IF v_cnt <> 2 THEN
        RAISE EXCEPTION 'Ожидалось 2 триггера, найдено %', v_cnt;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT t.id_tank
            FROM tanks t
            LEFT JOIN stock_movements m ON m.id_tank = t.id_tank
            GROUP BY t.id_tank, t.current_volume
            HAVING t.current_volume <> COALESCE(SUM(m.volume), 0)
        ) x
    ) THEN
        RAISE EXCEPTION 'Остатки не сходятся с регистром движений';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM deliveries d
        LEFT JOIN delivery_items di ON di.id_delivery = d.id_delivery
        GROUP BY d.id_delivery, d.total_amount
        HAVING d.total_amount <> COALESCE(SUM(di.total_cost), 0)
    ) THEN
        RAISE EXCEPTION 'Суммы поставок не сходятся';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM shipments s
        LEFT JOIN shipment_items si ON si.id_shipment = s.id_shipment
        GROUP BY s.id_shipment, s.total_amount
        HAVING s.total_amount <> COALESCE(SUM(si.total_cost), 0)
    ) THEN
        RAISE EXCEPTION 'Суммы отгрузок не сходятся';
    END IF;

    RAISE NOTICE 'ACCEPTANCE PASSED';
END;
$$;
```

После блока — контрольные выборки:

```sql
SELECT * FROM mv_product_stock ORDER BY deviation;
SELECT * FROM mv_monthly_sales ORDER BY month DESC, revenue DESC;
SELECT * FROM fn_product_forecast(1, 30, DATE '2026-06-30');
```

**Ожидаемый вывод:** `NOTICE: ACCEPTANCE PASSED`; запросы возвращают данные.

### 13.3. Матрица приёмки

| Проверка | Команда | Ожидание |
| :--- | :--- | :--- |
| 12 таблиц | `\dt` | 12 таблиц + matviews |
| 16 индексов | `\di` или запрос к `pg_indexes` | ≥16 пользовательских индексов |
| 15+ строк | блок в `99_acceptance.sql` | `ACCEPTANCE PASSED` |
| 23 запроса | прогон `q01..q23` | все непустые |
| 2 matviews | `\dm` | 2 строки |
| 2 курсора | код функции/процедуры | `OPEN/FETCH/CLOSE` |
| 1 функция | `\df fn_product_forecast` | существует |
| 1 процедура | `\df sp_build_forecasts` | существует |
| 2 триггера | `\dS shipment_items`, `\dS delivery_items` | по одному |
| Целостность | негативные тесты | ошибки ожидаемые |
| Точность | `NUMERIC` | 0,01/0,001 |

---

## 14. Структура отчёта и манифест рисунков

### 14.1. Структура DOCX/PDF

1. **Титульный лист** (по шаблону `ReportLab2.docx`).
2. **Содержание** (автособираемое поле или ручное).
3. **Введение** (1–2 с.): актуальность, цель, задачи, объект/предмет.
4. **1. Описание предметной области** (3–5 с.):
   - деятельность нефтебазы;
   - участники и процессы;
   - документы;
   - бизнес-правила (таблица BR-01…BR-20);
   - постановка задачи.
5. **2. Концептуальное проектирование** (3–5 с.):
   - сущности и атрибуты;
   - связи и кардинальности;
   - IDEF1X-диаграмма (рисунок);
   - обоснование решений.
6. **3. Логическое проектирование** (4–6 с.):
   - реляционная схема;
   - словарь данных (12 таблиц);
   - нормализация 1НФ→2НФ→3НФ→BCNF;
   - контролируемая избыточность;
   - ссылочные действия.
7. **4. Реализация в PostgreSQL** (5–7 с.):
   - создание БД;
   - DDL и особенности PostgreSQL;
   - ER-диаграмма;
   - индексы и `EXPLAIN`;
   - наполнение (скриншот количеств).
8. **5. Разработка запросов** (10–15 с.):
   - по каждому из 23 запросов: формулировка, SQL, скриншот, анализ.
9. **6. Объекты базы данных** (6–10 с.):
   - 2 matviews;
   - 2 курсора (в функции и процедуре);
   - функция;
   - процедура;
   - 2 триггера;
   - тесты.
10. **7. Целостность и точность** (3–5 с.):
    - ограничения;
    - негативные тесты;
    - `FLOAT` vs `NUMERIC`.
11. **Заключение** (1–2 с.): результаты, соответствие заданию, направления развития.
12. **Список источников** (5–10 позиций).
13. **Приложения**:
    - A. Полные SQL-скрипты.
    - B. Результаты запросов (текстом).
    - C. Листинги объектов.
    - D. Чек-лист приёмки.

**Ориентировочный объём:** 25–40 страниц с рисунками.

### 14.2. Манифест рисунков

| № | Файл | Содержание | Раздел |
| :---: | :--- | :--- | :---: |
| 1 | `fig_01_idef1x.png` | IDEF1X-диаграмма | 2 |
| 2 | `fig_02_physical_erd.png` | Физическая ER-диаграмма | 4 |
| 3 | `fig_03_db_create.png` | Создание БД / `\l` | 4 |
| 4 | `fig_04_dt.png` | Список 12 таблиц | 4 |
| 5 | `fig_05_describe_products.png` | `\d+ products` | 4 |
| 6 | `fig_06_indexes.png` | Список индексов | 4 |
| 7 | `fig_07_explain.png` | `EXPLAIN ANALYZE` | 4 |
| 8 | `fig_08_counts.png` | Количество строк по таблицам | 4 |
| 9–31 | `fig_q01.png` … `fig_q23.png` | 23 запроса | 5 |
| 32 | `fig_mv_product_stock.png` | `mv_product_stock` | 6 |
| 33 | `fig_mv_monthly_sales.png` | `mv_monthly_sales` | 6 |
| 34 | `fig_refresh_mv.png` | `REFRESH … CONCURRENTLY` | 6 |
| 35 | `fig_fn_forecast.png` | Вызов функции | 6 |
| 36 | `fig_proc_forecasts.png` | Вызов процедуры и таблица прогнозов | 6 |
| 37 | `fig_trigger_ok.png` | Успешная отгрузка (остаток уменьшился) | 6 |
| 38 | `fig_trigger_err.png` | Ошибка при недостатке остатка | 6 |
| 39 | `fig_constraints.png` | `pg_constraint` / `\d+` | 7 |
| 40 | `fig_negative_fk.png` | Ошибка FK | 7 |
| 41 | `fig_numeric.png` | `FLOAT` vs `NUMERIC` | 7 |
| 42 | `fig_acceptance.png` | `ACCEPTANCE PASSED` | 7/Приложение |

**Правила оформления рисунков:**

- Подпись по центру: `Рисунок N – Название`.
- Ссылка в тексте: «(рисунок N)» или «представлен на рисунке N».
- Скриншоты — с чётким шрифтом, без обрезанных заголовков.
- Если результат длинный — показывать первые 10–15 строк и подписывать «фрагмент результата».
- Нумерация сквозная.

### 14.3. Таблицы отчёта

| № | Содержание |
| :---: | :--- |
| 1 | Участники и роли |
| 2 | Бизнес-правила |
| 3 | Сущности и назначение |
| 4 | Связи и кардинальности |
| 5 | Словарь данных (по таблицам) |
| 6 | Функциональные зависимости |
| 7 | Ссылочные действия |
| 8 | Индексы |
| 9 | Матрица 23 запросов |
| 10 | Ограничения целостности |
| 11 | Негативные тесты |
| 12 | Точность типов |
| 13 | Объекты БД |
| 14 | Матрица приёмки |

---

## 15. Риски и меры снижения

| Код | Риск | Вероятность | Влияние | Меры |
| :--- | :--- | :---: | :---: | :--- |
| R-01 | Вариант в задании не совпадает с фактическим (кинотеатр vs нефтебаза) | Средняя | Высокое | Подтвердить у пользователя до P1; при смене — пересогласовать план |
| R-02 | Запросы возвращают пустые результаты | Высокая | Среднее | Калибровка данных (8.3), проверка каждого запроса после наполнения |
| R-03 | Рекурсия триггеров | Средняя | Высокое | Триггеры только на позиции, не на `stock_movements`; тест |
| R-04 | Дедлоки при конкурентных отгрузках | Низкая | Среднее | `ORDER BY id_tank` при блокировке, `FOR UPDATE`; в учебном сценарии — одна сессия |
| R-05 | Триггеры усложняют отладку | Высокая | Среднее | Логирование `RAISE NOTICE`, пошаговые тесты, `08_tests.sql` |
| R-06 | IDEF1X-инструмент недоступен/нет нотации | Средняя | Высокое | draw.io/ERwin; заранее проверить; не подменять Mermaid |
| R-07 | Проблемы с кириллицей в DOCX/PDF | Средняя | Среднее | UTF-8, шрифт Times New Roman, проверка PDF после конвертации |
| R-08 | `soffice` конвертирует с искажением | Низкая | Среднее | Проверить PDF постранично; при необходимости — Word/LibreOffice GUI |
| R-09 | Не хватает времени | Средняя | Высокое | Сначала обязательный минимум (P4–P9), улучшения — после |
| R-10 | Скриншоты нечитаемы | Средняя | Среднее | Единый масштаб, pgAdmin, 5–15 строк, проверка на 100 % |
| R-11 | Данные не сходятся после ручных правок | Средняя | Высокое | Не менять таблицы вручную; всё через скрипты; проверки сходимости |
| R-12 | Случайно изменены `Lab*`/`cinemadb` | Низкая | Высокое | Работать только в `RGR/`; перед сдачей `git status` |
| R-13 | `REFRESH … CONCURRENTLY` падает | Низкая | Среднее | Уникальный индекс; первичный refresh без `CONCURRENTLY` |
| R-14 | Последовательности после явных ID | Средняя | Среднее | `setval` в конце seed; проверка вставки новой строки |

---

## 16. Открытые вопросы и приложения

### 16.1. Вопросы к пользователю (повторно, для фиксации)

1. Подтверждаете вариант 17 (нефтебаза)?
2. Какие ФИО преподавателя, вуз, кафедра, группа для титульного листа?
3. DOCX + PDF — достаточно?
4. Скриншоты — pgAdmin 4 или терминал?
5. Есть ли требования к среде IDEF1X?
6. Можно ли использовать вымышленные названия организаций?
7. Есть ли жёсткий дедлайн/объём?
8. Нужны ли дополнительные объекты (представления, роли, аудит) сверх задания?

### 16.2. Приложение A. Шпаргалка команд

```bash
# Версия и подключение
psql --version
psql -d postgres -c 'SELECT version();'

# Создание/удаление БД
psql -d postgres -v ON_ERROR_STOP=1 -f sql/00_create_db.sql
dropdb --if-exists oildepotdb

# Прогон всех скриптов
for f in sql/0*.sql; do
  echo "== $f =="
  psql -d oildepotdb -v ON_ERROR_STOP=1 -f "$f" || break
done

# Один запрос
psql -d oildepotdb -P pager=off -P border=2 -f sql/queries/q01.sql

# Сохранение результата
psql -d oildepotdb -P pager=off -f sql/queries/q01.sql | tee results/q01.txt

# Список таблиц/индексов/представлений
psql -d oildepotdb -c '\dt'
psql -d oildepotdb -c '\di'
psql -d oildepotdb -c '\dm'
psql -d oildepotdb -c '\df fn_product_forecast'
psql -d oildepotdb -c '\dS shipment_items'

# Проверка constraints
psql -d oildepotdb -c "
SELECT conrelid::regclass, conname, pg_get_constraintdef(oid)
FROM pg_constraint WHERE connamespace='public'::regnamespace
ORDER BY 1,2;"

# Конвертация отчёта
soffice --headless --convert-to pdf --outdir docs docs/ReportRGR.docx

# Git-статус (не должно быть изменений в Lab*)
git status --short
```

### 16.3. Приложение B. Чек-лист файлов

- [ ] `RGR_implementation_plan.md`
- [ ] `sql/00_create_db.sql`
- [ ] `sql/01_schema.sql`
- [ ] `sql/02_indexes.sql`
- [ ] `sql/03_functions.sql`
- [ ] `sql/04_triggers.sql`
- [ ] `sql/05_seed.sql`
- [ ] `sql/06_matviews.sql`
- [ ] `sql/07_queries.sql`
- [ ] `sql/08_tests.sql`
- [ ] `sql/99_acceptance.sql`
- [ ] `sql/queries/q01.sql` … `q23.sql`
- [ ] `docs/ReportRGR.md`
- [ ] `docs/ReportRGR.docx`
- [ ] `docs/ReportRGR.pdf`
- [ ] `docs/diagrams/idef1x.png`
- [ ] `docs/diagrams/idef1x.drawio`
- [ ] `docs/diagrams/physical_erd.png`
- [ ] `docs/screenshots/fig_*.png`
- [ ] `results/q01.txt` … `q23.txt`
- [ ] `results/acceptance.txt`
- [ ] `docs/PROGRESS.md`

### 16.4. Приложение C. Чек-лист сдачи

- [ ] Все 23 запроса присутствуют и соответствуют категориям.
- [ ] В каждой таблице ≥15 строк.
- [ ] 2 matviews, 2 курсора, 1 функция, 1 процедура, 2 триггера.
- [ ] IDEF1X с указанием инструмента.
- [ ] Нормализация описана.
- [ ] Индексы созданы и обоснованы.
- [ ] Целостность и негативные тесты показаны.
- [ ] Точность `NUMERIC` обоснована.
- [ ] `99_acceptance.sql` выдаёт `ACCEPTANCE PASSED`.
- [ ] DOCX и PDF открываются, рисунки читаемы.
- [ ] `Lab*` и `cinemadb` не изменены.
- [ ] Отчёт подписан/оформлен по шаблону.

### 16.5. Приложение D. Глоссарий

| Термин | Значение |
| :--- | :--- |
| Нефтебаза | Предприятие по приёмке, хранению и отпуску нефтепродуктов |
| Резервуар | Ёмкость для хранения топлива |
| Поставка | Документ прихода топлива |
| Отгрузка | Документ расхода топлива |
| Движение | Запись регистра об изменении остатка |
| Замер | Измерение объёма/температуры/плотности |
| Прогноз | Расчёт ожидаемого расхода и остатка |
| Контролируемая избыточность | Кэшируемый агрегат, поддерживаемый триггерами |
| IDEF1X | Нотация концептуального моделирования данных |
| BCNF | Нормальная форма Бойса–Кодда |

### 16.6. Первый шаг агента

1. Прочитать `RGR_task.md` и этот план.
2. Задать вопросы из 16.1 (можно одним сообщением).
3. После ответов — начать P0: проверить окружение, создать папки, скопировать шаблон.
4. Вести `docs/PROGRESS.md` и после каждой фазы показывать пользователю краткий отчёт.

**Конец плана.**
