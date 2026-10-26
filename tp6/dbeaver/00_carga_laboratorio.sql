
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 4 - Parte 2: preparación de una instancia "razonablemente poblada".
--
-- Ejecutar SOLO sobre una copia de laboratorio creada desde schema.sql, vacía:
--   createdb food_store_tp6_lab
--   psql -X -d food_store_tp6_lab -f schema.sql
--   psql -X -v ON_ERROR_STOP=1 -d food_store_tp6_lab -f tp6/00_carga_laboratorio.sql
--
-- Volumen: 12 categorías, 10.000 productos, 20.000 clientes, 600.000 pedidos
-- distribuidos en los últimos 365 días (hora de Buenos Aires) y 1.500.000 detalles.
-- Incluye el prerrequisito de borrado lógico de pedido y detalle_pedido (ver README).
-- Es determinista salvo por la fecha de ejecución: los pedidos se anclan al día actual.
-- =====================================================================

SET TimeZone = 'America/Argentina/Buenos_Aires';

-- ---------------------------------------------------------------------
-- Prerrequisito de borrado lógico.
-- La consigna filtra "dp.eliminado = FALSE AND ped.eliminado = FALSE". El esquema final
-- del proyecto (TPI) implementa el borrado lógico con deleted_at (cliente, producto), pero
-- pedido y detalle_pedido todavía no lo tenían. Se agrega con la misma convención:
--   eliminado = FALSE   <=>   deleted_at IS NULL
-- ---------------------------------------------------------------------
ALTER TABLE pedido         ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE detalle_pedido ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

BEGIN;

DO $guardas$
BEGIN
    IF EXISTS (SELECT 1 FROM producto) OR EXISTS (SELECT 1 FROM pedido)
       OR EXISTS (SELECT 1 FROM cliente) OR EXISTS (SELECT 1 FROM categoria) THEN
        RAISE EXCEPTION 'La base no está vacía: este script solo se ejecuta sobre una copia nueva creada con schema.sql';
    END IF;
END
$guardas$;

INSERT INTO categoria (nombre, descripcion)
VALUES ('Almacén',     'Laboratorio TP6'),
       ('Bebidas',     'Laboratorio TP6'),
       ('Lácteos',     'Laboratorio TP6'),
       ('Panadería',   'Laboratorio TP6'),
       ('Carnes',      'Laboratorio TP6'),
       ('Verdulería',  'Laboratorio TP6'),
       ('Congelados',  'Laboratorio TP6'),
       ('Limpieza',    'Laboratorio TP6'),
       ('Perfumería',  'Laboratorio TP6'),
       ('Snacks',      'Laboratorio TP6'),
       ('Golosinas',   'Laboratorio TP6'),
       ('Mascotas',    'Laboratorio TP6');

-- Productos repartidos de forma despareja entre categorías (para que el ranking no sea
-- un empate) y con precios distintos por categoría.
WITH cat AS (
    SELECT id_categoria, row_number() OVER (ORDER BY id_categoria) AS k FROM categoria
)
INSERT INTO producto (nombre, descripcion, precio_lista, stock, activo, id_categoria)
SELECT format('TP6_PRODUCTO_%s', lpad(s.n::text, 5, '0')),
       'Producto de laboratorio TP6',
       (300 + mod(s.n * 37, 2000) + cat.k * 150)::numeric(12,2),
       100 + mod(s.n * 19, 400),
       mod(s.n, 25) <> 0,
       cat.id_categoria
FROM generate_series(1, 10000) AS s(n)
JOIN cat ON cat.k = 1 + floor(12 * power(mod(s.n * 7919, 10000) / 10000.0, 1.6))::int;

INSERT INTO cliente (nombre, apellido, email, telefono)
SELECT format('Cliente%s', lpad(s.n::text, 5, '0')),
       format('TP6%s', lpad(s.n::text, 5, '0')),
       format('tp6_cliente_%s@example.invalid', lpad(s.n::text, 5, '0')),
       format('+54-261-%s', lpad(mod(s.n * 7919, 10000000)::text, 7, '0'))
