-- Ejecutar en food_store_tp5_base y luego en food_store_tp5_indices_vistas.
EXPLAIN (ANALYZE, BUFFERS)
SELECT det.id_pedido, det.id_producto, det.cantidad, det.precio_unitario
FROM detalle_pedido AS det
WHERE det.id_producto = 100001
ORDER BY det.id_pedido;

EXPLAIN (ANALYZE, BUFFERS)
SELECT prod.id_producto, prod.nombre, prod.precio_lista, prod.stock
FROM producto AS prod
WHERE prod.activo
  AND prod.nombre LIKE 'TP3\_SB2026TP3\_PRODUCTO\_049%' ESCAPE '\'
ORDER BY prod.nombre
LIMIT 100;

EXPLAIN (ANALYZE, BUFFERS)
SELECT cli.id_cliente, cli.nombre, cli.apellido, cli.email
FROM cliente AS cli
WHERE cli.apellido LIKE 'TP3019%'
ORDER BY cli.apellido
LIMIT 100;
