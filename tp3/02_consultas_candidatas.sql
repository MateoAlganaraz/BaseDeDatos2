\set ON_ERROR_STOP on
\pset pager off
\timing on

-- Parte 2. Este archivo contiene EXACTAMENTE tres consultas candidatas.
-- Ejecutar una vez con -v tp3_fase=antes y otra con -v tp3_fase=despues.
\if :{?tp3_lote}
\else
  \echo 'ERROR: falta -v tp3_lote=...'
  \quit
\endif
\if :{?tp3_fase}
\else
  \echo 'ERROR: falta -v tp3_fase=antes o -v tp3_fase=despues'
  \quit
\endif

SELECT :'tp3_fase' AS fase_de_medicion,
       current_database() AS base_conectada,
       now() AS instante;

SELECT p.id_categoria AS tp3_categoria_objetivo
FROM producto AS p
WHERE left(p.nombre, length(format('TP3_%s_PRODUCTO_', :'tp3_lote))) = format('TP3_%s_PRODUCTO_', :'tp3_lote')
  AND p.activo
GROUP BY p.id_categoria
ORDER BY count(*) DESC, p.id_categoria
LIMIT 1
\gset

\echo 'Q1 - productos activos de una categoria, con rango de precio y orden'
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id_producto, p.nombre, p.precio_lista, p.stock
FROM producto AS p
WHERE p.id_categoria = :'tp3_categoria_objetivo'::bigint
  AND p.activo
  AND p.precio_lista BETWEEN 1500 AND 4500
ORDER BY p.precio_lista DESC, p.id_producto
LIMIT 100;

\echo 'Q2 - pedidos recientes por forma de pago, ordenados por fecha'
EXPLAIN (ANALYZE, BUFFERS)
SELECT ped.id_pedido, ped.fecha, ped.id_cliente, ped.forma_pago
FROM pedido AS ped
WHERE ped.forma_pago = 'TARJETA'::forma_pago_enum
  AND ped.fecha >= current_timestamp - interval '90 days'
ORDER BY ped.fecha DESC
LIMIT 200;

\echo 'Q3 - productos mas vendidos en los ultimos siete dias'
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
