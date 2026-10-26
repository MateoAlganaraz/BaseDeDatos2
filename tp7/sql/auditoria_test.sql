\pset pager off

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 5 - Parte B.2: secuencia de prueba de la auditoría.
--
-- Se ejecuta con conexiones TCP reales (host 127.0.0.1) para que el log registre el origen.
-- Las contraseñas de app_web y admin_datos se toman de un archivo PGPASSFILE temporal que
-- arma scripts/run_tp7.sh; no están en el repositorio.
--   psql -X -v db=food_store_tp7_lab -f tp7/sql/auditoria_test.sql
--
-- Secuencia: lectura, inserción, actualización (app_web), un inicio de sesión fallido contra
-- el motor, una autenticación fallida de la aplicación y una operación privilegiada de
-- admin_datos con SET ROLE. Deja un pedido nuevo y descuenta 2 unidades de stock en la base
-- de laboratorio (es una prueba con efecto real, como la operación que se quiere auditar).
-- ON_ERROR_STOP queda desactivado a propósito: el intento fallido debe producir un error.
-- =====================================================================

\set conn_app 'host=127.0.0.1 dbname=' :db ' user=app_web application_name=foodstore_web sslmode=require'
\set conn_app_mal 'host=127.0.0.1 dbname=' :db ' user=app_web password=TP7-AUDIT-incorrecta application_name=foodstore_web sslmode=require'
\set conn_admin 'host=127.0.0.1 dbname=' :db ' user=admin_datos application_name=psql_admin sslmode=require'

\echo '== B.2.1 Conexión de la aplicación =='
\connect :conn_app
SELECT current_user, inet_client_addr() AS origen;

\echo '== B.2.2 Lectura =='
SELECT id_producto, nombre, precio_lista, stock
FROM producto
WHERE activo AND deleted_at IS NULL
ORDER BY id_producto
LIMIT 3;

\echo '== B.2.3 Inserción: pedido con un detalle =='
WITH nuevo AS (
    INSERT INTO pedido (id_cliente, forma_pago)
    VALUES ((SELECT min(id_cliente) FROM cliente WHERE deleted_at IS NULL), 'TARJETA')
    RETURNING id_pedido
)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT nuevo.id_pedido, p.id_producto, 2, p.precio_lista
FROM nuevo
CROSS JOIN producto p
WHERE p.id_producto = (SELECT min(id_producto) FROM producto);

\echo '== B.2.4 Actualización: descuento de stock =='
UPDATE producto SET stock = stock - 2
WHERE id_producto = (SELECT min(id_producto) FROM producto);

\echo '== B.2.5 Autenticación fallida de la aplicación (fn_autenticar) =='
SELECT fn_autenticar('nadie.tp7audit@correo.test', 'TP7-AUDIT-clave-erronea') AS autenticado;


\echo '== B.2.6 Operación privilegiada: admin_datos con SET ROLE explícito =='
\connect :conn_admin
SELECT current_user;
SELECT count(*) FROM public.producto;            -- falla: sin SET ROLE no hereda nada
SET ROLE food_store_owner;
COMMENT ON TABLE producto IS 'Catálogo de Food Store (comentario agregado en la prueba TP7-AUDIT)';
RESET ROLE;

-- Va al final porque, en un script, un \connect fallido cierra la conexión anterior y psql
-- no ejecuta lo que sigue.
\echo '== B.2.7 Inicio de sesión fallido contra el motor (contraseña incorrecta) =='
\connect :conn_app_mal
\echo '== Fin de la secuencia de prueba =='
