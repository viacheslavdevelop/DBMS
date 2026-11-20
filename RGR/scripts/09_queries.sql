-- =============================================================================
-- 09. Аналитические SQL-запросы (23 запроса)
-- РГР по СУБД, вариант 17. База данных oil_depot_db (PostgreSQL)
-- =============================================================================

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