FROM generate_series(1, 20000) AS s(n);

CREATE TEMP TABLE map_producto ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY id_producto)::int AS n, id_producto, precio_lista
FROM producto;
CREATE UNIQUE INDEX ON map_producto (n);
ANALYZE map_producto;

CREATE TEMP TABLE map_cliente ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY id_cliente)::int AS n, id_cliente
FROM cliente;
CREATE UNIQUE INDEX ON map_cliente (n);
ANALYZE map_cliente;

-- 600.000 pedidos: día = mod(n, 365) días atrás. Los pedidos del día actual se reparten
-- entre la medianoche y el momento de la carga, para no generar fechas futuras.
INSERT INTO pedido (fecha, id_cliente, forma_pago)
SELECT CASE
           WHEN mod(s.n, 365) = 0 THEN
               date_trunc('day', now()) + (mod(s.n * 7919, 86400) / 86400.0) * (now() - date_trunc('day', now()))
           ELSE
               date_trunc('day', now()) - mod(s.n, 365) * interval '1 day'
               + mod(s.n * 7919, 86400) * interval '1 second'
       END,
       c.id_cliente,
       (ARRAY['EFECTIVO', 'TARJETA', 'TRANSFERENCIA']::forma_pago_enum[])[(1 + mod(s.n, 3))::int]
FROM generate_series(1::bigint, 600000) AS s(n)
JOIN map_cliente AS c ON c.n = (1 + mod(s.n * 31, 20000))::int;

CREATE TEMP TABLE map_pedido ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY id_pedido)::int AS n, id_pedido
FROM pedido;
CREATE UNIQUE INDEX ON map_pedido (n);
ANALYZE map_pedido;

-- Entre 1 y 4 productos distintos por pedido (promedio 2,5): 1.500.000 detalles.
-- Las posiciones j*7919 mod 10.000 son distintas para j = 0..3, así que no se repite la PK.
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT p.id_pedido, pr.id_producto, 1 + mod(p.n * 3 + j, 6), pr.precio_lista
FROM map_pedido AS p
CROSS JOIN LATERAL generate_series(0, mod(p.n, 4)) AS j
JOIN map_producto AS pr ON pr.n = 1 + mod(p.n * 13 + j * 7919, 10000);

-- Borrado lógico de laboratorio: ~2 % de pedidos y ~1 % de detalles, para que los filtros
-- de la consulta tengan efecto real.
ANALYZE pedido;
ANALYZE detalle_pedido;

UPDATE pedido p
SET deleted_at = p.fecha + interval '2 hours'
FROM map_pedido AS m
WHERE m.id_pedido = p.id_pedido AND mod(m.n, 50) = 7;

UPDATE detalle_pedido d
SET deleted_at = now()
FROM map_pedido AS m
WHERE m.id_pedido = d.id_pedido AND mod(m.n, 97) = 11 AND mod(d.id_producto, 2) = 0;

COMMIT;

VACUUM ANALYZE categoria;
VACUUM ANALYZE producto;
VACUUM ANALYZE cliente;
VACUUM ANALYZE pedido;
VACUUM ANALYZE detalle_pedido;

-- == Volumen cargado ==
SELECT 'categoria' AS tabla, count(*) AS filas FROM categoria
UNION ALL SELECT 'producto', count(*) FROM producto
UNION ALL SELECT 'cliente', count(*) FROM cliente
UNION ALL SELECT 'pedido', count(*) FROM pedido
UNION ALL SELECT 'pedido eliminado', count(*) FROM pedido WHERE deleted_at IS NOT NULL
UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido
UNION ALL SELECT 'detalle eliminado', count(*) FROM detalle_pedido WHERE deleted_at IS NOT NULL
UNION ALL SELECT 'pedidos de hoy', count(*) FROM pedido WHERE fecha >= current_date AND fecha < current_date + 1;

-- == Productos por categoría ==
SELECT c.nombre, count(*) AS productos
FROM producto p JOIN categoria c USING (id_categoria)
GROUP BY c.nombre ORDER BY productos DESC;
