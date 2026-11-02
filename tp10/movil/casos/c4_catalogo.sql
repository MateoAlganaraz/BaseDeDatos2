PRAGMA foreign_keys = ON;
.headers on
.mode column
.echo on
-- C4 (2/2): al recargar el catálogo, el 109 ya no aparece para vender, pero su fila queda
-- (lápida) y el borrador viejo sigue apuntándola.
SELECT count(*) AS en_catalogo_disponible FROM catalogo_disponible WHERE id = 109;
SELECT id, nombre, disponible, eliminado, copiado_en FROM producto_cache WHERE id = 109;
SELECT id_local, producto_id, cantidad FROM item_borrador WHERE producto_id = 109;
-- Un borrador nuevo ya no puede incluirlo (error esperado del trigger, sin filas nuevas):
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c4000000-0000-4000-8000-000000000002', 'tablet-feria-01', 'EFECTIVO');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c4000000-0000-4000-8000-000000000002', 109, 1, 63300);
DELETE FROM pedido_borrador WHERE id_local = 'c4000000-0000-4000-8000-000000000002';
SELECT count(*) AS items_nuevos_con_109 FROM item_borrador
WHERE producto_id = 109 AND id_local <> 'c4000000-0000-4000-8000-000000000001';
