-- PARTE 4 - Consulta común de competencia para DBeaver.
-- Ejecutar este mismo reporte en una copia sin el índice de Q3 y luego con él.
-- Combina producto, categoría, detalle_pedido y pedido, con agregación mensual.
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
