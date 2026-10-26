\pset pager off

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 6 - Chequeo de salud de foodstore (SPEC_U6: tarea diaria).
--
-- Solo lectura: no modifica datos ni configuración. Compatible con PostgreSQL 16+.
--   psql -X -h localhost -U foodstore_backup -d foodstore -f tp8/health_check.sql
-- (foodstore_backup puede leer pg_stat_*; para ver el texto de consultas de otros roles en
--  pg_stat_activity hace falta pg_read_all_stats o superusuario.)
-- Umbral de alerta: consultas activas o transacciones "idle in transaction" de más de 5 min.
-- =====================================================================

\echo '== Momento del chequeo =='
SELECT now() AS ejecutado_en, current_database() AS base, version() AS motor;

\echo '== 1. Tamaño de la base y de sus tablas más grandes =='
SELECT pg_size_pretty(pg_database_size(current_database())) AS tamano_base;

SELECT c.relname AS tabla,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total,
       pg_size_pretty(pg_relation_size(c.oid))       AS datos,
       pg_size_pretty(pg_indexes_size(c.oid))        AS indices
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname = 'public'
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 10;

\echo '== 2. Actividad de conexiones =='
SELECT numbackends AS conexiones, xact_commit, xact_rollback,
       round(100.0 * xact_rollback / nullif(xact_commit + xact_rollback, 0), 2) AS pct_rollback,
       round(100.0 * blks_hit / nullif(blks_hit + blks_read, 0), 2)              AS pct_cache_hit,
       deadlocks, temp_files, pg_size_pretty(temp_bytes) AS temp_usado,
       stats_reset
FROM pg_stat_database
WHERE datname = current_database();

SELECT coalesce(state, '(proceso interno)') AS estado, count(*) AS sesiones
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY 1
ORDER BY 2 DESC;

SELECT current_setting('max_connections')::int AS max_connections,
       (SELECT count(*) FROM pg_stat_activity) AS conexiones_totales_servidor;

\echo '== 3. Estado de las tablas: tuplas vivas/muertas, vacuum y analyze =='
SELECT relname,
       n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 2) AS pct_muertas,
       n_mod_since_analyze,
       last_vacuum, last_autovacuum, last_analyze, last_autoanalyze,
       autovacuum_count, autoanalyze_count
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

\echo '== 4. Consultas activas (sin la propia) =='
SELECT pid, usename, application_name, client_addr, state,
       now() - xact_start  AS duracion_transaccion,
       now() - query_start AS duracion_consulta,
       wait_event_type, wait_event,
       left(query, 120) AS consulta
FROM pg_stat_activity
WHERE datname = current_database()
  AND state <> 'idle'
  AND pid <> pg_backend_pid()
ORDER BY query_start;

\echo '== 5. Alertas: consultas activas o transacciones abiertas de más de 5 minutos (esperado: 0 filas) =='
SELECT pid, usename, state, now() - coalesce(xact_start, query_start) AS antiguedad, left(query, 80) AS consulta
FROM pg_stat_activity
WHERE datname = current_database()
  AND state IN ('active', 'idle in transaction', 'idle in transaction (aborted)')
  AND pid <> pg_backend_pid()
  AND now() - coalesce(xact_start, query_start) > interval '5 minutes';

\echo '== 6. Bloqueos en espera (esperado: 0 filas) =='
SELECT bloqueado.pid AS pid_bloqueado, left(bloqueado.query, 60) AS consulta_bloqueada,
       bloqueante.pid AS pid_bloqueante, left(bloqueante.query, 60) AS consulta_bloqueante
FROM pg_stat_activity bloqueado
JOIN LATERAL unnest(pg_blocking_pids(bloqueado.pid)) AS b(pid) ON true
JOIN pg_stat_activity bloqueante ON bloqueante.pid = b.pid
WHERE bloqueado.datname = current_database();

\echo '== 7. Edad de transacciones (wraparound): % consumido de autovacuum_freeze_max_age =='
SELECT datname, age(datfrozenxid) AS edad_xid,
       round(100.0 * age(datfrozenxid) / current_setting('autovacuum_freeze_max_age')::bigint, 2) AS pct_del_limite
FROM pg_database
WHERE datname = current_database();
