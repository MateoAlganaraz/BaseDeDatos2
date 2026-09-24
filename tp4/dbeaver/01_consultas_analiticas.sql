-- TP4 - Parte 1 para DBeaver. Ejecutar antes y despues de 02_indices.sql.
-- Guardar el panel de resultados de cada EXPLAIN (ANALYZE, BUFFERS).

-- Q1 - Facturacion por categoria y mes (pedido, detalle, producto, categoria)
EXPLAIN (ANALYZE, BUFFERS)
WITH parametros AS (
    SELECT max(fecha) AS referencia
    FROM pedido
)
SELECT date_trunc('month', ped.fecha) AS mes,
       cat.id_categoria,
       cat.nombre AS categoria,
       count(DISTINCT ped.id_pedido) AS pedidos,
       sum(det.cantidad * det.precio_unitario) AS facturacion
FROM pedido AS ped
JOIN detalle_pedido AS det ON det.id_pedido = ped.id_pedido
JOIN producto AS prod ON prod.id_producto = det.id_producto
JOIN categoria AS cat ON cat.id_categoria = prod.id_categoria
CROSS JOIN parametros AS par
WHERE ped.fecha >= par.referencia - interval '90 days'
  AND prod.activo
  AND cat.activo
GROUP BY date_trunc('month', ped.fecha), cat.id_categoria, cat.nombre
ORDER BY mes DESC, facturacion DESC, cat.id_categoria ASC;

-- Q2 - Ranking de clientes por gasto (cliente, pedido, detalle, producto)
EXPLAIN (ANALYZE, BUFFERS)
WITH parametros AS (
    SELECT max(fecha) AS referencia
    FROM pedido
),
gasto_cliente AS (
    SELECT cli.id_cliente,
           cli.nombre,
           cli.apellido,
           sum(det.cantidad * det.precio_unitario) AS total_gastado
    FROM cliente AS cli
    JOIN pedido AS ped ON ped.id_cliente = cli.id_cliente
    JOIN detalle_pedido AS det ON det.id_pedido = ped.id_pedido
    JOIN producto AS prod ON prod.id_producto = det.id_producto
    CROSS JOIN parametros AS par
    WHERE ped.fecha >= par.referencia - interval '90 days'
      AND prod.activo
    GROUP BY cli.id_cliente, cli.nombre, cli.apellido
)
SELECT id_cliente,
       nombre,
       apellido,
       total_gastado,
       rank() OVER (ORDER BY total_gastado DESC) AS puesto
FROM gasto_cliente
ORDER BY total_gastado DESC, id_cliente ASC
LIMIT 100;

-- Q3 - Ventas mensuales del producto 100001 (producto, categoria, detalle, pedido)
-- Mantener p.id_producto = 100001 para que antes/despues comparen exactamente el mismo caso.
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('month', ped.fecha) AS mes,
       prod.id_producto,
       prod.nombre AS producto,
       cat.nombre AS categoria,
       sum(det.cantidad) AS unidades_vendidas,
       sum(det.cantidad * det.precio_unitario) AS facturacion
FROM producto AS prod
JOIN categoria AS cat ON cat.id_categoria = prod.id_categoria
JOIN detalle_pedido AS det ON det.id_producto = prod.id_producto
JOIN pedido AS ped ON ped.id_pedido = det.id_pedido
WHERE prod.id_producto = 100001
  AND prod.activo
  AND cat.activo
GROUP BY date_trunc('month', ped.fecha),
         prod.id_producto, prod.nombre, cat.nombre
ORDER BY mes ASC, prod.id_producto ASC;
