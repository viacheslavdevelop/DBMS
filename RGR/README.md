# РГР: учёт и прогноз запасов нефтепродуктов (вариант 17)

Реляционная база данных нефтебазы в PostgreSQL 18.6: 12 таблиц, ограничения
целостности, индексы, два материализованных представления, функция и процедура
прогноза, два триггера учёта остатков, 23 запроса, негативные тесты и
приёмочная проверка.

## Готовые документы

- `docs/ReportRGR.docx` — пояснительная записка (42 рисунка, 19 таблиц, 62 с.).
- `docs/ReportRGR.pdf` — та же записка в PDF.
- `docs/PROGRESS.md` — журнал выполнения и замечания по данным.
- `docs/diagrams/idef1x.png`, `docs/diagrams/idef1x.drawio` — концептуальная
  модель IDEF1X; `docs/diagrams/idef1x_spec.md` — её спецификация (сущности,
  атрибуты, связи, кардинальности, раскладка).
- `docs/diagrams/physical_erd.png` — физическая модель PostgreSQL.
- `docs/screenshots/` — 42 иллюстрации, построенные по фактическим выводам psql.
- `results/` — текстовые результаты выполнения запросов, тестов и приёмки.

## Структура SQL

| Файл | Назначение |
| --- | --- |
| `sql/00_create_db.sql` | создание базы `oildepotdb` в UTF-8 |
| `sql/01_schema.sql` | 12 таблиц, PK/FK, CHECK, UNIQUE, вычисляемые столбцы |
| `sql/02_indexes.sql` | 17 индексов, включая частичный индекс дефицита |
| `sql/03_functions.sql` | `fn_product_forecast`, `sp_build_forecasts` |
| `sql/04_triggers.sql` | триггеры позиций поставок и отгрузок |
| `sql/05_seed.sql` | тестовые данные и калибровка остатков |
| `sql/06_matviews.sql` | `mv_product_stock`, `mv_monthly_sales` |
| `sql/07_queries.sql` | запуск всех 23 запросов |
| `sql/08_tests.sql` | 12 негативных тестов в транзакциях с ROLLBACK |
| `sql/99_acceptance.sql` | приёмочная проверка и сообщение `ACCEPTANCE PASSED` |
| `sql/queries/q01.sql` … `q23.sql` | отдельные запросы |

## Полный прогон на чистой базе

```bash
psql -d postgres -v ON_ERROR_STOP=1 -f sql/00_create_db.sql
for f in 01_schema 02_indexes 03_functions 04_triggers 05_seed 06_matviews; do
  psql -X -d oildepotdb -v ON_ERROR_STOP=1 -f "sql/$f.sql"
done
psql -X -d oildepotdb -v ON_ERROR_STOP=1 -f sql/07_queries.sql
psql -X -d oildepotdb -v ON_ERROR_STOP=0 -f sql/08_tests.sql
psql -X -d oildepotdb -v ON_ERROR_STOP=1 -f sql/99_acceptance.sql
```

`08_tests.sql` запускается без `ON_ERROR_STOP`: 12 ошибок являются ожидаемым
результатом, каждая транзакция завершается `ROLLBACK`.

## Пересборка иллюстраций и отчёта

```bash
python3 docs/make_diagrams.py      # IDEF1X и физическая ERD
python3 docs/make_figures.py       # скриншоты из результатов psql
python3 docs/build_report.py       # DOCX + PDF, два прохода для содержания
```

Для сборки нужны Python 3, `python-docx`, `Pillow`, `PyMuPDF`, LibreOffice
(`soffice`) и шрифты macOS. Отчёт собирается из шаблона
`templates/ReportTemplate.docx`.

## Проверенные контрольные значения

- Строк: products 15, tanks 15, suppliers 15, clients 15, price_history 30,
  deliveries 20, delivery_items 40, shipments 20, shipment_items 38,
  stock_movements 93, tank_measurements 30, reserve_forecasts 15.
- Запросы возвращают от 3 до 34 строк; пустых результатов нет.
- Негативные тесты: 12 ожидаемых ошибок, все изменения откатаны.
- Приёмка: `ACCEPTANCE PASSED`; расхождений остатков и сумм документов нет.
