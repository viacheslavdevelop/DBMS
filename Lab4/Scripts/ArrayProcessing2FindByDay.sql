-- 2. Выборка: Найти всех сотрудников, работающих в пятницу
SELECT 
    e.fio,
    es.sched_id,
    es.schedule
FROM Employee_Schedules es
JOIN Employees e ON es.id_employee = e.id_employee
WHERE 6 = ANY(es.schedule);