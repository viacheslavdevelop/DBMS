CREATE TABLE Employee_Schedules (
    sched_id SERIAL PRIMARY KEY,
    id_employee INTEGER NOT NULL,
    schedule integer[],
    CONSTRAINT fk_schedules_employee FOREIGN KEY (id_employee) 
        REFERENCES Employees (id_employee) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Client_Details (
    id_client INTEGER NOT NULL PRIMARY KEY,
    details jsonb,
    CONSTRAINT fk_details_client FOREIGN KEY (id_client) 
        REFERENCES Clients (id_client) ON DELETE CASCADE ON UPDATE CASCADE
);
