-- =====================================================================
-- TP N.º 8 - Caso C2 (preparación en el servidor de PRUEBAS): sube el precio del producto 101.
-- Representa un cambio de precio hecho en PostgreSQL, la fuente de verdad, mientras la tablet
-- tenía un borrador con el precio anterior. No lo hace la tablet.
-- =====================================================================
BEGIN;
UPDATE public.producto SET precio_lista = round(precio_lista * 1.05, 2)
WHERE id_producto = 101;
SELECT id_producto, precio_lista, (precio_lista * 100)::bigint AS precio_centavos
FROM public.producto WHERE id_producto = 101;
COMMIT;
