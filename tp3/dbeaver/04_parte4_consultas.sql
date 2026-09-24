-- PARTE 4 - Spec 1 (resumen)
-- Tablas: categoria y producto. Solo categorias y productos activos (activo = TRUE).
-- Salida: id, nombre, cantidad y valor de lista total; incluye categorias activas sin
-- productos activos con cero. Orden: cantidad DESC, nombre ASC, id ASC. Sin LIMIT.
-- SQL propuesto por IA: LEFT JOIN + agregacion.
SELECT c.id_categoria, c.nombre,
       count(p.id_producto) AS cantidad_productos_activos,
       coalesce(sum(p.precio_lista), 0::numeric) AS valor_lista_total
FROM categoria AS c
LEFT JOIN producto AS p
  ON p.id_categoria = c.id_categoria
 AND p.activo
WHERE c.activo
GROUP BY c.id_categoria, c.nombre
ORDER BY cantidad_productos_activos DESC, c.nombre ASC, c.id_categoria ASC;

-- SQL alternativo propio: subconsultas correlacionadas, misma especificacion.
SELECT c.id_categoria, c.nombre,
       (SELECT count(*)
        FROM producto AS p
        WHERE p.id_categoria = c.id_categoria AND p.activo) AS cantidad_productos_activos,
       coalesce((SELECT sum(p.precio_lista)
                 FROM producto AS p
                 WHERE p.id_categoria = c.id_categoria AND p.activo), 0::numeric) AS valor_lista_total
FROM categoria AS c
WHERE c.activo
ORDER BY cantidad_productos_activos DESC, c.nombre ASC, c.id_categoria ASC;

-- Equivalencia formal del Spec 1. Cada contador debe ser 0.
WITH ia AS (
    SELECT c.id_categoria, c.nombre, count(p.id_producto) AS cantidad_productos_activos,
           coalesce(sum(p.precio_lista), 0::numeric) AS valor_lista_total
    FROM categoria c LEFT JOIN producto p ON p.id_categoria = c.id_categoria AND p.activo
    WHERE c.activo GROUP BY c.id_categoria, c.nombre
), propia AS (
    SELECT c.id_categoria, c.nombre,
           (SELECT count(*) FROM producto p WHERE p.id_categoria = c.id_categoria AND p.activo) AS cantidad_productos_activos,
           coalesce((SELECT sum(p.precio_lista) FROM producto p WHERE p.id_categoria = c.id_categoria AND p.activo), 0::numeric) AS valor_lista_total
    FROM categoria c WHERE c.activo
)
SELECT 'spec_1_ia_menos_propia' AS control, count(*) AS filas_distintas
FROM (SELECT * FROM ia EXCEPT SELECT * FROM propia) AS diferencias
UNION ALL
SELECT 'spec_1_propia_menos_ia', count(*)
FROM (SELECT * FROM propia EXCEPT SELECT * FROM ia) AS diferencias;

-- PARTE 4 - Spec 2 (subconsulta)
-- Tablas: categoria, producto, pedido y detalle_pedido. Devuelve productos y categorias
-- activos que NO tuvieron detalle en pedidos de los ultimos 90 dias. Salida: id producto,
-- nombre producto, categoria y precio. Orden: nombre, id. Sin LIMIT.
-- SQL propuesto por IA: NOT IN. id_producto es NOT NULL tanto en producto como en detalle_pedido.
SELECT p.id_producto, p.nombre AS producto, c.nombre AS categoria, p.precio_lista
FROM producto AS p
JOIN categoria AS c ON c.id_categoria = p.id_categoria
WHERE p.activo
  AND c.activo
  AND p.id_producto NOT IN (
      SELECT det.id_producto
      FROM detalle_pedido AS det
      JOIN pedido AS ped ON ped.id_pedido = det.id_pedido
      WHERE ped.fecha >= current_timestamp - interval '90 days'
  )
ORDER BY producto ASC, p.id_producto ASC;

-- SQL alternativo propio: anti-join con NOT EXISTS, misma especificacion.
SELECT p.id_producto, p.nombre AS producto, c.nombre AS categoria, p.precio_lista
FROM producto AS p
JOIN categoria AS c ON c.id_categoria = p.id_categoria
WHERE p.activo
  AND c.activo
  AND NOT EXISTS (
      SELECT 1
      FROM detalle_pedido AS det
      JOIN pedido AS ped ON ped.id_pedido = det.id_pedido
      WHERE det.id_producto = p.id_producto
        AND ped.fecha >= current_timestamp - interval '90 days'
  )
ORDER BY producto ASC, p.id_producto ASC;

-- Equivalencia formal del Spec 2. Cada contador debe ser 0.
WITH ia AS (
    SELECT p.id_producto, p.nombre AS producto, c.nombre AS categoria, p.precio_lista
    FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE p.activo AND c.activo
      AND p.id_producto NOT IN (
          SELECT det.id_producto FROM detalle_pedido det
          JOIN pedido ped ON ped.id_pedido = det.id_pedido
          WHERE ped.fecha >= current_timestamp - interval '90 days'
      )
), propia AS (
    SELECT p.id_producto, p.nombre AS producto, c.nombre AS categoria, p.precio_lista
    FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE p.activo AND c.activo
      AND NOT EXISTS (
          SELECT 1 FROM detalle_pedido det JOIN pedido ped ON ped.id_pedido = det.id_pedido
          WHERE det.id_producto = p.id_producto
            AND ped.fecha >= current_timestamp - interval '90 days'
      )
)
SELECT 'spec_2_ia_menos_propia' AS control, count(*) AS filas_distintas
FROM (SELECT * FROM ia EXCEPT SELECT * FROM propia) AS diferencias
UNION ALL
SELECT 'spec_2_propia_menos_ia', count(*)
FROM (SELECT * FROM propia EXCEPT SELECT * FROM ia) AS diferencias;
