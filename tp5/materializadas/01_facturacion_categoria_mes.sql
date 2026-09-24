-- Reporte agregado costoso de la Semana 4, ahora precalculado.
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

CREATE UNIQUE INDEX idx_mv_tp5_facturacion_categoria_mes
    ON mv_tp5_facturacion_categoria_mes (mes, id_categoria);
