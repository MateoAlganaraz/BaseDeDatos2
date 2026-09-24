-- Validaciones no destructivas de TP4. No presupone que los indices mejoraron:
-- solo informa si existen y exige equivalencia formal para las dos specs.
SELECT indice,
       definicion
FROM (
    SELECT 'idx_tp4_pedido_fecha_id_cliente' AS indice,
           coalesce(pg_get_indexdef(to_regclass('idx_tp4_pedido_fecha_id_cliente')), 'NO_EXISTE') AS definicion
    UNION ALL
    SELECT 'idx_tp4_detalle_pedido_cobertura',
           coalesce(pg_get_indexdef(to_regclass('idx_tp4_detalle_pedido_cobertura')), 'NO_EXISTE')
    UNION ALL
    SELECT 'idx_tp4_detalle_producto_pedido',
           coalesce(pg_get_indexdef(to_regclass('idx_tp4_detalle_producto_pedido')), 'NO_EXISTE')
) AS indices_tp4
ORDER BY indice;

-- Todas las FK del modelo deben seguir apuntando a filas existentes.
SELECT 'pedido_sin_cliente' AS control, count(*) AS filas_invalidas
FROM pedido ped LEFT JOIN cliente cli ON cli.id_cliente = ped.id_cliente
WHERE cli.id_cliente IS NULL
UNION ALL
SELECT 'detalle_sin_pedido', count(*)
FROM detalle_pedido det LEFT JOIN pedido ped ON ped.id_pedido = det.id_pedido
WHERE ped.id_pedido IS NULL
UNION ALL
SELECT 'detalle_sin_producto', count(*)
FROM detalle_pedido det LEFT JOIN producto prod ON prod.id_producto = det.id_producto
WHERE prod.id_producto IS NULL
UNION ALL
SELECT 'producto_sin_categoria', count(*)
FROM producto prod LEFT JOIN categoria cat ON cat.id_categoria = prod.id_categoria
WHERE cat.id_categoria IS NULL;

-- Equivalencia de Parte 3 (misma definicion que 03_specs_equivalencia.sql).
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
