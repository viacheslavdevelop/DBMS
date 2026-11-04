BEGIN;

INSERT INTO Clients (fio, phone)
VALUES ('Соколов Алексей Петрович', '+79131002030');

INSERT INTO Clients (fio, phone)
VALUES ('Морозова Мария Игоревна', '+79134005060');

SAVEPOINT sp_clients_valid;

INSERT INTO Clients (fio, phone)
VALUES ('Тестовый Клиент Ошибочный 1', '+79990000001');

INSERT INTO Clients (fio, phone)
VALUES ('Тестовый Клиент Ошибочный 2', '+79990000002');

ROLLBACK TO SAVEPOINT sp_clients_valid;

COMMIT;

SELECT * FROM Clients ORDER BY id_client ASC;