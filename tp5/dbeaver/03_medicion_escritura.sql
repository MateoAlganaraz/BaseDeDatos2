-- Medir el tiempo que muestra DBeaver para este INSERT y luego ejecutar ROLLBACK.
BEGIN;
CREATE TEMP TABLE lote_escritura_tp5 ON COMMIT DROP AS
WITH producto_prueba AS (
    SELECT max(id_producto) AS id_producto FROM producto
)
SELECT ped.id_pedido, producto_prueba.id_producto,
       1::integer AS cantidad, 1.00::numeric(12,2) AS precio_unitario
FROM pedido AS ped
CROSS JOIN producto_prueba
WHERE NOT EXISTS (
    SELECT 1 FROM detalle_pedido AS det
    WHERE det.id_pedido = ped.id_pedido
      AND det.id_producto = producto_prueba.id_producto
)
ORDER BY ped.id_pedido
LIMIT 600;

INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_pedido, id_producto, cantidad, precio_unitario
FROM lote_escritura_tp5;

ROLLBACK;
