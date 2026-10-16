INSERT INTO Preorders (id_client, booking_datetime, status)
VALUES (1, NOW(), 'активен')
RETURNING id_preorder;

CALL sp_sell_ticket(
    p_session_id   => 1,
    p_row_num      => 2,
    p_seat_num     => 5,
    p_employee_id  => 1,
    p_preorder_id  => 1,
    p_discount_pct => 10.00
);

SELECT 
    t.id_ticket,
    t.id_session,
    t.row_num,
    t.seat_num,
    t.actual_price,
    p.id_preorder,
    p.status AS preorder_status
FROM Tickets t
LEFT JOIN Preorders p ON t.id_preorder = p.id_preorder
WHERE t.id_session = 1 AND t.row_num = 2 AND t.seat_num = 5;