\set ON_ERROR_STOP off
\pset pager off
\pset border 2
SET client_encoding = 'UTF8';

\echo 'N01 — отгрузка при недостаточном остатке'
BEGIN;
INSERT INTO shipments (id_shipment, shipment_number, id_client, shipment_date, status, payment_type)
VALUES (21, 'ТЕСТ-ОТГ-01', 1, CURRENT_DATE, 'оформлена', 'безналичный');
INSERT INTO shipment_items (id_shipment, line_no, id_product, id_tank, volume, price_per_liter)
VALUES (21, 1, 1, 1, 999999.000, 60.00);
ROLLBACK;

\echo 'N02 — переполнение резервуара при приходе'
BEGIN;
INSERT INTO deliveries (id_delivery, delivery_number, id_supplier, delivery_date, invoice_number, status)
VALUES (22, 'ТЕСТ-ПСТ-02', 1, CURRENT_DATE, 'ТЕСТ-СФ-02', 'оформлена');
INSERT INTO delivery_items (id_delivery, line_no, id_product, id_tank, volume, price_per_liter)
VALUES (22, 1, 15, 15, 99999.000, 65.00);
ROLLBACK;

\echo 'N03 — несоответствие продукта и резервуара'
BEGIN;
INSERT INTO deliveries (id_delivery, delivery_number, id_supplier, delivery_date, invoice_number, status)
VALUES (23, 'ТЕСТ-ПСТ-03', 1, CURRENT_DATE, 'ТЕСТ-СФ-03', 'оформлена');
INSERT INTO delivery_items (id_delivery, line_no, id_product, id_tank, volume, price_per_liter)
VALUES (23, 1, 2, 1, 100.000, 55.00);
ROLLBACK;

\echo 'N04 — отрицательная цена за литр'
BEGIN;
INSERT INTO deliveries (id_delivery, delivery_number, id_supplier, delivery_date, invoice_number, status)
VALUES (24, 'ТЕСТ-ПСТ-04', 1, CURRENT_DATE, 'ТЕСТ-СФ-04', 'оформлена');
INSERT INTO delivery_items (id_delivery, line_no, id_product, id_tank, volume, price_per_liter)
VALUES (24, 1, 1, 1, 100.000, -5.00);
ROLLBACK;

\echo 'N05 — плотность продукта вне допустимого диапазона'
BEGIN;
INSERT INTO products (product_code, name, category, octane_rating, density, min_reserve)
VALUES ('ТЕСТ-01', 'Тестовый продукт', 'бензин', 95, 1200.00, 1000.000);
ROLLBACK;

\echo 'N06 — некорректный ИНН поставщика'
BEGIN;
INSERT INTO suppliers (name, inn, phone)
VALUES ('ООО «Тестовый поставщик»', '12345', '+7 (495) 000-00-00');
ROLLBACK;

\echo 'N07 — дублирование номера поставки'
BEGIN;
INSERT INTO deliveries (delivery_number, id_supplier, delivery_date, invoice_number, status)
VALUES ('ПСТ-2025-001', 1, CURRENT_DATE, 'ТЕСТ-СФ-07', 'оформлена');
ROLLBACK;

\echo 'N08 — удаление продукта, на который ссылается резервуар'
BEGIN;
DELETE FROM products WHERE id_product = 1;
ROLLBACK;

\echo 'N09 — удаление поставки, у которой есть позиции'
BEGIN;
DELETE FROM deliveries WHERE id_delivery = 1;
ROLLBACK;

\echo 'N10 — изменение позиции принятой поставки'
BEGIN;
UPDATE delivery_items
SET volume = volume + 1
WHERE id_delivery_item = (SELECT min(id_delivery_item) FROM delivery_items WHERE id_delivery = 1);
ROLLBACK;

\echo 'N11 — отрицательный остаток в резервуаре'
BEGIN;
UPDATE tanks SET current_volume = -1 WHERE id_tank = 1;
ROLLBACK;

\echo 'N12 — отмена уже отгруженной отгрузки'
BEGIN;
UPDATE shipments SET status = 'отменена' WHERE id_shipment = 1;
ROLLBACK;
