-- Parte 2: cambios aceptados SOLO despues de capturar 02 con tp3_fase=antes.
-- Ejecutar en la copia de laboratorio. No se ejecuta CREATE INDEX CONCURRENTLY
-- para conservar una transaccion atomica y reproducible en la practica.
BEGIN;

CREATE INDEX IF NOT EXISTS idx_tp3_producto_categoria_precio_activo
    ON producto (id_categoria, precio_lista DESC, id_producto)
    WHERE activo;

CREATE INDEX IF NOT EXISTS idx_tp3_pedido_forma_pago_fecha
    ON pedido (forma_pago, fecha DESC);

CREATE INDEX IF NOT EXISTS idx_tp3_pedido_fecha
    ON pedido (fecha);

DO $verificar_indices$
DECLARE
    definicion text;
BEGIN
    SELECT pg_get_indexdef('idx_tp3_producto_categoria_precio_activo'::regclass) INTO definicion;
    IF definicion NOT LIKE '%(id_categoria, precio_lista DESC, id_producto)%WHERE activo%' THEN
        RAISE EXCEPTION 'idx_tp3_producto_categoria_precio_activo existe con una definicion distinta: %', definicion;
    END IF;
    SELECT pg_get_indexdef('idx_tp3_pedido_forma_pago_fecha'::regclass) INTO definicion;
    IF definicion NOT LIKE '%(forma_pago, fecha DESC)%' THEN
        RAISE EXCEPTION 'idx_tp3_pedido_forma_pago_fecha existe con una definicion distinta: %', definicion;
    END IF;
    SELECT pg_get_indexdef('idx_tp3_pedido_fecha'::regclass) INTO definicion;
    IF definicion NOT LIKE '%(fecha)%' THEN
        RAISE EXCEPTION 'idx_tp3_pedido_fecha existe con una definicion distinta: %', definicion;
    END IF;
END
$verificar_indices$;

COMMIT;
ANALYZE VERBOSE producto;
ANALYZE VERBOSE pedido;

SELECT indexrelid::regclass AS indice, pg_get_indexdef(indexrelid) AS definicion
FROM pg_index
WHERE indexrelid IN (
    'idx_tp3_producto_categoria_precio_activo'::regclass,
    'idx_tp3_pedido_forma_pago_fecha'::regclass,
    'idx_tp3_pedido_fecha'::regclass
)
ORDER BY indexrelid::regclass::text;
