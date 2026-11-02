-- =====================================================================
-- TP N.º 8 - Control final (consigna 2.c): la simulación no cambió el servidor.
-- Compara contra la línea base tomada en 01_v_snapshot_movil.sql, antes de los casos.
-- Los únicos cambios esperados son los que se prepararon a mano como "servidor":
-- el precio del producto 101 (C2) y la baja lógica del 109 (C4). Ninguno toca stock ni pedidos.
-- =====================================================================

SELECT 'pedidos'  AS control, b.pedidos  AS antes, (SELECT count(*) FROM public.pedido) AS ahora,
       b.pedidos = (SELECT count(*) FROM public.pedido) AS sin_cambios
FROM movil.linea_base b
UNION ALL
SELECT 'detalles', b.detalles, (SELECT count(*) FROM public.detalle_pedido),
       b.detalles = (SELECT count(*) FROM public.detalle_pedido)
FROM movil.linea_base b
UNION ALL
SELECT 'stock total', b.stock_total, (SELECT sum(stock) FROM public.producto),
       b.stock_total = (SELECT sum(stock) FROM public.producto)
FROM movil.linea_base b;

-- Producto por producto: debe devolver 0 filas.
SELECT 'productos con stock distinto de la línea base' AS control, count(*) AS filas
FROM movil.linea_base_stock lb
JOIN public.producto p USING (id_producto)
WHERE p.stock <> lb.stock;

-- Solo los dos cambios preparados para C2 y C4.
SELECT id_producto, precio_lista, stock, deleted_at IS NOT NULL AS dado_de_baja
FROM public.producto
WHERE id_producto IN (101, 106, 109, 110, 111)
ORDER BY id_producto;
