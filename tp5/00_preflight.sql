\set ON_ERROR_STOP on
\pset pager off

SELECT current_database() AS base_laboratorio,
       current_user AS usuario,
       version() AS version_postgresql;

SELECT c.relname AS tabla,
       c.reltuples::bigint AS filas_estimadas,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS tamano_total
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN ('cliente', 'categoria', 'producto', 'pedido', 'detalle_pedido')
ORDER BY c.relname;

SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
