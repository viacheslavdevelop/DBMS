-- 3. Обновление: Добавить рабочий день сотруднику
UPDATE Employee_Schedules 
SET schedule = schedule || 4 
WHERE id_employee = 1;