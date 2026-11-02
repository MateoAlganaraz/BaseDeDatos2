-- =====================================================================
-- TP N.º 8 - Caso C4 (preparación en el servidor de PRUEBAS): baja lógica del producto 109.
-- La fila no se borra (deleted_at): la instantánea la envía como lápida.
-- =====================================================================
BEGIN;
UPDATE public.producto SET deleted_at = now()
WHERE id_producto = 109 AND deleted_at IS NULL;
SELECT id_producto, activo, deleted_at IS NOT NULL AS dado_de_baja
FROM public.producto WHERE id_producto = 109;
COMMIT;
