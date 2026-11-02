PRAGMA foreign_keys = ON;
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP N.º 8 (Unidad 8) - Consigna 2.a: importar la instantánea y recargar producto_cache.
--
-- Ejecutar con el CSV en la carpeta actual (sqlite3 resuelve la ruta desde ahí):
--   cd tp10/movil
--   sqlite3 foodstore_movil.db < cargar_snapshot.sql
--
-- 1. snapshot_servidor se reemplaza entera con el CSV exportado por psql (\copy ... CSV HEADER).
-- 2. producto_cache se actualiza con UPSERT: nunca se borran filas, porque los ítems de los
--    borradores las referencian. Un producto dado de baja queda con eliminado = 1 (lápida).
-- No se modifica ningún borrador ni ninguna solicitud.
-- =====================================================================

DELETE FROM snapshot_servidor;
.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor

BEGIN;
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, copiado_en)
SELECT id, nombre, precio_centavos, stock, disponible = 't', eliminado = 't', copiado_en
FROM snapshot_servidor
WHERE true
ON CONFLICT (id) DO UPDATE SET
    nombre          = excluded.nombre,
    precio_centavos = excluded.precio_centavos,
    stock_visto     = excluded.stock_visto,
    disponible      = excluded.disponible,
    eliminado       = excluded.eliminado,
    copiado_en      = excluded.copiado_en;
COMMIT;

.headers on
.mode column
SELECT 'instantánea cargada' AS paso,
       (SELECT count(*) FROM snapshot_servidor)   AS filas_snapshot,
       (SELECT count(*) FROM producto_cache)      AS filas_cache,
       (SELECT count(*) FROM catalogo_disponible) AS disponibles,
       (SELECT count(*) FROM producto_cache WHERE eliminado = 1) AS lapidas,
       (SELECT max(copiado_en) FROM snapshot_servidor) AS fecha_copia;
