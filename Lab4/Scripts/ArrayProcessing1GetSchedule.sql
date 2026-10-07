-- 1. Выборка: Получить расписание сотрудников
SELECT es.sched_id, e.fio, es.schedule
FROM Employee_Schedules es 
JOIN Employees e ON es.id_employee = e.id_employee;
