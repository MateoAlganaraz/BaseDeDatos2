PRAGMA foreign_keys = ON;
.headers on
.mode column
.echo on
-- C2 (1/2): borrador con el producto 101 al precio que muestra la tablet, y su solicitud.
-- Después, en el servidor, sube ese precio (servidor/c2_subir_precio.sql).
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c2000000-0000-4000-8000-000000000001', 'tablet-feria-01', 'EFECTIVO');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'c2000000-0000-4000-8000-000000000001', id, 2, precio_centavos FROM catalogo_disponible WHERE id = 101;
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('c2000000-0000-4000-9000-000000000001', 'c2000000-0000-4000-8000-000000000001');
COMMIT;
SELECT producto_id, cantidad, precio_centavos_visto FROM item_borrador
WHERE id_local = 'c2000000-0000-4000-8000-000000000001';
