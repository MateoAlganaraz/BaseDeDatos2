-- PARTE 5. Consulta comun para todos los equipos. Medir antes y despues en la misma copia.
-- No cambiar la semantica: categoria y producto activos, rango inclusivo, orden y LIMIT.
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id_producto, p.nombre AS producto, c.nombre AS categoria, p.precio_lista, p.stock
FROM producto AS p
JOIN categoria AS c ON c.id_categoria = p.id_categoria
WHERE p.activo
  AND c.activo
  AND p.precio_lista BETWEEN 1500 AND 4500
ORDER BY p.precio_lista DESC, p.id_producto
LIMIT 100;
