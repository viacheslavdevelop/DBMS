SET client_encoding = 'UTF8';

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*) INTO v_count FROM products;
    IF v_count < 15 THEN RAISE EXCEPTION 'products: %, ожидалось не менее 15', v_count; END IF;

    SELECT count(*) INTO v_count FROM tanks;
    IF v_count < 15 THEN RAISE EXCEPTION 'tanks: %, ожидалось не менее 15', v_count; END IF;

    SELECT count(*) INTO v_count FROM suppliers;
    IF v_count < 15 THEN RAISE EXCEPTION 'suppliers: %, ожидалось не менее 15', v_count; END IF;

    SELECT count(*) INTO v_count FROM clients;
    IF v_count < 15 THEN RAISE EXCEPTION 'clients: %, ожидалось не менее 15', v_count; END IF;

    SELECT count(*) INTO v_count FROM price_history;
    IF v_count < 30 THEN RAISE EXCEPTION 'price_history: %, ожидалось не менее 30', v_count; END IF;

    SELECT count(*) INTO v_count FROM deliveries;
    IF v_count < 20 THEN RAISE EXCEPTION 'deliveries: %, ожидалось не менее 20', v_count; END IF;

    SELECT count(*) INTO v_count FROM delivery_items;
    IF v_count < 40 THEN RAISE EXCEPTION 'delivery_items: %, ожидалось не менее 40', v_count; END IF;

    SELECT count(*) INTO v_count FROM shipments;
    IF v_count < 20 THEN RAISE EXCEPTION 'shipments: %, ожидалось не менее 20', v_count; END IF;

    SELECT count(*) INTO v_count FROM shipment_items;
    IF v_count < 38 THEN RAISE EXCEPTION 'shipment_items: %, ожидалось не менее 38', v_count; END IF;

    SELECT count(*) INTO v_count FROM stock_movements;
    IF v_count < 93 THEN RAISE EXCEPTION 'stock_movements: %, ожидалось не менее 93', v_count; END IF;

    SELECT count(*) INTO v_count FROM tank_measurements;
    IF v_count < 30 THEN RAISE EXCEPTION 'tank_measurements: %, ожидалось не менее 30', v_count; END IF;

    SELECT count(*) INTO v_count FROM reserve_forecasts;
    IF v_count < 15 THEN RAISE EXCEPTION 'reserve_forecasts: %, ожидалось не менее 15', v_count; END IF;

    IF to_regclass('public.mv_product_stock') IS NULL THEN
        RAISE EXCEPTION 'материализованное представление mv_product_stock не найдено';
    END IF;
    IF to_regclass('public.mv_monthly_sales') IS NULL THEN
        RAISE EXCEPTION 'материализованное представление mv_monthly_sales не найдено';
    END IF;
    IF to_regprocedure('fn_product_forecast(integer,integer,date)') IS NULL THEN
        RAISE EXCEPTION 'функция fn_product_forecast не найдена';
    END IF;
    IF to_regprocedure('sp_build_forecasts(date,integer)') IS NULL THEN
        RAISE EXCEPTION 'процедура sp_build_forecasts не найдена';
    END IF;

    SELECT count(*) INTO v_count
    FROM pg_trigger
    WHERE tgname IN ('trg_delivery_items_stock', 'trg_shipment_items_stock')
      AND NOT tgisinternal;
    IF v_count <> 2 THEN RAISE EXCEPTION 'ожидалось 2 триггера, найдено %', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM tanks t
    WHERE t.current_volume <> (
        SELECT COALESCE(SUM(m.volume), 0)
        FROM stock_movements m
        WHERE m.id_tank = t.id_tank
    );
    IF v_count <> 0 THEN RAISE EXCEPTION 'расхождение остатков по журналу движений: % резервуаров', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM deliveries d
    WHERE d.total_amount <> (
        SELECT COALESCE(SUM(di.total_cost), 0)
        FROM delivery_items di
        WHERE di.id_delivery = d.id_delivery
    );
    IF v_count <> 0 THEN RAISE EXCEPTION 'расхождение сумм поставок: % документов', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM shipments s
    WHERE s.total_amount <> (
        SELECT COALESCE(SUM(si.total_cost), 0)
        FROM shipment_items si
        WHERE si.id_shipment = s.id_shipment
    );
    IF v_count <> 0 THEN RAISE EXCEPTION 'расхождение сумм отгрузок: % документов', v_count; END IF;

    SELECT count(*) INTO v_count FROM tanks WHERE current_volume < 0 OR current_volume > capacity;
    IF v_count <> 0 THEN RAISE EXCEPTION 'некорректный остаток в % резервуарах', v_count; END IF;

    RAISE NOTICE 'ACCEPTANCE PASSED';
END;
$$;

\pset pager off
\pset border 2
\pset null '(null)'

SELECT 'products' AS table_name, count(*) AS row_count FROM products
UNION ALL SELECT 'tanks', count(*) FROM tanks
UNION ALL SELECT 'suppliers', count(*) FROM suppliers
UNION ALL SELECT 'clients', count(*) FROM clients
UNION ALL SELECT 'price_history', count(*) FROM price_history
UNION ALL SELECT 'deliveries', count(*) FROM deliveries
UNION ALL SELECT 'delivery_items', count(*) FROM delivery_items
UNION ALL SELECT 'shipments', count(*) FROM shipments
UNION ALL SELECT 'shipment_items', count(*) FROM shipment_items
UNION ALL SELECT 'stock_movements', count(*) FROM stock_movements
UNION ALL SELECT 'tank_measurements', count(*) FROM tank_measurements
UNION ALL SELECT 'reserve_forecasts', count(*) FROM reserve_forecasts
ORDER BY table_name;

SELECT product_code, name, total_volume, min_reserve, deviation, reserve_status
FROM mv_product_stock
ORDER BY product_code;

SELECT month, product_code, shipments_count, volume, revenue, avg_price
FROM mv_monthly_sales
ORDER BY month, product_code
LIMIT 12;

SELECT *
FROM fn_product_forecast(1, 30, DATE '2026-06-30');
