INSERT INTO Clients (id_client, fio, phone) VALUES 
(1, 'Иванов Иван Иванович', '+79991234567'),
(2, 'Петрова Анна Сергеевна', '+79997654321');

INSERT INTO Halls (id_hall, name, capacity) VALUES 
(1, 'Основной зал', 150),
(2, 'VIP зал', 30);

INSERT INTO Suppliers (id_supplier, name) VALUES 
(1, 'Централ Партнершип'),
(2, 'Каро Прокат');

INSERT INTO Employees (id_employee, fio, role) VALUES 
(1, 'Смирнов Алексей', 'кассир'),
(2, 'Козлова Елена', 'администратор');

INSERT INTO Preorders (id_preorder, id_client, booking_datetime, status) VALUES 
(1, 1, '2026-10-05 14:00:00', 'активен'),
(2, 2, '2026-10-06 18:30:00', 'выкуплен');

INSERT INTO Invoices (id_invoice, invoice_number, delivery_date, id_supplier, license_cost) VALUES 
(1, 'INV-1001', '2026-10-01', 1, 95000.00),
(2, 'INV-1002', '2026-10-02', 2, 85000.00);

INSERT INTO Movies (id_movie, title, genre, duration, age_restriction, id_invoice) VALUES 
(1, 'Дюна: Часть вторая', 'Фантастика', 166, '12+', 1),
(2, 'Мастер и Маргарита', 'Драма', 157, '18+', 2);

INSERT INTO Sessions (id_session, session_datetime, base_price, id_hall, id_movie) VALUES 
(1, '2026-10-10 18:00:00', 450.00, 1, 1),
(2, '2026-10-10 21:00:00', 700.00, 2, 2);

INSERT INTO Tickets (id_ticket, id_preorder, seat_num, row_num, actual_price, id_session, id_employee) VALUES 
(1, 1, 12, 5, 450.00, 1, 1),
(2, 2, 1, 1, 700.00, 2, 1);
