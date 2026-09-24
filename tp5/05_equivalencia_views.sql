\set ON_ERROR_STOP on
\pset pager off

-- Cada control compara en ambos sentidos la vista con la consulta manual equivalente.
-- El resultado esperado es 0 en todas las filas.
WITH vista AS (
    SELECT * FROM vw_tp5_productos_vigentes_categoria
), manual AS (
    SELECT prod.id_producto, prod.nombre AS producto, prod.descripcion,
           prod.precio_lista, prod.stock, cat.id_categoria, cat.nombre AS categoria
    FROM producto AS prod
    JOIN categoria AS cat ON cat.id_categoria = prod.id_categoria
    WHERE prod.activo AND cat.activo
)
SELECT 'productos_vista_menos_manual' AS control, count(*) AS filas_distintas
FROM (SELECT * FROM vista EXCEPT SELECT * FROM manual) AS diferencia
UNION ALL
SELECT 'productos_manual_menos_vista', count(*)
FROM (SELECT * FROM manual EXCEPT SELECT * FROM vista) AS diferencia;

WITH vista AS (
    SELECT * FROM vw_tp5_pedidos_cliente
), manual AS (
    SELECT ped.id_pedido, ped.fecha, ped.forma_pago,
           cli.id_cliente, cli.nombre, cli.apellido, cli.email
    FROM pedido AS ped
    JOIN cliente AS cli ON cli.id_cliente = ped.id_cliente
)
SELECT 'pedidos_vista_menos_manual' AS control, count(*) AS filas_distintas
FROM (SELECT * FROM vista EXCEPT SELECT * FROM manual) AS diferencia
UNION ALL
SELECT 'pedidos_manual_menos_vista', count(*)
FROM (SELECT * FROM manual EXCEPT SELECT * FROM vista) AS diferencia;

WITH vista AS (
    SELECT * FROM vw_tp5_detalle_pedido_producto
), manual AS (
    SELECT det.id_pedido, det.id_producto, prod.nombre AS producto,
           det.cantidad, det.precio_unitario,
           det.cantidad * det.precio_unitario AS subtotal
    FROM detalle_pedido AS det
    JOIN producto AS prod ON prod.id_producto = det.id_producto
)
SELECT 'detalle_vista_menos_manual' AS control, count(*) AS filas_distintas
FROM (SELECT * FROM vista EXCEPT SELECT * FROM manual) AS diferencia
UNION ALL
SELECT 'detalle_manual_menos_vista', count(*)
FROM (SELECT * FROM manual EXCEPT SELECT * FROM vista) AS diferencia;

WITH vista AS (
    SELECT * FROM vw_tp5_clientes_reportes
), manual AS (
    SELECT cli.id_cliente, cli.nombre, cli.apellido, cli.email
    FROM cliente AS cli
)
SELECT 'clientes_vista_menos_manual' AS control, count(*) AS filas_distintas
FROM (SELECT * FROM vista EXCEPT SELECT * FROM manual) AS diferencia
UNION ALL
SELECT 'clientes_manual_menos_vista', count(*)
FROM (SELECT * FROM manual EXCEPT SELECT * FROM vista) AS diferencia;
