-- PARTE 3 - Spec 1: ranking con funcion de ventana.
-- Tablas: cliente, pedido, detalle_pedido y producto.
-- Filtros: 90 dias previos a la fecha maxima cargada; producto.activo = true. Cliente, pedido y
-- detalle_pedido no tienen columna de borrado logico en este esquema.
-- Salida: un cliente por fila, con nombre, apellido, total gastado y RANK descendente.
-- Empates: comparten puesto; el ORDER BY final desempata por id_cliente sin cambiar RANK.

-- SQL generado a partir de la spec: agregacion previa + ventana.
WITH parametros AS (SELECT max(fecha) AS referencia FROM pedido),
gasto_cliente AS (
    SELECT cli.id_cliente,
           cli.nombre,
           cli.apellido,
           sum(det.cantidad * det.precio_unitario) AS total_gastado
    FROM cliente AS cli
    JOIN pedido AS ped ON ped.id_cliente = cli.id_cliente
    JOIN detalle_pedido AS det ON det.id_pedido = ped.id_pedido
    JOIN producto AS prod ON prod.id_producto = det.id_producto
    CROSS JOIN parametros AS par
    WHERE ped.fecha >= par.referencia - interval '90 days'
      AND prod.activo
    GROUP BY cli.id_cliente, cli.nombre, cli.apellido
)
SELECT id_cliente, nombre, apellido, total_gastado,
       rank() OVER (ORDER BY total_gastado DESC) AS puesto
FROM gasto_cliente
ORDER BY total_gastado DESC, id_cliente ASC;

-- Version alternativa: subconsulta correlacionada para calcular el gasto por cliente.
WITH parametros AS (SELECT max(fecha) AS referencia FROM pedido),
clientes_con_gasto AS (
    SELECT cli.id_cliente,
           cli.nombre,
           cli.apellido,
           (
               SELECT sum(det.cantidad * det.precio_unitario)
               FROM pedido AS ped
               JOIN detalle_pedido AS det ON det.id_pedido = ped.id_pedido
               JOIN producto AS prod ON prod.id_producto = det.id_producto
               WHERE ped.id_cliente = cli.id_cliente
                 AND ped.fecha >= par.referencia - interval '90 days'
                 AND prod.activo
           ) AS total_gastado
    FROM cliente AS cli
    CROSS JOIN parametros AS par
    WHERE EXISTS (
        SELECT 1
        FROM pedido AS ped
        JOIN detalle_pedido AS det ON det.id_pedido = ped.id_pedido
        JOIN producto AS prod ON prod.id_producto = det.id_producto
        WHERE ped.id_cliente = cli.id_cliente
          AND ped.fecha >= par.referencia - interval '90 days'
          AND prod.activo
    )
)
SELECT id_cliente, nombre, apellido, total_gastado,
       rank() OVER (ORDER BY total_gastado DESC) AS puesto
FROM clientes_con_gasto
ORDER BY total_gastado DESC, id_cliente ASC;

-- PARTE 3 - Spec 2: subconsulta correlacionada.
-- Tablas: categoria, producto, detalle_pedido y pedido.
-- Filtros: categoria.activo = true, producto.activo = true y ventana de 90 dias.
-- Salida: productos activos de categorias activas SIN una venta en la ventana.
-- Orden: categoria, producto, id_producto; no usa SELECT * ni LIMIT.

-- SQL generado a partir de la spec: anti-join correlacionado con NOT EXISTS.
WITH parametros AS (SELECT max(fecha) AS referencia FROM pedido)
SELECT prod.id_producto,
       prod.nombre AS producto,
       cat.nombre AS categoria,
       prod.precio_lista
FROM producto AS prod
JOIN categoria AS cat ON cat.id_categoria = prod.id_categoria
CROSS JOIN parametros AS par
WHERE prod.activo
  AND cat.activo
  AND NOT EXISTS (
      SELECT 1
      FROM detalle_pedido AS det
      JOIN pedido AS ped ON ped.id_pedido = det.id_pedido
      WHERE det.id_producto = prod.id_producto
        AND ped.fecha >= par.referencia - interval '90 days'
  )
ORDER BY categoria ASC, producto ASC, prod.id_producto ASC;

-- Version alternativa: LEFT JOIN + HAVING, misma especificacion.
WITH parametros AS (SELECT max(fecha) AS referencia FROM pedido)
SELECT prod.id_producto,
       prod.nombre AS producto,
       cat.nombre AS categoria,
       prod.precio_lista
FROM producto AS prod
JOIN categoria AS cat ON cat.id_categoria = prod.id_categoria
LEFT JOIN detalle_pedido AS det ON det.id_producto = prod.id_producto
LEFT JOIN pedido AS ped
  ON ped.id_pedido = det.id_pedido
 AND ped.fecha >= (SELECT referencia - interval '90 days' FROM parametros)
