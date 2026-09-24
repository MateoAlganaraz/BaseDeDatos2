CREATE INDEX idx_tp5_detalle_producto_pedido
    ON detalle_pedido (id_producto, id_pedido)
    INCLUDE (cantidad, precio_unitario);

CREATE INDEX idx_tp5_producto_nombre_activo_prefijo
    ON producto (nombre text_pattern_ops)
    INCLUDE (id_producto, precio_lista, stock)
    WHERE activo;

CREATE INDEX idx_tp5_cliente_apellido_prefijo
    ON cliente (apellido text_pattern_ops)
    INCLUDE (id_cliente, nombre, email);

ANALYZE detalle_pedido;
ANALYZE producto;
ANALYZE cliente;
