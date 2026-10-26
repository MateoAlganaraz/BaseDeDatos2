\pset pager off

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 5 - Parte A.3: verificación de roles y privilegios contra la spec.
--
--   psql -X -d food_store_tp7_lab -f tp7/sql/verificacion_permisos.sql > tp7/docs/verificacion_permisos.txt
--
-- 1. \du: atributos y membresías.
-- 2. information_schema.role_table_grants (tablas), privilegios de columna y de funciones.
-- 3. Comparación "esperado vs. real" en ambos sentidos: ni más ni menos (0 y 0).
-- 4. Pruebas funcionales con SET ROLE: lo permitido funciona y lo prohibido falla.
--
-- Nota: information_schema.role_*_grants solo muestra privilegios donde el otorgante o
-- el beneficiario es un rol habilitado en la sesión. Los GRANT se registran a nombre del
-- dueño (food_store_owner), por eso las consultas se hacen con SET ROLE food_store_owner.
-- =====================================================================

\echo '== 1. \\du (roles del proyecto) =='
\du (food_store_owner|rol_*|app_web|admin_datos)

\echo '== 1. Membresías con sus opciones (PostgreSQL 16) =='
SELECT r.rolname AS rol, m.rolname AS miembro, am.admin_option, am.inherit_option, am.set_option
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.roleid
JOIN pg_roles m ON m.oid = am.member
WHERE r.rolname IN ('food_store_owner', 'rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'rol_auditor')
ORDER BY 1, 2;

SET ROLE food_store_owner;

\echo '== 2. information_schema.role_table_grants (sin el dueño) =='
SELECT grantee, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND grantee <> 'food_store_owner'
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

\echo '== 2. Privilegios a nivel de columna (pg_attribute.attacl) =='
SELECT g.grantee::regrole AS grantee, c.relname AS tabla, g.privilege_type,
       string_agg(a.attname, ', ' ORDER BY a.attnum) AS columnas
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(a.attacl) AS g
WHERE n.nspname = 'public' AND a.attacl IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

\echo '== 2. information_schema.role_routine_grants (sin el dueño) =='
SELECT grantee, routine_name, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public' AND grantee <> 'food_store_owner'
ORDER BY 1, 2;

RESET ROLE;

\echo '== 2. Privilegios de PUBLIC sobre tablas y funciones del esquema public (esperado: 0 y 0) =='
SELECT 'tablas' AS objeto, count(*) AS privilegios_public
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) g
WHERE n.nspname = 'public' AND c.relkind IN ('r', 'v', 'm') AND g.grantee = 0
UNION ALL
SELECT 'funciones', count(*)
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) g
WHERE n.nspname = 'public' AND g.grantee = 0;

\echo '== 2. Configuración por rol de login =='
SELECT r.rolname, s.setconfig FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole ORDER BY 1;

\echo '== 2. CONNECT sobre la base =='
SELECT coalesce(g.grantee::regrole::text, 'PUBLIC') AS grantee, g.privilege_type
FROM pg_database d
CROSS JOIN LATERAL aclexplode(d.datacl) g
WHERE d.datname = current_database()
ORDER BY 1, 2;

\echo '== 2. Privilegios por defecto para objetos futuros =='
SELECT pg_get_userbyid(d.defaclrole) AS para_objetos_de, coalesce(n.nspname, '(global)') AS esquema,
       CASE d.defaclobjtype WHEN 'r' THEN 'tablas' WHEN 'f' THEN 'funciones' ELSE d.defaclobjtype::text END AS tipo,
       d.defaclacl
FROM pg_default_acl d
LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
ORDER BY 1, 2;

-- ---------------------------------------------------------------------
-- 3. Esperado (matriz de design.md) vs. real
-- ---------------------------------------------------------------------
CREATE TEMP TABLE esperado (grantee text, objeto text, columna text, privilegio text);
INSERT INTO esperado VALUES
    -- R2.1
    ('rol_app_lectura', 'categoria', NULL, 'SELECT'), ('rol_app_lectura', 'producto', NULL, 'SELECT'),
    ('rol_app_lectura', 'cliente', NULL, 'SELECT'), ('rol_app_lectura', 'pedido', NULL, 'SELECT'),
    ('rol_app_lectura', 'detalle_pedido', NULL, 'SELECT'),
    -- R3.1
    ('rol_app_escritura', 'cliente', NULL, 'INSERT'), ('rol_app_escritura', 'pedido', NULL, 'INSERT'),
    ('rol_app_escritura', 'detalle_pedido', NULL, 'INSERT'),
    -- R3.1 v2: UPDATE por columna
    ('rol_app_escritura', 'cliente', 'nombre', 'UPDATE'), ('rol_app_escritura', 'cliente', 'apellido', 'UPDATE'),
    ('rol_app_escritura', 'cliente', 'email', 'UPDATE'), ('rol_app_escritura', 'cliente', 'telefono', 'UPDATE'),
    ('rol_app_escritura', 'cliente', 'deleted_at', 'UPDATE'),
    ('rol_app_escritura', 'pedido', 'forma_pago', 'UPDATE'), ('rol_app_escritura', 'pedido', 'deleted_at', 'UPDATE'),
    ('rol_app_escritura', 'detalle_pedido', 'cantidad', 'UPDATE'), ('rol_app_escritura', 'detalle_pedido', 'deleted_at', 'UPDATE'),
    -- R5.1
    ('rol_reportes', 'categoria', NULL, 'SELECT'), ('rol_reportes', 'producto', NULL, 'SELECT'),
    ('rol_reportes', 'pedido', NULL, 'SELECT'), ('rol_reportes', 'detalle_pedido', NULL, 'SELECT'),
    -- R6.1
    ('rol_auditor', 'auditoria_acceso', NULL, 'SELECT'),
    -- R3.2, R4.2
    ('rol_app_escritura', 'producto', 'stock', 'UPDATE'),
    ('rol_soporte', 'usuario', 'activo', 'UPDATE'),
    -- R3.3, R4.3
    ('rol_app_escritura', 'fn_autenticar', NULL, 'EXECUTE'),
    ('rol_soporte', 'fn_resetear_password', NULL, 'EXECUTE');
