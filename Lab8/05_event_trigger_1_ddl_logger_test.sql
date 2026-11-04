CREATE TABLE temp_promo_codes (
    id_promo SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL
);

ALTER TABLE temp_promo_codes ADD COLUMN discount INTEGER;

DROP TABLE temp_promo_codes;

SELECT * FROM ddl_audit_log ORDER BY log_id ASC;