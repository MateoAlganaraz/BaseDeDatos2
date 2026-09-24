\set ON_ERROR_STOP on
\pset pager off
\timing on

\echo 'Q1 - Detalles de ventas del producto 100001'
EXPLAIN (ANALYZE, BUFFERS)
SELECT det.id_pedido,
       det.id_producto,
       det.cantidad,
       det.precio_unitario
FROM detalle_pedido AS det
WHERE det.id_producto = 100001
ORDER BY det.id_pedido;

\echo 'Q2 - Autocompletado de productos activos por prefijo'
EXPLAIN (ANALYZE, BUFFERS)
SELECT prod.id_producto,
       prod.nombre,
       prod.precio_lista,
       prod.stock
FROM producto AS prod
WHERE prod.activo
  -- Los guiones bajos son literales del código de catálogo, no comodines de LIKE.
  AND prod.nombre LIKE 'TP3\_SB2026TP3\_PRODUCTO\_049%' ESCAPE '\'
ORDER BY prod.nombre
LIMIT 100;

\echo 'Q3 - Busqueda de clientes por prefijo de apellido'
EXPLAIN (ANALYZE, BUFFERS)
SELECT cli.id_cliente,
       cli.nombre,
       cli.apellido,
       cli.email
FROM cliente AS cli
WHERE cli.apellido LIKE 'TP3019%'
ORDER BY cli.apellido
LIMIT 100;
