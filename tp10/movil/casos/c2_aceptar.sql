PRAGMA foreign_keys = ON;
.headers on
.mode column
.echo on
-- C2 (2/2): el cliente acepta el precio nuevo. La tablet ya recargó el catálogo
-- (cargar_snapshot.sql), actualiza el precio visto del borrador y envía una solicitud NUEVA.
-- La solicitud en CONFLICTO no se reabre: queda como registro.
BEGIN;
UPDATE item_borrador
SET precio_centavos_visto = (SELECT p.precio_centavos FROM producto_cache p WHERE p.id = item_borrador.producto_id)
WHERE id_local = 'c2000000-0000-4000-8000-000000000001';
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('c2000000-0000-4000-9000-000000000002', 'c2000000-0000-4000-8000-000000000001');
COMMIT;
SELECT i.producto_id, i.precio_centavos_visto, p.precio_centavos AS precio_en_cache
FROM item_borrador i JOIN producto_cache p ON p.id = i.producto_id
WHERE i.id_local = 'c2000000-0000-4000-8000-000000000001';
