PRAGMA foreign_keys = ON;
.headers on
.mode column
.echo on
-- C4 (1/2): borrador con el producto 109. Después, en el servidor, se lo da de baja
-- (servidor/c4_baja_logica.sql).
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c4000000-0000-4000-8000-000000000001', 'tablet-feria-01', 'EFECTIVO');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'c4000000-0000-4000-8000-000000000001', id, 2, precio_centavos FROM catalogo_disponible WHERE id = 109;
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('c4000000-0000-4000-9000-000000000001', 'c4000000-0000-4000-8000-000000000001');
COMMIT;