-- R2.2
INSERT INTO esperado
SELECT 'rol_app_lectura', 'usuario', c, 'SELECT'
FROM unnest(ARRAY['id_usuario', 'nombre', 'apellido', 'email', 'rol', 'activo']) AS c;
-- R4.1
INSERT INTO esperado
SELECT 'rol_soporte', 'usuario', c, 'SELECT'
FROM unnest(ARRAY['id_usuario', 'nombre', 'apellido', 'email', 'telefono', 'rol', 'fecha_alta',
                  'activo', 'intentos_fallidos', 'bloqueado_hasta']) AS c;

-- Lo "real" se toma de los catálogos (aclexplode sobre relacl, attacl y proacl): es la
-- misma información que muestran las vistas de information_schema de la sección 2, pero
-- sin depender del rol habilitado en la sesión.
CREATE TEMP TABLE real AS
SELECT g.grantee::regrole::text AS grantee, c.relname::text AS objeto, NULL::text AS columna, g.privilege_type::text AS privilegio
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) AS g
WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm') AND g.grantee <> c.relowner
UNION ALL
SELECT g.grantee::regrole::text, c.relname::text, a.attname::text, g.privilege_type
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(a.attacl) AS g
WHERE n.nspname = 'public' AND a.attacl IS NOT NULL
UNION ALL
SELECT CASE WHEN g.grantee = 0 THEN 'PUBLIC' ELSE g.grantee::regrole::text END, p.proname::text, NULL, g.privilege_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) AS g
WHERE n.nspname = 'public' AND g.grantee <> p.proowner;

\echo '== 3. Esperado vs. real (ni más ni menos: 0 y 0) =='
SELECT 'esperado EXCEPT real (falta otorgar)' AS control, count(*) AS filas FROM (TABLE esperado EXCEPT TABLE real) x
UNION ALL
SELECT 'real EXCEPT esperado (sobra)', count(*) FROM (TABLE real EXCEPT TABLE esperado) y
UNION ALL
SELECT 'privilegios esperados', count(*) FROM esperado
UNION ALL
SELECT 'privilegios reales', count(*) FROM real;

\echo '== 3. Detalle de diferencias, si las hubiera =='
(SELECT 'falta' AS tipo, * FROM esperado EXCEPT SELECT 'falta', * FROM real)
UNION ALL
(SELECT 'sobra', * FROM real EXCEPT SELECT 'sobra', * FROM esperado)
ORDER BY 1, 2, 3, 4;

-- ---------------------------------------------------------------------
-- 4. Pruebas funcionales: cada operación se ejecuta con SET LOCAL ROLE dentro de una
-- subtransacción que siempre se revierte.
-- Limitación: SET ROLE comprueba la membresía del usuario de SESIÓN (aquí, el superusuario),
-- así que "SET ROLE admin_datos" desde app_web, o "SET ROLE food_store_owner" desde
-- admin_datos, no se pueden probar de este modo: se prueban con conexiones reales de
-- app_web y admin_datos en auditoria_test.sql y simulacro_incidente.sql.
-- admin_datos no hereda nada de food_store_owner: sin SET ROLE ni siquiera tiene USAGE
-- sobre el esquema public (pruebas 26 y 27).
-- ---------------------------------------------------------------------
CREATE FUNCTION pg_temp.probar(p_rol text, p_sql text)
RETURNS text
LANGUAGE plpgsql
AS $fn$
BEGIN
    BEGIN
        EXECUTE format('SET LOCAL ROLE %I', p_rol);
        EXECUTE p_sql;
        RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = '__permitido__';
    EXCEPTION
        WHEN raise_exception THEN
            IF SQLERRM = '__permitido__' THEN RETURN 'permitido'; END IF;
            RETURN 'error: ' || SQLERRM;
        WHEN insufficient_privilege THEN
            RETURN 'denegado';
        WHEN OTHERS THEN
            RETURN 'error: ' || SQLERRM;
    END;
END
$fn$;

