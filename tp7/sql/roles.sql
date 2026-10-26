\set ON_ERROR_STOP on
\pset pager off

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 5 - Parte A: roles y permisos de mínimo privilegio para Food Store.
--
-- Implementa la matriz de docs/kiro_roles_spec/design.md. Cada GRANT indica el
-- requisito (R#) de docs/kiro_roles_spec/requirements.md que lo justifica.
-- Versión 2: incorpora las correcciones aceptadas de la auditoría hecha con IA
-- (BITACORA.md, registro A2); las rechazadas están justificadas allí.
--
-- Ejecutar como superusuario sobre la copia de laboratorio, después de 00_base_usuarios.sql:
--   psql -X -v ON_ERROR_STOP=1 -d food_store_tp7_lab -f tp7/sql/roles.sql
-- Es idempotente: si los roles ya existen, los elimina (con sus privilegios en esta
-- base) y los vuelve a crear. Los roles son globales del clúster: no ejecutar en un
-- servidor compartido donde otros proyectos usen los mismos nombres.
--
-- Las contraseñas NO se definen aquí (R7.3): ver scripts/run_tp7.sh.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Limpieza idempotente
-- ---------------------------------------------------------------------
DO $limpieza$
DECLARE
    v_rol text;
BEGIN
    FOREACH v_rol IN ARRAY ARRAY['app_web', 'admin_datos', 'rol_app_lectura', 'rol_app_escritura',
                                 'rol_soporte', 'rol_reportes', 'rol_auditor', 'food_store_owner']
    LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_rol) THEN
            EXECUTE format('REASSIGN OWNED BY %I TO %I', v_rol, current_user);
            EXECUTE format('DROP OWNED BY %I', v_rol);
            EXECUTE format('DROP ROLE %I', v_rol);
        END IF;
    END LOOP;
END
$limpieza$;

-- ---------------------------------------------------------------------
-- 1. Roles (R1 a R7)
-- ---------------------------------------------------------------------
-- R1: dueño de los objetos, sin login.
CREATE ROLE food_store_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

-- Roles de grupo: concentran privilegios; nunca tienen login.
CREATE ROLE rol_app_lectura   NOLOGIN;   -- R2: lectura de la aplicación web
CREATE ROLE rol_app_escritura NOLOGIN;   -- R3: altas y modificaciones de la aplicación web
CREATE ROLE rol_soporte       NOLOGIN;   -- R4: atención de cuentas de usuario
CREATE ROLE rol_reportes      NOLOGIN;   -- R5: reportes sin datos personales
CREATE ROLE rol_auditor       NOLOGIN;   -- R6: lectura del registro de accesos (rol adicional)

-- R7: roles de login, sin contraseña en el repositorio.
CREATE ROLE app_web LOGIN CONNECTION LIMIT 50
    NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
CREATE ROLE admin_datos LOGIN CONNECTION LIMIT 5
    NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

GRANT rol_app_lectura, rol_app_escritura TO app_web;
-- R1.3: admin_datos puede actuar como dueño solo con SET ROLE explícito (PostgreSQL 16+).
GRANT food_store_owner TO admin_datos WITH INHERIT FALSE, SET TRUE;

COMMENT ON ROLE food_store_owner  IS 'Dueño de los objetos de Food Store. Sin login. R1';
COMMENT ON ROLE rol_app_lectura   IS 'SELECT de catálogo, clientes, pedidos y columnas no sensibles de usuario. R2';
COMMENT ON ROLE rol_app_escritura IS 'INSERT/UPDATE de clientes y pedidos, UPDATE(stock), EXECUTE fn_autenticar. R3';
COMMENT ON ROLE rol_soporte       IS 'Lectura de cuentas sin hash, UPDATE(activo), EXECUTE fn_resetear_password. R4';
COMMENT ON ROLE rol_reportes      IS 'SELECT de ventas y catálogo; usuario_anon. Sin datos personales. R5';
COMMENT ON ROLE rol_auditor       IS 'SELECT sobre auditoria_acceso. R6';
COMMENT ON ROLE app_web           IS 'Login de la aplicación web. R7.1';
COMMENT ON ROLE admin_datos       IS 'Login del administrador de datos; SET ROLE food_store_owner para DDL. R7.2';

-- ---------------------------------------------------------------------
-- 2. Propiedad de los objetos (R1)
-- ---------------------------------------------------------------------
DO $propiedad$
DECLARE
    v_obj record;
BEGIN
    FOR v_obj IN
        SELECT format('ALTER %s %I.%I OWNER TO food_store_owner',
                      CASE c.relkind WHEN 'v' THEN 'VIEW' WHEN 'm' THEN 'MATERIALIZED VIEW'
                                     WHEN 'S' THEN 'SEQUENCE' ELSE 'TABLE' END,
                      n.nspname, c.relname) AS sentencia
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relkind IN ('r', 'p', 'v', 'm', 'S')
          AND NOT EXISTS (SELECT 1 FROM pg_depend d          -- secuencias de identidad: siguen a su tabla
                          WHERE d.objid = c.oid AND d.deptype = 'i')
        UNION ALL
        SELECT format('ALTER FUNCTION %s OWNER TO food_store_owner', p.oid::regprocedure)
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
        UNION ALL
        SELECT format('ALTER TYPE %I.%I OWNER TO food_store_owner', n.nspname, t.typname)
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'public' AND t.typtype = 'e'
    LOOP
        EXECUTE v_obj.sentencia;
    END LOOP;
