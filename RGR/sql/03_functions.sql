SET client_encoding = 'UTF8';

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
    v_total NUMERIC := 0;
    v_stock NUMERIC := 0;
    v_avg   NUMERIC := 0;
    v_pred  NUMERIC := 0;
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
