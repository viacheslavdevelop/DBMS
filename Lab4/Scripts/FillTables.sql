INSERT INTO Employee_Schedules (id_employee, schedule) VALUES
(1, '{1, 3, 5, 6, 7}'::integer[]),
(2, '{1, 2, 5, 7}'::integer[]);

INSERT INTO Client_Details (id_client, details) VALUES
(1, '{"favorite_genres": ["комедия", "фантастика"], "has_vip": true, "visits": 5}'::jsonb),
(2, '{"favorite_genres": ["драма", "детектив"], "has_vip": false, "visits": 1}'::jsonb);
