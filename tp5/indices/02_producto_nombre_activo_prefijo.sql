-- Q2 - Autocompletado de productos activos por nombre.
CREATE INDEX idx_tp5_producto_nombre_activo_prefijo
    ON producto (nombre text_pattern_ops)
    INCLUDE (id_producto, precio_lista, stock)
    WHERE activo;

ANALYZE producto;
