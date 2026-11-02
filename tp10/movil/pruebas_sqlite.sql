PRAGMA foreign_keys = ON;
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP N.º 8 (Unidad 8) - Consigna 1.c: pruebas de la base de la tablet.
--
-- Requiere el esquema y el catálogo cargados (schema_sqlite.sql y cargar_snapshot.sql):
--   cd tp10/movil
--   sqlite3 foodstore_movil.db < pruebas_sqlite.sql
-- Los errores de C7 son esperados: sqlite3 los informa y sigue con la línea siguiente.
-- Los UUID son fijos para que la prueba sea reproducible (en la tablet real se generan).
-- =====================================================================
.headers on
.mode column
.echo on

-- Las claves foráneas están activas en esta conexión (esperado: 1).
PRAGMA foreign_keys;

-- ---------------------------------------------------------------------
-- 1. Borrador completo (borrador + ítems + solicitud) con BEGIN ... COMMIT
-- ---------------------------------------------------------------------
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('1c000000-0000-4000-8000-000000000001', 'tablet-feria-01', 'EFECTIVO');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT '1c000000-0000-4000-8000-000000000001', id, 2, precio_centavos FROM catalogo_disponible WHERE id = 104;
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT '1c000000-0000-4000-8000-000000000001', id, 1, precio_centavos FROM catalogo_disponible WHERE id = 105;
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('1c000000-0000-4000-9000-000000000001', '1c000000-0000-4000-8000-000000000001');
COMMIT;

SELECT b.id_local, b.forma_pago, i.producto_id, i.cantidad, i.precio_centavos_visto, c.estado
FROM pedido_borrador b
JOIN item_borrador i USING (id_local)
JOIN cola_sync c USING (id_local)
WHERE b.id_local = '1c000000-0000-4000-8000-000000000001';

-- Otra operación, deshecha con ROLLBACK: el cliente se arrepiente antes de guardar.
SELECT 'antes del ROLLBACK' AS momento, (SELECT count(*) FROM pedido_borrador) AS borradores,
       (SELECT count(*) FROM item_borrador) AS items, (SELECT count(*) FROM cola_sync) AS solicitudes;
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('1c000000-0000-4000-8000-000000000002', 'tablet-feria-01', 'TARJETA');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT '1c000000-0000-4000-8000-000000000002', id, 3, precio_centavos FROM catalogo_disponible WHERE id = 103;
SELECT 'dentro de la transacción' AS momento, (SELECT count(*) FROM pedido_borrador) AS borradores,
       (SELECT count(*) FROM item_borrador) AS items;
ROLLBACK;
SELECT 'después del ROLLBACK' AS momento, (SELECT count(*) FROM pedido_borrador) AS borradores,
       (SELECT count(*) FROM item_borrador) AS items, (SELECT count(*) FROM cola_sync) AS solicitudes;

-- ---------------------------------------------------------------------
-- 2. Caso C1: el catálogo disponible se consulta solo con el archivo de la tablet.
-- sqlite3 no abre ninguna conexión de red; run_tp10.sh lo ejecuta con PostgreSQL detenido.
-- ---------------------------------------------------------------------
SELECT count(*) AS productos_disponibles, max(copiado_en) AS copia_del
FROM catalogo_disponible;
SELECT id, nombre, printf('%.2f', precio_centavos / 100.0) AS precio, stock_visto
FROM catalogo_disponible
WHERE id BETWEEN 101 AND 111
ORDER BY id;

-- ---------------------------------------------------------------------
-- 3. Caso C7: cantidad 0 y producto inexistente dan error y no dejan filas nuevas.
-- ---------------------------------------------------------------------
SELECT 'antes de C7' AS momento, (SELECT count(*) FROM pedido_borrador) AS borradores,
       (SELECT count(*) FROM item_borrador) AS items;

-- 3a. Ítem suelto con cantidad 0 sobre un borrador existente: lo rechaza el CHECK.
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('1c000000-0000-4000-8000-000000000001', 106, 0, 387200);

-- 3b. Ítem suelto con un producto que no existe: lo rechaza la clave foránea.
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('1c000000-0000-4000-8000-000000000001', 999999, 1, 100);

-- 3c. Borrador completo con los dos errores: la aplicación deshace todo con ROLLBACK.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('1c000000-0000-4000-8000-000000000007', 'tablet-feria-01', 'TRANSFERENCIA');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('1c000000-0000-4000-8000-000000000007', 107, 0, 345900);
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('1c000000-0000-4000-8000-000000000007', 999999, 1, 100);
ROLLBACK;

-- 3d. Otras reglas del esquema: forma de pago fuera de la lista y estado inválido.
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('1c000000-0000-4000-8000-000000000008', 'tablet-feria-01', 'CHEQUE');
UPDATE cola_sync SET estado = 'APROBADO' WHERE solicitud_uuid = '1c000000-0000-4000-9000-000000000001';

SELECT 'después de C7' AS momento, (SELECT count(*) FROM pedido_borrador) AS borradores,
       (SELECT count(*) FROM item_borrador) AS items,
       (SELECT count(*) FROM pedido_borrador
        WHERE id_local IN ('1c000000-0000-4000-8000-000000000007',
                           '1c000000-0000-4000-8000-000000000008')) AS borradores_de_c7;
