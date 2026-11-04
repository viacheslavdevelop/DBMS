DO $$
BEGIN
    RAISE NOTICE '1. Все сеансы';
    CALL session_select(NULL, NULL, NULL);

    RAISE NOTICE ' 2. Сеанс с ID = 1 ';
    CALL session_select(1, NULL, NULL);

    RAISE NOTICE ' 3. Сеансы фильма с ID = 1 ';
    CALL session_select(NULL, 1, NULL);

    RAISE NOTICE ' 4. Сеансы в зале с ID = 1 ';
    CALL session_select(NULL, NULL, 1);
END;
$$;
