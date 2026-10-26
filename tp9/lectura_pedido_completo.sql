\pset pager off
-- TP Unidad 7 - Criterio técnico de la conclusión: costo de leer un pedido completo (cliente + líneas)
-- en PostgreSQL, armando el documento con JOIN y json_agg sobre la base completa (600.000 pedidos).
--   psql -X -d foodstore -f tp9/lectura_pedido_completo.sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id_pedido, p.fecha, p.forma_pago,
       json_build_object('id_cliente', c.id_cliente, 'nombre', c.nombre, 'apellido', c.apellido) AS cliente,
       json_agg(json_build_object('id_producto', d.id_producto, 'cantidad', d.cantidad,
                                  'precio_unitario', d.precio_unitario) ORDER BY d.id_producto) AS lineas,
       sum(d.cantidad * d.precio_unitario) FILTER (WHERE d.deleted_at IS NULL) AS total
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente
JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE p.id_pedido = 2118
GROUP BY p.id_pedido, c.id_cliente;
