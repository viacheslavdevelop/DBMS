CREATE TABLE Clients (
    id_client SERIAL PRIMARY KEY,
    fio VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL
);

CREATE TABLE Halls (
    id_hall SERIAL PRIMARY KEY,
    name VARCHAR(20) NOT NULL,
    capacity INTEGER NOT NULL CHECK (capacity > 0)
);

CREATE TABLE Suppliers (
    id_supplier SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE Employees (
    id_employee SERIAL PRIMARY KEY,
    fio VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL
);

CREATE TABLE Preorders (
    id_preorder SERIAL PRIMARY KEY,
    id_client INTEGER NOT NULL,
    booking_datetime TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('выкуплен', 'активен', 'отменен')),
    FOREIGN KEY (id_client) REFERENCES Clients(id_client) ON DELETE CASCADE
);

CREATE TABLE Invoices (
    id_invoice SERIAL PRIMARY KEY,
    invoice_number VARCHAR(20) NOT NULL,
    delivery_date DATE NOT NULL,
    id_supplier INTEGER NOT NULL,
    license_cost NUMERIC(7, 2) NOT NULL CHECK (license_cost >= 0),
    FOREIGN KEY (id_supplier) REFERENCES Suppliers(id_supplier) ON DELETE RESTRICT
);

CREATE TABLE Movies (
    id_movie SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    genre VARCHAR(30) NOT NULL,
    duration INTEGER NOT NULL CHECK (duration > 0),
    age_restriction VARCHAR(10) NOT NULL,
    id_invoice INTEGER NOT NULL,
    FOREIGN KEY (id_invoice) REFERENCES Invoices(id_invoice) ON DELETE RESTRICT
);

CREATE TABLE Sessions (
    id_session SERIAL PRIMARY KEY,
    session_datetime TIMESTAMP NOT NULL,
    base_price NUMERIC(5, 2) NOT NULL CHECK (base_price >= 0),
    id_hall INTEGER NOT NULL,
    id_movie INTEGER NOT NULL,
    FOREIGN KEY (id_hall) REFERENCES Halls(id_hall) ON DELETE RESTRICT,
    FOREIGN KEY (id_movie) REFERENCES Movies(id_movie) ON DELETE CASCADE
);

CREATE TABLE Tickets (
    id_ticket SERIAL PRIMARY KEY,
    id_preorder INTEGER,
    seat_num INTEGER NOT NULL CHECK (seat_num > 0),
    row_num INTEGER NOT NULL CHECK (row_num > 0),
    actual_price NUMERIC(5, 2) NOT NULL CHECK (actual_price >= 0),
    id_session INTEGER NOT NULL,
    id_employee INTEGER NOT NULL,
    FOREIGN KEY (id_preorder) REFERENCES Preorders(id_preorder) ON DELETE SET NULL,
    FOREIGN KEY (id_session) REFERENCES Sessions(id_session) ON DELETE CASCADE,
    FOREIGN KEY (id_employee) REFERENCES Employees(id_employee) ON DELETE RESTRICT,
    CONSTRAINT unique_seat_per_session UNIQUE (id_session, row_num, seat_num)
);