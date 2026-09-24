\set ON_ERROR_STOP on
\pset pager off

-- Ejecutar en la COPIA de laboratorio, nunca sobre la base original.
SELECT current_database() AS base_conectada,
       current_user AS rol_conectado,
       version() AS version_postgresql,
       now() AS instante;

SELECT c.relname AS tabla,
       c.reltuples::bigint AS filas_estimadas
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN ('cliente', 'categoria', 'producto', 'pedido', 'detalle_pedido')
ORDER BY c.relname;

SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('cliente', 'categoria', 'producto', 'pedido', 'detalle_pedido')
ORDER BY tablename, indexname;
