SET client_encoding = 'UTF8';

CREATE INDEX IF NOT EXISTS idx_tanks_product ON tanks (id_product);
CREATE INDEX IF NOT EXISTS idx_tanks_status ON tanks (status);
CREATE INDEX IF NOT EXISTS idx_price_product_date ON price_history (id_product, effective_date);
CREATE INDEX IF NOT EXISTS idx_deliveries_supplier_date ON deliveries (id_supplier, delivery_date);
CREATE INDEX IF NOT EXISTS idx_deliveries_status_date ON deliveries (status, delivery_date);
CREATE INDEX IF NOT EXISTS idx_delivery_items_delivery ON delivery_items (id_delivery);
CREATE INDEX IF NOT EXISTS idx_delivery_items_product ON delivery_items (id_product);
CREATE INDEX IF NOT EXISTS idx_delivery_items_tank ON delivery_items (id_tank);
CREATE INDEX IF NOT EXISTS idx_shipments_client_date ON shipments (id_client, shipment_date);
CREATE INDEX IF NOT EXISTS idx_shipments_status_date ON shipments (status, shipment_date);
CREATE INDEX IF NOT EXISTS idx_shipment_items_shipment ON shipment_items (id_shipment);
CREATE INDEX IF NOT EXISTS idx_shipment_items_product ON shipment_items (id_product);
CREATE INDEX IF NOT EXISTS idx_shipment_items_tank ON shipment_items (id_tank);
CREATE INDEX IF NOT EXISTS idx_movements_product_date ON stock_movements (id_product, movement_date);
CREATE INDEX IF NOT EXISTS idx_movements_tank_date ON stock_movements (id_tank, movement_date);
CREATE INDEX IF NOT EXISTS idx_forecasts_product_date ON reserve_forecasts (id_product, forecast_date);
CREATE INDEX IF NOT EXISTS idx_forecasts_deficit ON reserve_forecasts (id_product)
    WHERE predicted_reserve < 0;
