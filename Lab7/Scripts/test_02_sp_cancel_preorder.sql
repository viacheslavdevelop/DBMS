INSERT INTO Preorders (id_client, booking_datetime, status)
VALUES (1, NOW(), 'активен');

CALL sp_cancel_preorder(2);

SELECT 
    id_preorder,
    id_client,
    booking_datetime,
    status
FROM Preorders
WHERE id_preorder = 2;