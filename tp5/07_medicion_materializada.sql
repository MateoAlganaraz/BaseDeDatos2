\set ON_ERROR_STOP on
\pset pager off
\timing on

\echo 'Reporte original: facturacion por categoria y mes'
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('month', ped.fecha) AS mes,
       cat.id_categoria,
       cat.nombre AS categoria,
       count(DISTINCT ped.id_pedido) AS pedidos,
       sum(det.cantidad * det.precio_unitario) AS facturacion
FROM categoria AS cat
JOIN producto AS prod ON prod.id_categoria = cat.id_categoria
JOIN detalle_pedido AS det ON det.id_producto = prod.id_producto
JOIN pedido AS ped ON ped.id_pedido = det.id_pedido
WHERE cat.activo AND prod.activo
GROUP BY date_trunc('month', ped.fecha), cat.id_categoria, cat.nombre
ORDER BY mes DESC, facturacion DESC, cat.id_categoria;

\echo 'Reporte materializado: misma salida precalculada'
EXPLAIN (ANALYZE, BUFFERS)
SELECT mes, id_categoria, categoria, pedidos, facturacion
FROM mv_tp5_facturacion_categoria_mes
ORDER BY mes DESC, facturacion DESC, id_categoria;
