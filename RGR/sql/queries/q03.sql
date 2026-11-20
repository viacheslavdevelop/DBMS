\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q03 — активные поставщики с телефоном +7 или контактным лицом'

SELECT id_supplier, name, inn, phone, contact_person
FROM suppliers
WHERE is_active = TRUE
  AND (phone LIKE '+7%' OR contact_person IS NOT NULL)
ORDER BY name;
