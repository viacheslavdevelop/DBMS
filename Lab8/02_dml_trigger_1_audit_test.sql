INSERT INTO Tickets (id_preorder, seat_num, row_num, actual_price, id_session, id_employee)
VALUES (NULL, 7, 3, 450.00, 1, 1);

UPDATE Tickets
SET actual_price = 400.00
WHERE id_session = 1 AND row_num = 3 AND seat_num = 5;

DELETE FROM Tickets
WHERE id_session = 1 AND row_num = 3 AND seat_num = 5;

SELECT * FROM tickets_audit ORDER BY audit_id ASC;
