\set ON_ERROR_STOP on
\timing on

-- Requiere el índice único de materializadas.sql.
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tp5_facturacion_categoria_mes;
