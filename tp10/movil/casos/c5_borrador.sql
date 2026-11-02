PRAGMA foreign_keys = ON;
.headers on
.mode column
.echo on
-- C5: borrador sin cambios posteriores en el servidor (productos 110 y 111).
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c5000000-0000-4000-8000-000000000001', 'tablet-feria-01', 'TRANSFERENCIA');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'c5000000-0000-4000-8000-000000000001', id, 3, precio_centavos FROM catalogo_disponible WHERE id = 110;
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'c5000000-0000-4000-8000-000000000001', id, 1, precio_centavos FROM catalogo_disponible WHERE id = 111;
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('c5000000-0000-4000-9000-000000000001', 'c5000000-0000-4000-8000-000000000001');
COMMIT;
