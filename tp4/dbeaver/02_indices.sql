-- TP4 - Indices candidatos para DBeaver. Ejecutar solo despues de capturar los planes "antes".
BEGIN;

CREATE INDEX IF NOT EXISTS idx_tp4_pedido_fecha_id_cliente
    ON pedido (fecha DESC, id_pedido)
    INCLUDE (id_cliente);

CREATE INDEX IF NOT EXISTS idx_tp4_detalle_pedido_cobertura
    ON detalle_pedido (id_pedido)
    INCLUDE (id_producto, cantidad, precio_unitario);

CREATE INDEX IF NOT EXISTS idx_tp4_detalle_producto_pedido
    ON detalle_pedido (id_producto, id_pedido)
    INCLUDE (cantidad, precio_unitario);

COMMIT;

ANALYZE pedido;
ANALYZE detalle_pedido;
ANALYZE producto;
ANALYZE categoria;
ANALYZE cliente;

SELECT indexrelid::regclass AS indice,
       pg_get_indexdef(indexrelid) AS definicion
FROM pg_index
WHERE indexrelid IN (
    'idx_tp4_pedido_fecha_id_cliente'::regclass,
    'idx_tp4_detalle_pedido_cobertura'::regclass,
    'idx_tp4_detalle_producto_pedido'::regclass
)
ORDER BY indexrelid::regclass::text;