WHERE prod.activo
  AND cat.activo
GROUP BY prod.id_producto, prod.nombre, cat.nombre, prod.precio_lista
HAVING count(ped.id_pedido) = 0
ORDER BY categoria ASC, producto ASC, prod.id_producto ASC;

-- Verificacion formal. Las cuatro filas deben informar 0 diferencias.
WITH parametros AS (SELECT max(fecha) AS referencia FROM pedido),
spec1_ia AS (
    WITH gasto_cliente AS (
        SELECT cli.id_cliente, cli.nombre, cli.apellido,
               sum(det.cantidad * det.precio_unitario) AS total_gastado
        FROM cliente cli
        JOIN pedido ped ON ped.id_cliente = cli.id_cliente
        JOIN detalle_pedido det ON det.id_pedido = ped.id_pedido
        JOIN producto prod ON prod.id_producto = det.id_producto
        CROSS JOIN parametros par
        WHERE ped.fecha >= par.referencia - interval '90 days' AND prod.activo
        GROUP BY cli.id_cliente, cli.nombre, cli.apellido
    )
    SELECT id_cliente, nombre, apellido, total_gastado,
           rank() OVER (ORDER BY total_gastado DESC) AS puesto
    FROM gasto_cliente
),
spec1_propia AS (
    WITH clientes_con_gasto AS (
        SELECT cli.id_cliente, cli.nombre, cli.apellido,
               (SELECT sum(det.cantidad * det.precio_unitario)
                FROM pedido ped
                JOIN detalle_pedido det ON det.id_pedido = ped.id_pedido
                JOIN producto prod ON prod.id_producto = det.id_producto
                CROSS JOIN parametros par
                WHERE ped.id_cliente = cli.id_cliente
                  AND ped.fecha >= par.referencia - interval '90 days'
                  AND prod.activo) AS total_gastado
        FROM cliente cli
        WHERE EXISTS (
            SELECT 1 FROM pedido ped
            JOIN detalle_pedido det ON det.id_pedido = ped.id_pedido
            JOIN producto prod ON prod.id_producto = det.id_producto
            CROSS JOIN parametros par
            WHERE ped.id_cliente = cli.id_cliente
              AND ped.fecha >= par.referencia - interval '90 days'
              AND prod.activo
        )
    )
    SELECT id_cliente, nombre, apellido, total_gastado,
           rank() OVER (ORDER BY total_gastado DESC) AS puesto
    FROM clientes_con_gasto
),
spec2_ia AS (
    SELECT prod.id_producto, prod.nombre AS producto, cat.nombre AS categoria, prod.precio_lista
    FROM producto prod
    JOIN categoria cat ON cat.id_categoria = prod.id_categoria
    CROSS JOIN parametros par
    WHERE prod.activo AND cat.activo
      AND NOT EXISTS (
          SELECT 1 FROM detalle_pedido det
          JOIN pedido ped ON ped.id_pedido = det.id_pedido
          WHERE det.id_producto = prod.id_producto
            AND ped.fecha >= par.referencia - interval '90 days'
      )
),
spec2_propia AS (
    SELECT prod.id_producto, prod.nombre AS producto, cat.nombre AS categoria, prod.precio_lista
    FROM producto prod
    JOIN categoria cat ON cat.id_categoria = prod.id_categoria
    LEFT JOIN detalle_pedido det ON det.id_producto = prod.id_producto
    LEFT JOIN pedido ped
      ON ped.id_pedido = det.id_pedido
     AND ped.fecha >= (SELECT referencia - interval '90 days' FROM parametros)
    WHERE prod.activo AND cat.activo
    GROUP BY prod.id_producto, prod.nombre, cat.nombre, prod.precio_lista
    HAVING count(ped.id_pedido) = 0
)
SELECT 'spec_1_ia_menos_propia' AS control, count(*) AS filas_distintas
FROM (SELECT * FROM spec1_ia EXCEPT SELECT * FROM spec1_propia) AS diferencias
UNION ALL
SELECT 'spec_1_propia_menos_ia', count(*)
FROM (SELECT * FROM spec1_propia EXCEPT SELECT * FROM spec1_ia) AS diferencias
UNION ALL
SELECT 'spec_2_ia_menos_propia', count(*)
FROM (SELECT * FROM spec2_ia EXCEPT SELECT * FROM spec2_propia) AS diferencias
UNION ALL
SELECT 'spec_2_propia_menos_ia', count(*)
FROM (SELECT * FROM spec2_propia EXCEPT SELECT * FROM spec2_ia) AS diferencias;
