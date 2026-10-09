SELECT 
    id_session, 
    base_price AS "Базовая цена",
    CASE 
        WHEN base_price < 200 THEN 'Бюджетный'
        WHEN base_price <= 500 THEN 'Стандарт'
        ELSE 'Премиум'
    END AS "Категория сеанса"
FROM Sessions
ORDER BY base_price;
