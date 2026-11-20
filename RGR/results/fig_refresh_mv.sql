\echo 'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_stock;'
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_stock;
\echo 'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;'
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;
SELECT 'mv_product_stock' AS matview, COUNT(*) AS rows FROM mv_product_stock
UNION ALL SELECT 'mv_monthly_sales', COUNT(*) FROM mv_monthly_sales;
