\set ON_ERROR_STOP on
\pset pager off
\timing on

-- TP4 - Indices candidatos. Aplicar SOLO despues de guardar el plan "antes".
-- Son hipotesis a comprobar: no implican que PostgreSQL los vaya a usar ni que mejoren el tiempo.
BEGIN;

-- Cubre el filtro temporal y aporta los identificadores necesarios para llegar a pedido/detalle.
CREATE INDEX IF NOT EXISTS idx_tp4_pedido_fecha_id_cliente
    ON pedido (fecha DESC, id_pedido)
    INCLUDE (id_cliente);

-- Cubre las lineas que se alcanzan desde pedido ya filtrado por fecha, sin volver a la tabla.
CREATE INDEX IF NOT EXISTS idx_tp4_detalle_pedido_cobertura
    ON detalle_pedido (id_pedido)
    INCLUDE (id_producto, cantidad, precio_unitario);

-- Q3: parte desde un producto puntual y llega a sus detalles; permite Index Only Scan.
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
