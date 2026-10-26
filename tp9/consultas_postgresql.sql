\set ON_ERROR_STOP on
\pset pager off

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 7 - NoSQL: lado PostgreSQL.
--
--   psql -X -d foodstore -f tp9/consultas_postgresql.sql
--
-- 1. Tablas y claves del subconjunto "pedidos y detalle de pedidos" (Consigna 1).
-- 2. Selección de los 12 pedidos migrados (esquema auxiliar nosql_lab; no modifica Food Store).
-- 3. Documentos que se migran, armados con json_build_object (los usa scripts/exportar_migracion.py).
-- 4. Consultas equivalentes a b) y c) de MongoDB (Consigna 5), sobre el subconjunto y sobre toda la base.
-- 5. Controles de las reglas de integridad y referencia para d).
--
-- Mapeo con el modelo real (los nombres de la consigna son ilustrativos):
--   estado del pedido -> derivado del borrado lógico: pedido.deleted_at IS NULL => 'VIGENTE', si no 'ANULADO'.
--   precio histórico  -> detalle_pedido.precio_unitario (precio cobrado), no producto.precio_lista (actual).
--   línea anulada     -> detalle_pedido.deleted_at IS NOT NULL.
-- =====================================================================

\echo '== 1. Tablas y claves que intervienen =='
SELECT tc.table_name AS tabla, tc.constraint_type AS tipo, tc.constraint_name AS restriccion,
       string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS columnas,
       max(ccu.table_name) FILTER (WHERE tc.constraint_type = 'FOREIGN KEY') AS referencia
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
LEFT JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
WHERE tc.table_schema = 'public'
  AND tc.table_name IN ('pedido', 'detalle_pedido', 'cliente', 'producto', 'categoria')
  AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE')
GROUP BY 1, 2, 3
ORDER BY 1, 2 DESC, 3;

-- ---------------------------------------------------------------------
-- 2. Selección de pedidos a migrar (12): cubre los casos que el modelo debe representar.
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS nosql_lab;
DROP TABLE IF EXISTS nosql_lab.pedido_migrado CASCADE;  -- también borra la vista documento_pedido, que se recrea abajo
CREATE TABLE nosql_lab.pedido_migrado (
    id_pedido BIGINT PRIMARY KEY REFERENCES public.pedido (id_pedido),
    motivo    TEXT NOT NULL
);
INSERT INTO nosql_lab.pedido_migrado (id_pedido, motivo) VALUES
    (1,      'vigente, sin el producto 3373'),
    (2,      'vigente, sin el producto 3373'),
    (3,      'vigente, sin el producto 3373'),
    (7,      'anulado (borrado lógico)'),
    (57,     'anulado (borrado lógico)'),
    (107,    'anulado (borrado lógico)'),
    (2118,   'vigente, contiene el producto 3373'),
    (5355,   'vigente, contiene el producto 3373'),
    (5644,   'vigente, contiene el producto 3373'),
    (8881,   'vigente, contiene el producto 3373'),
    (12118,  'vigente, contiene el producto 3373'),
    (598881, 'vigente, la línea del producto 3373 está anulada');

\echo '== 2. Pedidos seleccionados =='
SELECT m.id_pedido, m.motivo, p.fecha, p.forma_pago,
       CASE WHEN p.deleted_at IS NULL THEN 'VIGENTE' ELSE 'ANULADO' END AS estado
FROM nosql_lab.pedido_migrado m JOIN pedido p USING (id_pedido)
ORDER BY m.id_pedido;

