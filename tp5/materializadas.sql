-- Vista materializada de TP5: resumen costoso de facturación por categoría y mes.
CREATE MATERIALIZED VIEW mv_tp5_facturacion_categoria_mes AS
SELECT date_trunc('month', ped.fecha) AS mes,
       cat.id_categoria,
       cat.nombre AS categoria,
       count(DISTINCT ped.id_pedido) AS pedidos,
       sum(det.cantidad * det.precio_unitario) AS facturacion
FROM categoria AS cat
JOIN producto AS prod ON prod.id_categoria = cat.id_categoria
JOIN detalle_pedido AS det ON det.id_producto = prod.id_producto
JOIN pedido AS ped ON ped.id_pedido = det.id_pedido
WHERE cat.activo
  AND prod.activo
GROUP BY date_trunc('month', ped.fecha), cat.id_categoria, cat.nombre
WITH DATA;

-- La combinación mes/categoría es única y habilita REFRESH ... CONCURRENTLY.
CREATE UNIQUE INDEX idx_mv_tp5_facturacion_categoria_mes
    ON mv_tp5_facturacion_categoria_mes (mes, id_categoria);
