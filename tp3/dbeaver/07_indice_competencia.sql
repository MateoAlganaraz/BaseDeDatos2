-- Parte 5. Ejecutar solamente sobre food_store_tp3_competencia despues del plan inicial.
-- Ataca el Seq Scan y el Sort de la consulta comun: conserva productos activos
-- en el orden precio_lista DESC, id_producto e incluye las columnas de salida.
BEGIN;

CREATE INDEX IF NOT EXISTS idx_tp3_comp_producto_precio_activo
    ON producto (precio_lista DESC, id_producto)
    INCLUDE (id_categoria, nombre, stock)
    WHERE activo;

DO $verificar_indice_competencia$
DECLARE
    definicion text;
BEGIN
    SELECT pg_get_indexdef('idx_tp3_comp_producto_precio_activo'::regclass)
    INTO definicion;
    IF definicion NOT LIKE '%(precio_lista DESC, id_producto)%INCLUDE (id_categoria, nombre, stock)%WHERE activo%' THEN
        RAISE EXCEPTION 'El indice de competencia existe con una definicion distinta: %', definicion;
    END IF;
END
$verificar_indice_competencia$;

COMMIT;
ANALYZE VERBOSE producto;

SELECT pg_get_indexdef('idx_tp3_comp_producto_precio_activo'::regclass) AS definicion_indice;
