INSERT INTO Tickets (id_preorder, seat_num, row_num, actual_price, id_session, id_employee)
VALUES (1, 1, 1, 800.00, 2, 1);

SELECT * FROM Preorders WHERE id_preorder = 1;