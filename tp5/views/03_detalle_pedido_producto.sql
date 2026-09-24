-- Vista 3 - Detalle de pedido con el nombre del producto.
CREATE OR REPLACE VIEW vw_tp5_detalle_pedido_producto AS
SELECT det.id_pedido,
       det.id_producto,
       prod.nombre AS producto,
       det.cantidad,
       det.precio_unitario,
       det.cantidad * det.precio_unitario AS subtotal
FROM detalle_pedido AS det
JOIN producto AS prod ON prod.id_producto = det.id_producto;
