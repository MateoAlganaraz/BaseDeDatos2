\set ON_ERROR_STOP on
\pset pager off

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 6 - Revisión semanal de mantenimiento (SPEC_U6, regla 5).
--
-- 1. Revisa la configuración de autovacuum y el estado de cada tabla.
-- 2. Calcula, con la misma fórmula que usa autovacuum, si cada tabla ya superó su umbral de
--    VACUUM (50 + 0,2 × filas) o de ANALYZE (50 + 0,1 × filas) sin que autovacuum la haya
--    procesado todavía, o si nunca fue analizada.
-- 3. SOLO para esas tablas ejecuta VACUUM (ANALYZE): seguro (no bloquea lecturas ni
--    escrituras normales) y justificado por la observación del paso 2. Si ninguna tabla lo
--    necesita, no hace nada. Nunca usa VACUUM FULL (bloqueo exclusivo y reescritura completa).
-- 4. Vuelve a mostrar el estado para comprobar el efecto.
--
-- Requiere ser dueño de las tablas o superusuario (en PostgreSQL 16 no existe pg_maintain):
--   psql -X -h localhost -U postgres -d foodstore -f tp8/maintenance.sql
-- VACUUM no puede ejecutarse dentro de una transacción: \gexec ejecuta cada sentencia aparte.
-- =====================================================================

\echo '== 1. Configuración de autovacuum =='
SELECT name, setting, unit
FROM pg_settings
WHERE name IN ('autovacuum', 'autovacuum_naptime', 'autovacuum_vacuum_threshold',
               'autovacuum_vacuum_scale_factor', 'autovacuum_analyze_threshold',
               'autovacuum_analyze_scale_factor', 'autovacuum_max_workers')
ORDER BY name;

\echo '== 1. Trabajadores de autovacuum activos en este momento =='
SELECT pid, now() - xact_start AS duracion, left(query, 80) AS tarea
FROM pg_stat_activity
WHERE backend_type = 'autovacuum worker';

-- Vista temporal con el diagnóstico (se reutiliza antes y después).
CREATE TEMP VIEW diagnostico_mantenimiento AS
SELECT s.relname,
       c.reltuples::bigint AS filas_estimadas,
       s.n_live_tup, s.n_dead_tup,
       round(100.0 * s.n_dead_tup / nullif(s.n_live_tup + s.n_dead_tup, 0), 2) AS pct_muertas,
       (current_setting('autovacuum_vacuum_threshold')::int
        + current_setting('autovacuum_vacuum_scale_factor')::float8 * greatest(c.reltuples, 0))::bigint AS umbral_vacuum,
       s.n_mod_since_analyze,
       (current_setting('autovacuum_analyze_threshold')::int
        + current_setting('autovacuum_analyze_scale_factor')::float8 * greatest(c.reltuples, 0))::bigint AS umbral_analyze,
       greatest(s.last_vacuum, s.last_autovacuum)   AS ultimo_vacuum,
       greatest(s.last_analyze, s.last_autoanalyze) AS ultimo_analyze
FROM pg_stat_user_tables s
JOIN pg_class c ON c.oid = s.relid
WHERE s.schemaname = 'public';

\echo '== 2. Diagnóstico ANTES (requiere_vacuum / requiere_analyze según la fórmula de autovacuum) =='
SELECT relname, filas_estimadas, n_dead_tup, pct_muertas, umbral_vacuum,
       n_dead_tup > umbral_vacuum AS requiere_vacuum,
       n_mod_since_analyze, umbral_analyze,
       (n_mod_since_analyze > umbral_analyze OR ultimo_analyze IS NULL) AS requiere_analyze,
       ultimo_vacuum, ultimo_analyze
FROM diagnostico_mantenimiento
ORDER BY n_dead_tup DESC;

\echo '== 3. Acción: VACUUM (ANALYZE) solo sobre las tablas que lo requieren =='
SELECT format('VACUUM (ANALYZE, VERBOSE) public.%I', relname) AS sentencia
FROM diagnostico_mantenimiento
WHERE n_dead_tup > umbral_vacuum
   OR n_mod_since_analyze > umbral_analyze
   OR ultimo_analyze IS NULL
ORDER BY n_dead_tup DESC
\gexec

\echo '== 4. Diagnóstico DESPUÉS =='
SELECT relname, n_live_tup, n_dead_tup, pct_muertas,
       n_dead_tup > umbral_vacuum AS requiere_vacuum,
       n_mod_since_analyze,
       (n_mod_since_analyze > umbral_analyze OR ultimo_analyze IS NULL) AS requiere_analyze,
       ultimo_vacuum, ultimo_analyze
FROM diagnostico_mantenimiento
ORDER BY relname;
