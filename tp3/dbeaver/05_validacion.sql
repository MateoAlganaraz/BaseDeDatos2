-- Validacion no destructiva de la carga, FKs, CHECK/UNIQUE y equivalencias de Parte 4.
-- Debe coincidir con el lote usado en 01_carga_masiva.sql.
SET app.tp3_lote = 'SB2026TP3';

DO $validar_carga$
DECLARE
    lote text := current_setting('app.tp3_lote');
    cantidad bigint;
BEGIN
    SELECT count(*) INTO cantidad FROM cliente
    WHERE left(email, length(format('tp3_%s_cliente_', lote))) = format('tp3_%s_cliente_', lote);
    IF cantidad <> 20000 THEN RAISE EXCEPTION 'Clientes TP3 esperados 20000, obtenidos %', cantidad; END IF;

    SELECT count(*) INTO cantidad FROM producto
    WHERE left(nombre, length(format('TP3_%s_PRODUCTO_', lote))) = format('TP3_%s_PRODUCTO_', lote);
    IF cantidad <> 50000 THEN RAISE EXCEPTION 'Productos TP3 esperados 50000, obtenidos %', cantidad; END IF;

    SELECT count(*) INTO cantidad FROM pedido ped JOIN cliente cli ON cli.id_cliente = ped.id_cliente
    WHERE left(cli.email, length(format('tp3_%s_cliente_', lote))) = format('tp3_%s_cliente_', lote);
    IF cantidad <> 200000 THEN RAISE EXCEPTION 'Pedidos TP3 esperados 200000, obtenidos %', cantidad; END IF;

    SELECT count(*) INTO cantidad
    FROM detalle_pedido det JOIN pedido ped ON ped.id_pedido = det.id_pedido
    JOIN cliente cli ON cli.id_cliente = ped.id_cliente
    WHERE left(cli.email, length(format('tp3_%s_cliente_', lote))) = format('tp3_%s_cliente_', lote);
    IF cantidad <> 400000 THEN RAISE EXCEPTION 'Detalles TP3 esperados 400000, obtenidos %', cantidad; END IF;

    IF EXISTS (SELECT 1 FROM producto WHERE left(nombre, length(format('TP3_%s_PRODUCTO_', lote))) = format('TP3_%s_PRODUCTO_', lote)
               AND (precio_lista NOT BETWEEN 500 AND 5000 OR stock NOT BETWEEN 0 AND 200)) THEN
        RAISE EXCEPTION 'Un producto del lote no respeta el rango de precio o stock';
    END IF;
    IF EXISTS (SELECT 1 FROM pedido p LEFT JOIN cliente c ON c.id_cliente = p.id_cliente WHERE c.id_cliente IS NULL)
       OR EXISTS (SELECT 1 FROM detalle_pedido d LEFT JOIN pedido p ON p.id_pedido = d.id_pedido WHERE p.id_pedido IS NULL)
       OR EXISTS (SELECT 1 FROM detalle_pedido d LEFT JOIN producto p ON p.id_producto = d.id_producto WHERE p.id_producto IS NULL) THEN
        RAISE EXCEPTION 'Se encontro una referencia huerfana';
    END IF;
    IF EXISTS (SELECT 1 FROM cliente GROUP BY email HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'Se encontro email duplicado';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid IN ('cliente'::regclass, 'producto'::regclass, 'pedido'::regclass, 'detalle_pedido'::regclass) AND NOT convalidated) THEN
        RAISE EXCEPTION 'Existe una restriccion no validada';
    END IF;
END
$validar_carga$;

-- El resultado esperado de cada fila de esta seccion es 0.
WITH spec1_ia AS (
    SELECT c.id_categoria, c.nombre, count(p.id_producto) AS cantidad_productos_activos,
           coalesce(sum(p.precio_lista), 0::numeric) AS valor_lista_total
    FROM categoria c LEFT JOIN producto p ON p.id_categoria = c.id_categoria AND p.activo
    WHERE c.activo GROUP BY c.id_categoria, c.nombre
), spec1_propia AS (
    SELECT c.id_categoria, c.nombre,
           (SELECT count(*) FROM producto p WHERE p.id_categoria = c.id_categoria AND p.activo) AS cantidad_productos_activos,
           coalesce((SELECT sum(p.precio_lista) FROM producto p WHERE p.id_categoria = c.id_categoria AND p.activo), 0::numeric) AS valor_lista_total
    FROM categoria c WHERE c.activo
), spec2_ia AS (
    SELECT p.id_producto, p.nombre, c.nombre AS categoria, p.precio_lista
    FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE p.activo AND c.activo AND p.id_producto NOT IN (
        SELECT d.id_producto FROM detalle_pedido d JOIN pedido ped ON ped.id_pedido = d.id_pedido
        WHERE ped.fecha >= current_timestamp - interval '90 days'
    )
), spec2_propia AS (
    SELECT p.id_producto, p.nombre, c.nombre AS categoria, p.precio_lista
    FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE p.activo AND c.activo AND NOT EXISTS (
        SELECT 1 FROM detalle_pedido d JOIN pedido ped ON ped.id_pedido = d.id_pedido
        WHERE d.id_producto = p.id_producto AND ped.fecha >= current_timestamp - interval '90 days'
    )
)
SELECT 'spec_1_ia_menos_propia' AS control, count(*) AS filas_distintas FROM (SELECT * FROM spec1_ia EXCEPT SELECT * FROM spec1_propia) x
UNION ALL SELECT 'spec_1_propia_menos_ia', count(*) FROM (SELECT * FROM spec1_propia EXCEPT SELECT * FROM spec1_ia) x
UNION ALL SELECT 'spec_2_ia_menos_propia', count(*) FROM (SELECT * FROM spec2_ia EXCEPT SELECT * FROM spec2_propia) x
UNION ALL SELECT 'spec_2_propia_menos_ia', count(*) FROM (SELECT * FROM spec2_propia EXCEPT SELECT * FROM spec2_ia) x;

SELECT 'VALIDACION_COMPLETA_SIN_ERRORES' AS resultado;
