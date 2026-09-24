-- Carga TP3: 50.000 productos, 20.000 clientes, 200.000 pedidos y 400.000 detalles.
-- No borra ni actualiza filas existentes. Usar UNICAMENTE una copia de laboratorio.
-- Cambiar solo este valor si se necesita otro lote y ejecutar el archivo completo.
SET app.tp3_lote = 'SB2026TP3';

BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '0';

DO $carga_guardas$
DECLARE
    lote text := current_setting('app.tp3_lote');
BEGIN
    IF lote !~ '^[A-Za-z0-9_]+$' THEN
        RAISE EXCEPTION 'tp3_lote solo puede contener letras, numeros y guion bajo: %', lote;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM categoria) THEN
        RAISE EXCEPTION 'No existen categorias donde distribuir los productos';
    END IF;
    IF EXISTS (
        SELECT 1 FROM producto
        WHERE left(nombre, length(format('TP3_%s_PRODUCTO_', lote))) = format('TP3_%s_PRODUCTO_', lote)
    ) OR EXISTS (
        SELECT 1 FROM cliente
        WHERE left(email, length(format('tp3_%s_cliente_', lote))) = format('tp3_%s_cliente_', lote)
    ) THEN
        RAISE EXCEPTION 'El lote % ya parece cargado. Elegir otro tp3_lote; no se reutilizan marcadores.', lote;
    END IF;
END
$carga_guardas$;

CREATE TEMP TABLE tp3_producto_map (
    n integer PRIMARY KEY,
    id_producto bigint NOT NULL UNIQUE
) ON COMMIT DROP;
CREATE TEMP TABLE tp3_cliente_map (
    n integer PRIMARY KEY,
    id_cliente bigint NOT NULL UNIQUE
) ON COMMIT DROP;
CREATE TEMP TABLE tp3_pedido_map (
    n integer PRIMARY KEY,
    id_pedido bigint NOT NULL UNIQUE
) ON COMMIT DROP;

-- Se usan las categorias existentes, sin crear ni alterar catalogos de la base.
WITH categorias_numeradas AS (
    SELECT id_categoria, row_number() OVER (ORDER BY id_categoria) AS n,
           count(*) OVER () AS total
    FROM categoria
)
INSERT INTO producto (nombre, descripcion, precio_lista, stock, activo, id_categoria)
SELECT format('TP3_%s_PRODUCTO_%s', current_setting('app.tp3_lote'), lpad(serie.n::text, 6, '0')),
       format('Producto generado para TP3, lote %s, secuencia %s', current_setting('app.tp3_lote'), serie.n),
       (500 + mod(serie.n * 37, 4501))::numeric(12,2),
       mod(serie.n * 19, 201),
       mod(serie.n, 20) <> 0,
       categoria.id_categoria
FROM generate_series(1, 50000) AS serie(n)
JOIN categorias_numeradas AS categoria
  ON categoria.n = mod(serie.n - 1, categoria.total) + 1;

INSERT INTO tp3_producto_map (n, id_producto)
SELECT serie.n, producto.id_producto
FROM generate_series(1, 50000) AS serie(n)
JOIN producto
  ON producto.nombre = format('TP3_%s_PRODUCTO_%s', current_setting('app.tp3_lote'), lpad(serie.n::text, 6, '0'));

INSERT INTO cliente (nombre, apellido, email, telefono)
SELECT format('Cliente%s', lpad(serie.n::text, 5, '0')),
       format('TP3%s', lpad(serie.n::text, 5, '0')),
       format('tp3_%s_cliente_%s@example.invalid', current_setting('app.tp3_lote'), lpad(serie.n::text, 5, '0')),
       format('+54-11-%s', lpad(mod(serie.n * 7919, 100000000)::text, 8, '0'))
FROM generate_series(1, 20000) AS serie(n);

INSERT INTO tp3_cliente_map (n, id_cliente)
SELECT serie.n, cliente.id_cliente
FROM generate_series(1, 20000) AS serie(n)
JOIN cliente
  ON cliente.email = format('tp3_%s_cliente_%s@example.invalid', current_setting('app.tp3_lote'), lpad(serie.n::text, 5, '0'));

