\set ON_ERROR_STOP on
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 6 - Actividad de laboratorio previa al chequeo de mantenimiento.
--
-- Reproduce operaciones habituales de la tienda para que pg_stat_user_tables muestre un
-- estado realista (tuplas muertas y filas modificadas desde el último ANALYZE):
--   * reposición de stock del 40 % del catálogo;
--   * actualización de precios de una categoría;
--   * baja lógica de 3.000 detalles de pedido.
-- Solo para la base de laboratorio:
--   psql -X -h localhost -U postgres -d foodstore -f tp8/sql/01_simular_actividad.sql
-- =====================================================================
BEGIN;
UPDATE producto SET stock = stock + 50 WHERE mod(id_producto, 5) IN (1, 3);
UPDATE producto SET precio_lista = round(precio_lista * 1.08, 2)
WHERE id_categoria = (SELECT min(id_categoria) FROM categoria);
UPDATE detalle_pedido SET deleted_at = now()
WHERE (id_pedido, id_producto) IN (
    SELECT id_pedido, id_producto FROM detalle_pedido
    WHERE deleted_at IS NULL ORDER BY id_pedido DESC LIMIT 3000);
COMMIT;
SELECT 'actividad simulada' AS estado, now() AS momento;
