\pset pager off
SET TimeZone = 'America/Argentina/Buenos_Aires';

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 5 - Parte C.2: ¿el escalamiento falló? Verificación posterior al simulacro.
-- Se ejecuta como superusuario, con la vista del administrador, no la del atacante.
--   psql -X -d food_store_tp7_lab -f tp7/sql/simulacro_verificacion.sql
-- =====================================================================

\echo '== C.2.1 Membresías en admin_datos (esperado: ninguna) =='
SELECT m.rolname AS miembro, r.rolname AS rol
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.roleid
JOIN pg_roles m ON m.oid = am.member
WHERE r.rolname = 'admin_datos';

\echo '== C.2.2 Membresías de app_web y rol_reportes (esperado: sin cambios respecto de roles.sql) =='
SELECT m.rolname AS miembro, r.rolname AS es_miembro_de, am.inherit_option, am.set_option
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.roleid
JOIN pg_roles m ON m.oid = am.member
WHERE m.rolname IN ('app_web', 'rol_reportes')
ORDER BY 1, 2;

\echo '== C.2.3 La cuenta 1 no recibió un reseteo de contraseña (esperado: 0 eventos RESET_PASSWORD) =='
SELECT count(*) AS resets_cuenta_1 FROM auditoria_acceso WHERE evento = 'RESET_PASSWORD' AND id_usuario = 1;

\echo '== C.2.4 Registro de accesos de la aplicación durante el simulacro (application_name sqlcli) =='
SELECT id_evento, to_char(fecha, 'YYYY-MM-DD HH24:MI:SS.MS') AS fecha, evento, id_usuario, rol_db, ip_origen, aplicacion
FROM auditoria_acceso
WHERE aplicacion = 'sqlcli'
ORDER BY id_evento;

\echo '== C.2.5 Estado de la cuenta atacada =='
SELECT id_usuario, rol, activo, intentos_fallidos, bloqueado_hasta
FROM usuario WHERE id_usuario = 17;
