-- Parte 2. Este archivo contiene EXACTAMENTE tres consultas candidatas.
-- Ejecutar una vez con 'antes' y otra con 'despues'. Cambiar solo estos valores.
SET app.tp3_lote = 'SB2026TP3';
SET app.tp3_fase = 'antes';

SELECT current_setting('app.tp3_fase') AS fase_de_medicion,
       current_database() AS base_conectada,
       now() AS instante;

-- Q1 - productos activos de una categoria, con rango de precio y orden.
-- La CTE calcula la categoria objetivo dentro de la misma consulta.
EXPLAIN (ANALYZE, BUFFERS)
WITH categoria_objetivo AS (
    SELECT p.id_categoria
    FROM producto AS p
    WHERE left(p.nombre, length(format('TP3_%s_PRODUCTO_', current_setting('app.tp3_lote'))))
          = format('TP3_%s_PRODUCTO_', current_setting('app.tp3_lote'))
      AND p.activo
    GROUP BY p.id_categoria
    ORDER BY count(*) DESC, p.id_categoria
    LIMIT 1
)
SELECT p.id_producto, p.nombre, p.precio_lista, p.stock
FROM producto AS p
JOIN categoria_objetivo AS objetivo ON objetivo.id_categoria = p.id_categoria
WHERE p.activo
  AND p.precio_lista BETWEEN 1500 AND 4500
ORDER BY p.precio_lista DESC, p.id_producto
LIMIT 100;

-- Q2 - pedidos recientes por forma de pago, ordenados por fecha.
EXPLAIN (ANALYZE, BUFFERS)
SELECT ped.id_pedido, ped.fecha, ped.id_cliente, ped.forma_pago
FROM pedido AS ped
WHERE ped.forma_pago = 'TARJETA'::forma_pago_enum
  AND ped.fecha >= current_timestamp - interval '90 days'
ORDER BY ped.fecha DESC
LIMIT 200;

-- Q3 - productos mas vendidos en los ultimos siete dias.
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id_producto, p.nombre, sum(det.cantidad) AS unidades_vendidas
FROM pedido AS ped
JOIN detalle_pedido AS det ON det.id_pedido = ped.id_pedido
JOIN producto AS p ON p.id_producto = det.id_producto
WHERE ped.fecha >= current_timestamp - interval '7 days'
  AND p.activo
GROUP BY p.id_producto, p.nombre
ORDER BY unidades_vendidas DESC, p.id_producto
LIMIT 20;
