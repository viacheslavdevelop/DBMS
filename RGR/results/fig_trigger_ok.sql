BEGIN;
SELECT current_volume AS before_volume FROM tanks WHERE id_tank = 1;
INSERT INTO deliveries (id_supplier, delivery_number, delivery_date, invoice_number, status)
VALUES (1, 'TEST-TRG-001', DATE '2026-06-01', 'INV-TRG-001', 'оформлена')
RETURNING id_delivery
\gset
INSERT INTO delivery_items (id_delivery, id_product, id_tank, line_no, volume, price_per_liter)
VALUES (:id_delivery, 1, 1, 1, 1000, 55.00);
SELECT current_volume AS after_volume FROM tanks WHERE id_tank = 1;
SELECT d.total_amount,
       (SELECT SUM(total_cost) FROM delivery_items WHERE id_delivery = :id_delivery) AS items_sum
FROM deliveries d WHERE d.id_delivery = :id_delivery;
SELECT movement_type, volume, id_delivery_item IS NOT NULL AS linked_to_item
FROM stock_movements
WHERE id_delivery_item = (SELECT id_delivery_item FROM delivery_items WHERE id_delivery = :id_delivery);
ROLLBACK;