-- ---------------------------------------------------------------------
-- 3. Documentos a migrar (una fila JSON por pedido).
-- Los importes salen como texto para no perder precisión: el exportador los convierte a
-- NumberDecimal (Decimal128) en el insertMany().
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW nosql_lab.documento_pedido AS
SELECT p.id_pedido,
       json_build_object(
           '_id',        p.id_pedido,
           'fecha',      to_char(p.fecha AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'estado',     CASE WHEN p.deleted_at IS NULL THEN 'VIGENTE' ELSE 'ANULADO' END,
           'anulado_en', to_char(p.deleted_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'forma_pago', p.forma_pago,
           'cliente',    json_build_object('id_cliente', c.id_cliente, 'nombre', c.nombre,
                                           'apellido', c.apellido, 'email', c.email),
           'lineas',     l.lineas,
           'total',      l.total::text,
           'cantidad_lineas_vigentes', l.vigentes
       ) AS documento
FROM pedido p
JOIN cliente c USING (id_cliente)
CROSS JOIN LATERAL (
    SELECT json_agg(json_build_object(
               'id_producto',     d.id_producto,
               'producto',        pr.nombre,
               'categoria',       cat.nombre,
               'cantidad',        d.cantidad,
               'precio_unitario', d.precio_unitario::text,
               'subtotal',        (d.cantidad * d.precio_unitario)::text,
               'anulada',         d.deleted_at IS NOT NULL
           ) ORDER BY d.id_producto) AS lineas,
           coalesce(sum(d.cantidad * d.precio_unitario) FILTER (WHERE d.deleted_at IS NULL), 0)::numeric(14,2) AS total,
           count(*) FILTER (WHERE d.deleted_at IS NULL) AS vigentes
    FROM detalle_pedido d
    JOIN producto pr USING (id_producto)
    JOIN categoria cat USING (id_categoria)
    WHERE d.id_pedido = p.id_pedido
) l
WHERE p.id_pedido IN (SELECT id_pedido FROM nosql_lab.pedido_migrado);

\echo '== 3. Ejemplo de documento (pedido 2118) =='
SELECT jsonb_pretty(documento::jsonb) FROM nosql_lab.documento_pedido WHERE id_pedido = 2118;

-- ---------------------------------------------------------------------
-- 4. Consultas equivalentes (Consigna 5)
-- ---------------------------------------------------------------------
\echo '== 4.b Pedidos con estado ANULADO, dentro del subconjunto migrado =='
SELECT p.id_pedido
FROM pedido p
JOIN nosql_lab.pedido_migrado m USING (id_pedido)
WHERE p.deleted_at IS NOT NULL
ORDER BY p.id_pedido;

\echo '== 4.c Pedidos que contienen el producto 3373 en una línea vigente, dentro del subconjunto =='
SELECT DISTINCT d.id_pedido
FROM detalle_pedido d
JOIN nosql_lab.pedido_migrado m USING (id_pedido)
WHERE d.id_producto = 3373
  AND d.deleted_at IS NULL
ORDER BY d.id_pedido;

\echo '== 4. Resumen para la tabla de verificación (subconjunto) =='
SELECT 'b) estado ANULADO' AS consulta, count(*) AS cantidad, string_agg(id_pedido::text, ', ' ORDER BY id_pedido) AS ids
FROM pedido p JOIN nosql_lab.pedido_migrado m USING (id_pedido) WHERE p.deleted_at IS NOT NULL
UNION ALL
SELECT 'c) producto 3373 (línea vigente)', count(DISTINCT d.id_pedido), string_agg(DISTINCT d.id_pedido::text, ', ')
FROM detalle_pedido d JOIN nosql_lab.pedido_migrado m USING (id_pedido)
WHERE d.id_producto = 3373 AND d.deleted_at IS NULL
UNION ALL
SELECT 'c'') producto 3373 incluyendo líneas anuladas', count(DISTINCT d.id_pedido), string_agg(DISTINCT d.id_pedido::text, ', ')
FROM detalle_pedido d JOIN nosql_lab.pedido_migrado m USING (id_pedido)
WHERE d.id_producto = 3373
ORDER BY 1;

\echo '== 4. Las mismas consultas sobre TODA la base (explica la diferencia de alcance) =='
SELECT 'b) estado ANULADO, toda la base' AS consulta, count(*) AS cantidad FROM pedido WHERE deleted_at IS NOT NULL
UNION ALL
SELECT 'c) producto 3373, toda la base', count(DISTINCT id_pedido) FROM detalle_pedido WHERE id_producto = 3373 AND deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- 5. Reglas de integridad y referencia para d)
-- ---------------------------------------------------------------------
\echo '== 5. Regla 1: total = suma de subtotales de líneas vigentes, con precio histórico =='
SELECT m.id_pedido,
       coalesce(sum(d.cantidad * d.precio_unitario) FILTER (WHERE d.deleted_at IS NULL), 0) AS total_historico,
       coalesce(sum(d.cantidad * pr.precio_lista)   FILTER (WHERE d.deleted_at IS NULL), 0) AS total_con_precio_actual
FROM nosql_lab.pedido_migrado m
JOIN detalle_pedido d USING (id_pedido)
JOIN producto pr USING (id_producto)
GROUP BY m.id_pedido
ORDER BY total_historico DESC;

\echo '== 5. Regla 2: un producto aparece una sola vez por pedido (PK compuesta) y cantidad/precio > 0 (esperado 0 y 0) =='
SELECT 'productos repetidos en un pedido' AS control, count(*) AS filas
FROM (SELECT id_pedido, id_producto FROM detalle_pedido JOIN nosql_lab.pedido_migrado USING (id_pedido)
      GROUP BY 1, 2 HAVING count(*) > 1) x
UNION ALL
SELECT 'líneas con cantidad o precio no positivos', count(*)
FROM detalle_pedido JOIN nosql_lab.pedido_migrado USING (id_pedido)
WHERE cantidad <= 0 OR precio_unitario <= 0;

\echo '== 5. Referencia para d): distribución de totales del subconjunto =='
SELECT count(*) AS pedidos,
       min(total) AS minimo,
       percentile_cont(0.5)  WITHIN GROUP (ORDER BY total) AS mediana,
       percentile_cont(0.75) WITHIN GROUP (ORDER BY total) AS p75,
       max(total) AS maximo
FROM (SELECT (documento ->> 'total')::numeric AS total FROM nosql_lab.documento_pedido) t;

\echo '== 5. d) en PostgreSQL (control): pedidos con total > 20000 =='
SELECT id_pedido, (documento ->> 'total')::numeric AS total, documento ->> 'estado' AS estado
FROM nosql_lab.documento_pedido
WHERE (documento ->> 'total')::numeric > 20000
ORDER BY total DESC;
