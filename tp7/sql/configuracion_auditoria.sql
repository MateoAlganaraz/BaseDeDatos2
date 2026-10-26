\set ON_ERROR_STOP on
\pset pager off

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 5 - Parte B.1: activación de la auditoría nativa en el servidor de desarrollo.
--
-- Ejecutar como superusuario (ALTER SYSTEM escribe postgresql.auto.conf):
--   psql -X -v ON_ERROR_STOP=1 -d food_store_tp7_lab -f tp7/sql/configuracion_auditoria.sql
-- Todos los parámetros elegidos se aplican con pg_reload_conf(): no requieren reinicio.
-- Para volver atrás: ver la sección "Reversión" de docs/informe_auditoria.md.
-- =====================================================================

\echo '== Valores ANTES =='
SELECT name, setting, context FROM pg_settings
WHERE name IN ('log_connections', 'log_disconnections', 'log_statement', 'log_line_prefix',
               'log_min_error_statement', 'log_timezone', 'log_destination', 'logging_collector')
ORDER BY name;

-- Quién se conecta y cuándo termina la sesión (incluye duración).
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
-- DDL + INSERT/UPDATE/DELETE/TRUNCATE/COPY FROM de todos los roles.
ALTER SYSTEM SET log_statement = 'mod';
-- Prefijo con los datos de auditoría: cuándo (%m), proceso (%p), quién (%u), en qué base (%d),
-- desde dónde (%h) y con qué aplicación (%a). %q omite el resto en procesos sin sesión.
ALTER SYSTEM SET log_line_prefix = '%m [%p] %q%u@%d %h app=%a ';
-- Las sentencias que fallan se registran completas aunque log_statement no las cubra.
ALTER SYSTEM SET log_min_error_statement = 'error';
-- Hora local de Food Store en el log.
ALTER SYSTEM SET log_timezone = 'America/Argentina/Buenos_Aires';

SELECT pg_reload_conf();

-- Granularidad por rol: la cuenta de la aplicación es la credencial más expuesta, por eso en
-- desarrollo se registran TODAS sus sentencias, incluidas las lecturas (necesario para ver una
-- lectura masiva en la Parte C). En producción esto se reemplazaría por auditoría de objeto
-- con pgaudit sobre usuario, ya que 'all' también deja en el log los argumentos de
-- fn_autenticar (ver informe_auditoria.md, punto 4).
ALTER ROLE app_web SET log_statement = 'all';

\echo '== Valores DESPUÉS (en esta sesión ya recargada) =='
SELECT name, setting, source FROM pg_settings
WHERE name IN ('log_connections', 'log_disconnections', 'log_statement', 'log_line_prefix',
               'log_min_error_statement', 'log_timezone')
ORDER BY name;

\echo '== Configuración específica por rol =='
SELECT r.rolname, s.setconfig
FROM pg_db_role_setting s
JOIN pg_roles r ON r.oid = s.setrole
WHERE r.rolname = 'app_web';
