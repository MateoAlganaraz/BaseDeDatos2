PRAGMA foreign_keys = ON;
.headers on
.mode column
.echo on
-- C3: borrador por más unidades de las que quedan del producto 106 (stock visto + 6).
-- El stock que ve la tablet no es una reserva: la tablet deja armar el borrador y el
-- semáforo lo frena contra el stock del servidor.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c3000000-0000-4000-8000-000000000001', 'tablet-feria-01', 'TARJETA');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'c3000000-0000-4000-8000-000000000001', id, stock_visto + 6, precio_centavos
FROM catalogo_disponible WHERE id = 106;
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('c3000000-0000-4000-9000-000000000001', 'c3000000-0000-4000-8000-000000000001');
COMMIT;
SELECT i.producto_id, i.cantidad, p.stock_visto FROM item_borrador i JOIN producto_cache p ON p.id = i.producto_id
WHERE i.id_local = 'c3000000-0000-4000-8000-000000000001';
