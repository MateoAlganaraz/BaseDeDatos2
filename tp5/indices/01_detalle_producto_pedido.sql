-- Q1 - Historial de ventas por producto.
-- Aceptado tras comprobar que evita el Parallel Seq Scan de detalle_pedido.
CREATE INDEX idx_tp5_detalle_producto_pedido
    ON detalle_pedido (id_producto, id_pedido)
    INCLUDE (cantidad, precio_unitario);

ANALYZE detalle_pedido;