END
$propiedad$;

-- El dueño crea objetos en public y usa pgcrypto desde las funciones SECURITY DEFINER.
GRANT USAGE, CREATE ON SCHEMA public TO food_store_owner;
GRANT USAGE ON SCHEMA extensiones TO food_store_owner;

-- ---------------------------------------------------------------------
-- 3. Superficie pública (R8.1, R8.2)
-- ---------------------------------------------------------------------
DO $base$
BEGIN
    EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database());
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO app_web, admin_datos', current_database());
    -- Revisión A2: CONNECT también para los roles de grupo de personas, para que sus futuros
    -- logins (p. ej. GRANT rol_soporte TO op_soporte_1) puedan conectarse por membresía.
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO rol_soporte, rol_reportes, rol_auditor', current_database());
END
$base$;

REVOKE ALL ON SCHEMA public      FROM PUBLIC;
REVOKE ALL ON SCHEMA extensiones FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
-- Revisión A2: ROUTINES incluye funciones y procedimientos.
REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA extensiones FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensiones TO food_store_owner;

GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, rol_auditor;

-- ---------------------------------------------------------------------
-- 4. Privilegios de los roles de grupo (matriz del diseño)
-- ---------------------------------------------------------------------
-- R2.1
GRANT SELECT ON categoria, producto, cliente, pedido, detalle_pedido TO rol_app_lectura;
-- R2.2: permiso a nivel de columna; password_hash, telefono y estado de bloqueo quedan fuera (R2.3).
GRANT SELECT (id_usuario, nombre, apellido, email, rol, activo) ON usuario TO rol_app_lectura;

-- R3.1: sin DELETE ni TRUNCATE (R3.4); la baja es lógica con UPDATE de deleted_at.
-- Revisión A2: UPDATE solo en las columnas que la aplicación modifica (no claves ni FK).
GRANT INSERT ON cliente, pedido, detalle_pedido TO rol_app_escritura;
GRANT UPDATE (nombre, apellido, email, telefono, deleted_at) ON cliente TO rol_app_escritura;
GRANT UPDATE (forma_pago, deleted_at) ON pedido TO rol_app_escritura;
GRANT UPDATE (cantidad, deleted_at) ON detalle_pedido TO rol_app_escritura;
-- R3.2: al vender solo se modifica el stock.
GRANT UPDATE (stock) ON producto TO rol_app_escritura;
-- R3.3
GRANT EXECUTE ON FUNCTION fn_autenticar(text, text) TO rol_app_escritura;

-- R4.1: todas las columnas de usuario salvo password_hash.
GRANT SELECT (id_usuario, nombre, apellido, email, telefono, rol, fecha_alta,
              activo, intentos_fallidos, bloqueado_hasta) ON usuario TO rol_soporte;
-- R4.2
GRANT UPDATE (activo) ON usuario TO rol_soporte;
-- R4.3
GRANT EXECUTE ON FUNCTION fn_resetear_password(bigint, text) TO rol_soporte;

-- R5.1 (el SELECT sobre usuario_anon se otorga en usuario_anon.sql, cuando la tabla existe).
GRANT SELECT ON categoria, producto, pedido, detalle_pedido TO rol_reportes;

-- R6: solo lectura; las funciones SECURITY DEFINER son las únicas que escriben.
GRANT SELECT ON auditoria_acceso TO rol_auditor;

-- ---------------------------------------------------------------------
-- 5. Tablas y funciones futuras (R8.3, R8.4)
-- ---------------------------------------------------------------------
-- Política: toda tabla nueva nace sin privilegios para nadie más que su dueño, y cada
-- permiso se otorga explícitamente después de justificarlo (igual que en este script).
-- Versión 1 otorgaba SELECT automático a rol_app_lectura; se quitó en la revisión A2 porque
-- una tabla futura con datos personales (p. ej. tokens de recuperación) quedaba legible
-- para la aplicación sin que nadie lo decidiera.
ALTER DEFAULT PRIVILEGES FOR ROLE food_store_owner IN SCHEMA public
    REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE food_store_owner IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM PUBLIC;
-- La revocación del EXECUTE por defecto a PUBLIC debe ser global (sin IN SCHEMA).
ALTER DEFAULT PRIVILEGES FOR ROLE food_store_owner
    REVOKE EXECUTE ON ROUTINES FROM PUBLIC;

-- ---------------------------------------------------------------------
-- 6. Límites de sesión de la aplicación (revisión A2). Se fijan en el rol de login porque
-- ALTER ROLE ... SET no se hereda de los roles de grupo.
-- ---------------------------------------------------------------------
ALTER ROLE app_web SET search_path = public;
ALTER ROLE app_web SET statement_timeout = '10s';
ALTER ROLE app_web SET idle_in_transaction_session_timeout = '30s';

\echo 'roles.sql aplicado. Verificar con sql/verificacion_permisos.sql'
