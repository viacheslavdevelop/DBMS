\pset pager off
\pset border 2
\pset null '(null)'
\echo 'Q14 — динамика закупочной цены по каждому продукту'

SELECT p.product_code,
       ph.effective_date,
       ph.purchase_price,
       ph.retail_price,
       LAG(ph.purchase_price) OVER (
           PARTITION BY ph.id_product ORDER BY ph.effective_date
       ) AS prev_purchase_price,
       ph.purchase_price - LAG(ph.purchase_price) OVER (
           PARTITION BY ph.id_product ORDER BY ph.effective_date
       ) AS purchase_delta
FROM price_history ph
JOIN products p ON p.id_product = ph.id_product
ORDER BY p.product_code, ph.effective_date;
