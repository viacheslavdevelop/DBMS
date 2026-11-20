SET client_encoding = 'UTF8';

CREATE OR REPLACE FUNCTION fn_delivery_items_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock    NUMERIC(12,3);
    v_capacity NUMERIC(12,3);
    v_product  INTEGER;
    v_status   VARCHAR(20);
    v_delta    NUMERIC(12,3);
    v_line     NUMERIC(14,2);
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT status INTO v_status FROM deliveries WHERE id_delivery = NEW.id_delivery;
        IF v_status IS NULL THEN
            RAISE EXCEPTION 'Поставка % не найдена', NEW.id_delivery;
        END IF;
        IF v_status <> 'оформлена' THEN
            RAISE EXCEPTION 'Нельзя изменять позиции поставки % в статусе «%»', NEW.id_delivery, v_status;
        END IF;

        SELECT current_volume, capacity, id_product
          INTO v_stock, v_capacity, v_product
          FROM tanks
         WHERE id_tank = NEW.id_tank
           FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Резервуар % не найден', NEW.id_tank;
        END IF;
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
            (SELECT d.delivery_date::timestamptz FROM deliveries d WHERE d.id_delivery = NEW.id_delivery),
            NEW.id_product, NEW.id_tank, 'приход', NEW.volume, NEW.id_delivery_item, 'Поставка'
        );

        UPDATE deliveries
           SET total_amount = total_amount + ROUND(NEW.volume * NEW.price_per_liter, 2)
         WHERE id_delivery = NEW.id_delivery;

    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.id_delivery <> OLD.id_delivery
           OR NEW.id_product <> OLD.id_product
           OR NEW.id_tank <> OLD.id_tank THEN
            RAISE EXCEPTION 'Нельзя изменять документ, продукт или резервуар позиции';
        END IF;

        SELECT status INTO v_status FROM deliveries WHERE id_delivery = NEW.id_delivery;
        IF v_status <> 'оформлена' THEN
            RAISE EXCEPTION 'Нельзя изменять позиции поставки % в статусе «%»', NEW.id_delivery, v_status;
        END IF;

        SELECT current_volume, capacity, id_product
          INTO v_stock, v_capacity, v_product
          FROM tanks
         WHERE id_tank = NEW.id_tank
           FOR UPDATE;
        IF v_product <> NEW.id_product THEN
            RAISE EXCEPTION 'Продукт не соответствует резервуару %', NEW.id_tank;
        END IF;

        v_delta := NEW.volume - OLD.volume;
        IF v_delta > 0 AND v_stock + v_delta > v_capacity THEN
            RAISE EXCEPTION 'Переполнение резервуара %: свободно %, требуется %',
                NEW.id_tank, v_capacity - v_stock, v_delta;
        END IF;
        IF v_delta < 0 AND v_stock < -v_delta THEN
            RAISE EXCEPTION 'Недостаточно топлива в резервуаре %: остаток %, требуется вернуть %',
                NEW.id_tank, v_stock, -v_delta;
        END IF;

        IF v_delta <> 0 THEN
            UPDATE tanks
               SET current_volume = current_volume + v_delta
             WHERE id_tank = NEW.id_tank;

            INSERT INTO stock_movements (
                movement_date, id_product, id_tank, movement_type, volume, comment
            ) VALUES (
                now(), NEW.id_product, NEW.id_tank, 'корректировка', v_delta,
                'Корректировка позиции поставки №' || OLD.id_delivery_item
            );
        END IF;

        v_line := ROUND(NEW.volume * NEW.price_per_liter, 2)
                - ROUND(OLD.volume * OLD.price_per_liter, 2);
        IF v_line <> 0 THEN
            UPDATE deliveries
               SET total_amount = total_amount + v_line
             WHERE id_delivery = NEW.id_delivery;
        END IF;

    ELSIF TG_OP = 'DELETE' THEN
        SELECT status INTO v_status FROM deliveries WHERE id_delivery = OLD.id_delivery;
        IF v_status <> 'оформлена' THEN
            RAISE EXCEPTION 'Нельзя изменять позиции поставки % в статусе «%»', OLD.id_delivery, v_status;
        END IF;

        SELECT current_volume, capacity, id_product
          INTO v_stock, v_capacity, v_product
          FROM tanks
         WHERE id_tank = OLD.id_tank
           FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Резервуар % не найден', OLD.id_tank;
        END IF;
        IF v_stock < OLD.volume THEN
            RAISE EXCEPTION 'Недостаточно топлива в резервуаре %: остаток %, требуется вернуть %',
                OLD.id_tank, v_stock, OLD.volume;
        END IF;

        UPDATE tanks
           SET current_volume = current_volume - OLD.volume
         WHERE id_tank = OLD.id_tank;

        INSERT INTO stock_movements (
            movement_date, id_product, id_tank, movement_type, volume, comment
        ) VALUES (
            now(), OLD.id_product, OLD.id_tank, 'корректировка', -OLD.volume,
            'Удаление позиции поставки №' || OLD.id_delivery_item
        );

        UPDATE deliveries
           SET total_amount = total_amount - ROUND(OLD.volume * OLD.price_per_liter, 2)
         WHERE id_delivery = OLD.id_delivery;

        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_shipment_items_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock    NUMERIC(12,3);
    v_capacity NUMERIC(12,3);
    v_product  INTEGER;
    v_status   VARCHAR(20);
    v_delta    NUMERIC(12,3);
    v_line     NUMERIC(14,2);
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT status INTO v_status FROM shipments WHERE id_shipment = NEW.id_shipment;
        IF v_status IS NULL THEN
            RAISE EXCEPTION 'Отгрузка % не найдена', NEW.id_shipment;
        END IF;
        IF v_status <> 'оформлена' THEN
            RAISE EXCEPTION 'Нельзя изменять позиции отгрузки % в статусе «%»', NEW.id_shipment, v_status;
        END IF;

        SELECT current_volume, capacity, id_product
          INTO v_stock, v_capacity, v_product
          FROM tanks
         WHERE id_tank = NEW.id_tank
           FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Резервуар % не найден', NEW.id_tank;
        END IF;
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
            (SELECT s.shipment_date::timestamptz FROM shipments s WHERE s.id_shipment = NEW.id_shipment),
            NEW.id_product, NEW.id_tank, 'расход', -NEW.volume, NEW.id_shipment_item, 'Отгрузка'
        );

        UPDATE shipments
           SET total_amount = total_amount + ROUND(NEW.volume * NEW.price_per_liter, 2)
         WHERE id_shipment = NEW.id_shipment;

    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.id_shipment <> OLD.id_shipment
           OR NEW.id_product <> OLD.id_product
           OR NEW.id_tank <> OLD.id_tank THEN
            RAISE EXCEPTION 'Нельзя изменять документ, продукт или резервуар позиции';
        END IF;

        SELECT status INTO v_status FROM shipments WHERE id_shipment = NEW.id_shipment;
        IF v_status <> 'оформлена' THEN
            RAISE EXCEPTION 'Нельзя изменять позиции отгрузки % в статусе «%»', NEW.id_shipment, v_status;
        END IF;

        SELECT current_volume, capacity, id_product
          INTO v_stock, v_capacity, v_product
          FROM tanks
         WHERE id_tank = NEW.id_tank
           FOR UPDATE;
        IF v_product <> NEW.id_product THEN
            RAISE EXCEPTION 'Продукт не соответствует резервуару %', NEW.id_tank;
        END IF;

        v_delta := NEW.volume - OLD.volume;
        IF v_delta > 0 AND v_stock < v_delta THEN
            RAISE EXCEPTION 'Недостаточно топлива в резервуаре %: остаток %, требуется %',
                NEW.id_tank, v_stock, v_delta;
        END IF;
        IF v_delta < 0 AND v_stock + (-v_delta) > v_capacity THEN
            RAISE EXCEPTION 'Переполнение резервуара %: свободно %, требуется вернуть %',
                NEW.id_tank, v_capacity - v_stock, -v_delta;
        END IF;

        IF v_delta <> 0 THEN
            UPDATE tanks
               SET current_volume = current_volume - v_delta
             WHERE id_tank = NEW.id_tank;

            INSERT INTO stock_movements (
                movement_date, id_product, id_tank, movement_type, volume, comment
            ) VALUES (
                now(), NEW.id_product, NEW.id_tank, 'корректировка', -v_delta,
                'Корректировка позиции отгрузки №' || OLD.id_shipment_item
            );
        END IF;

        v_line := ROUND(NEW.volume * NEW.price_per_liter, 2)
                - ROUND(OLD.volume * OLD.price_per_liter, 2);
        IF v_line <> 0 THEN
            UPDATE shipments
               SET total_amount = total_amount + v_line
             WHERE id_shipment = NEW.id_shipment;
        END IF;

    ELSIF TG_OP = 'DELETE' THEN
        SELECT status INTO v_status FROM shipments WHERE id_shipment = OLD.id_shipment;
        IF v_status <> 'оформлена' THEN
            RAISE EXCEPTION 'Нельзя изменять позиции отгрузки % в статусе «%»', OLD.id_shipment, v_status;
        END IF;

        SELECT current_volume, capacity, id_product
          INTO v_stock, v_capacity, v_product
          FROM tanks
         WHERE id_tank = OLD.id_tank
           FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Резервуар % не найден', OLD.id_tank;
        END IF;
        IF v_stock + OLD.volume > v_capacity THEN
            RAISE EXCEPTION 'Переполнение резервуара %: свободно %, требуется вернуть %',
                OLD.id_tank, v_capacity - v_stock, OLD.volume;
        END IF;

        UPDATE tanks
           SET current_volume = current_volume + OLD.volume
         WHERE id_tank = OLD.id_tank;

        INSERT INTO stock_movements (
            movement_date, id_product, id_tank, movement_type, volume, comment
        ) VALUES (
            now(), OLD.id_product, OLD.id_tank, 'корректировка', OLD.volume,
            'Удаление позиции отгрузки №' || OLD.id_shipment_item
        );

        UPDATE shipments
           SET total_amount = total_amount - ROUND(OLD.volume * OLD.price_per_liter, 2)
         WHERE id_shipment = OLD.id_shipment;

        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_delivery_items_stock ON delivery_items;
CREATE TRIGGER trg_delivery_items_stock
AFTER INSERT OR UPDATE OR DELETE ON delivery_items
FOR EACH ROW EXECUTE FUNCTION fn_delivery_items_stock();

DROP TRIGGER IF EXISTS trg_shipment_items_stock ON shipment_items;
CREATE TRIGGER trg_shipment_items_stock
AFTER INSERT OR UPDATE OR DELETE ON shipment_items
FOR EACH ROW EXECUTE FUNCTION fn_shipment_items_stock();
