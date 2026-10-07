-- 4. Обновление: Удалить рабочий день
UPDATE Employee_Schedules 
SET schedule = array_remove(schedule, 4) 
WHERE id_employee = 1;