INSERT INTO Preorders (id_client, booking_datetime, status)
VALUES (1, now(), 'отменен');

INSERT INTO Tickets (id_preorder, seat_num, row_num, actual_price, id_session, id_employee)
VALUES ((SELECT MAX(id_preorder) FROM Preorders WHERE status = 'отменен'), 15, 2, 450.00, 1, 1);