\echo '== 4. Pruebas funcionales (la columna coincide debe ser true en todas) =='
WITH pruebas (n, rol, operacion, esperado) AS (VALUES
    (1,  'rol_app_lectura',   'SELECT id_usuario, nombre, email FROM usuario LIMIT 1', 'permitido'),
    (2,  'rol_app_lectura',   'SELECT password_hash FROM usuario LIMIT 1', 'denegado'),
    (3,  'rol_app_lectura',   'SELECT telefono FROM usuario LIMIT 1', 'denegado'),
    (4,  'rol_app_lectura',   'INSERT INTO categoria (nombre) VALUES (''x'')', 'denegado'),
    (5,  'app_web',           'INSERT INTO pedido (id_cliente, forma_pago) VALUES ((SELECT min(id_cliente) FROM cliente), ''EFECTIVO'')', 'permitido'),
    (6,  'app_web',           'UPDATE producto SET stock = stock - 1 WHERE id_producto = (SELECT min(id_producto) FROM producto)', 'permitido'),
    (7,  'app_web',           'UPDATE producto SET precio_lista = 1 WHERE id_producto = (SELECT min(id_producto) FROM producto)', 'denegado'),
    (8,  'app_web',           'DELETE FROM detalle_pedido WHERE id_pedido = (SELECT min(id_pedido) FROM pedido)', 'denegado'),
    (9,  'app_web',           'SELECT fn_autenticar(''nadie@correo.test'', ''x'')', 'permitido'),
    (10, 'app_web',           'SELECT fn_resetear_password(17, ''ClaveNueva-2026'')', 'denegado'),
    (11, 'app_web',           'SELECT * FROM auditoria_acceso LIMIT 1', 'denegado'),
    (12, 'app_web',           'GRANT admin_datos TO rol_reportes', 'denegado'),
    (13, 'app_web',           'GRANT rol_soporte TO app_web', 'denegado'),
    (14, 'app_web',           'CREATE TABLE public.tabla_intrusa (x int)', 'denegado'),
    (28, 'app_web',           'UPDATE pedido SET deleted_at = now() WHERE id_pedido = (SELECT min(id_pedido) FROM pedido)', 'permitido'),
    (29, 'app_web',           'UPDATE pedido SET id_cliente = id_cliente WHERE id_pedido = (SELECT min(id_pedido) FROM pedido)', 'denegado'),
    (30, 'app_web',           'UPDATE detalle_pedido SET precio_unitario = 1 WHERE id_pedido = (SELECT min(id_pedido) FROM pedido)', 'denegado'),
    (31, 'rol_soporte',       'SELECT fn_resetear_password((SELECT min(id_usuario) FROM usuario WHERE rol = ''ADMIN''), ''ClaveNueva-2026'')', 'denegado'),
    (15, 'rol_soporte',       'SELECT telefono, bloqueado_hasta FROM usuario LIMIT 1', 'permitido'),
    (16, 'rol_soporte',       'SELECT password_hash FROM usuario LIMIT 1', 'denegado'),
    (17, 'rol_soporte',       'UPDATE usuario SET activo = false WHERE id_usuario = 17', 'permitido'),
    (18, 'rol_soporte',       'UPDATE usuario SET rol = ''ADMIN'' WHERE id_usuario = 17', 'denegado'),
    (19, 'rol_soporte',       'SELECT fn_resetear_password(17, ''ClaveNueva-2026'')', 'permitido'),
    (20, 'rol_soporte',       'SELECT * FROM pedido LIMIT 1', 'denegado'),
    (21, 'rol_reportes',      'SELECT count(*) FROM detalle_pedido', 'permitido'),
    (22, 'rol_reportes',      'SELECT * FROM cliente LIMIT 1', 'denegado'),
    (23, 'rol_reportes',      'SELECT nombre FROM usuario LIMIT 1', 'denegado'),
    (24, 'rol_auditor',       'SELECT * FROM auditoria_acceso LIMIT 1', 'permitido'),
    (25, 'rol_auditor',       'DELETE FROM auditoria_acceso', 'denegado'),
    (26, 'admin_datos',       'SELECT password_hash FROM public.usuario LIMIT 1', 'denegado'),
    (27, 'admin_datos',       'SELECT count(*) FROM public.pedido', 'denegado')
)
SELECT n, rol, operacion, esperado, pg_temp.probar(rol, operacion) AS obtenido,
       pg_temp.probar(rol, operacion) = esperado AS coincide
FROM pruebas
ORDER BY n;

\echo '== 4. ALTER DEFAULT PRIVILEGES en acción: tabla nueva creada por el dueño (se revierte) =='
BEGIN;
SET LOCAL ROLE food_store_owner;
CREATE TABLE tabla_futura_demo (id int);
CREATE FUNCTION fn_futura_demo() RETURNS int LANGUAGE sql RETURN 1;
RESET ROLE;
SELECT 'tabla_futura_demo' AS objeto, relacl::text AS acl FROM pg_class WHERE relname = 'tabla_futura_demo'
UNION ALL
SELECT 'fn_futura_demo()', proacl::text FROM pg_proc WHERE proname = 'fn_futura_demo';
ROLLBACK;