INSERT INTO pedido (fecha, id_cliente, forma_pago)
SELECT current_timestamp
           - (mod(serie.n * 13, 365) * interval '1 day')
           - (mod(serie.n * 7919, 86400) * interval '1 second'),
       cliente.id_cliente,
       CASE mod(serie.n, 3)
           WHEN 0 THEN 'EFECTIVO'::forma_pago_enum
           WHEN 1 THEN 'TARJETA'::forma_pago_enum
           ELSE 'TRANSFERENCIA'::forma_pago_enum
       END
FROM generate_series(1, 200000) AS serie(n)
JOIN tp3_cliente_map AS cliente
  ON cliente.n = mod(serie.n - 1, 20000) + 1;

INSERT INTO tp3_pedido_map (n, id_pedido)
SELECT serie.n, pedido.id_pedido
FROM generate_series(1, 200000) AS serie(n)
JOIN pedido
  ON pedido.id_cliente = (
        SELECT cliente.id_cliente
        FROM tp3_cliente_map AS cliente
        WHERE cliente.n = mod(serie.n - 1, 20000) + 1
     )
 AND pedido.fecha = current_timestamp
           - (mod(serie.n * 13, 365) * interval '1 day')
           - (mod(serie.n * 7919, 86400) * interval '1 second');

-- Dos productos distintos por pedido: 400.000 detalles sin violar la PK compuesta.
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT pedido.id_pedido, producto.id_producto,
       mod(pedido.n, 5) + 1, producto.precio_lista
FROM tp3_pedido_map AS pedido
JOIN tp3_producto_map AS producto_map ON producto_map.n = mod(pedido.n - 1, 50000) + 1
JOIN producto ON producto.id_producto = producto_map.id_producto
UNION ALL
SELECT pedido.id_pedido, producto.id_producto,
       mod(pedido.n * 3, 5) + 1, producto.precio_lista
FROM tp3_pedido_map AS pedido
JOIN tp3_producto_map AS producto_map ON producto_map.n = mod(pedido.n * 17 + 6, 50000) + 1
JOIN producto ON producto.id_producto = producto_map.id_producto;

DO $carga_conteos$
BEGIN
    IF (SELECT count(*) FROM tp3_producto_map) <> 50000
       OR (SELECT count(*) FROM tp3_cliente_map) <> 20000
       OR (SELECT count(*) FROM tp3_pedido_map) <> 200000 THEN
        RAISE EXCEPTION 'La carga no produjo todos los identificadores esperados; se revierte la transaccion';
    END IF;
    IF (SELECT count(*) FROM detalle_pedido d JOIN tp3_pedido_map p ON p.id_pedido = d.id_pedido) <> 400000 THEN
        RAISE EXCEPTION 'La carga no produjo 400000 detalles; se revierte la transaccion';
    END IF;
END
$carga_conteos$;

COMMIT;

-- Estadisticas nuevas antes de cualquier EXPLAIN ANALYZE de la Parte 2.
ANALYZE VERBOSE cliente;
ANALYZE VERBOSE producto;
ANALYZE VERBOSE pedido;
ANALYZE VERBOSE detalle_pedido;

SELECT 'clientes_lote' AS control, count(*) AS cantidad
FROM cliente WHERE left(email, length(format('tp3_%s_cliente_', current_setting('app.tp3_lote')))) = format('tp3_%s_cliente_', current_setting('app.tp3_lote'))
UNION ALL
SELECT 'productos_lote', count(*)
FROM producto WHERE left(nombre, length(format('TP3_%s_PRODUCTO_', current_setting('app.tp3_lote')))) = format('TP3_%s_PRODUCTO_', current_setting('app.tp3_lote'))
UNION ALL
SELECT 'pedidos_lote', count(*)
FROM pedido ped JOIN cliente cli ON cli.id_cliente = ped.id_cliente
WHERE left(cli.email, length(format('tp3_%s_cliente_', current_setting('app.tp3_lote')))) = format('tp3_%s_cliente_', current_setting('app.tp3_lote'))
UNION ALL
SELECT 'detalles_lote', count(*)
FROM detalle_pedido det
JOIN pedido ped ON ped.id_pedido = det.id_pedido
JOIN cliente cli ON cli.id_cliente = ped.id_cliente
WHERE left(cli.email, length(format('tp3_%s_cliente_', current_setting('app.tp3_lote')))) = format('tp3_%s_cliente_', current_setting('app.tp3_lote'));
