
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 4 - Parte 2: mediciones repetidas (complemento de 5.2 a/d)
--
-- Un único EXPLAIN ANALYZE puede variar por caché o por ruido del equipo. Este script
-- ejecuta cada variante 30 veces (más 3 de calentamiento) y reporta mínimo, mediana y
-- máximo del "Execution Time". También mide:
--   * la alternativa "solo índice" sobre pedido(fecha), sin desnormalizar (se revierte);
--   * el costo que los disparadores agregan a una inserción de 1.000 detalles.
-- Requiere haber ejecutado tp_desnormalizacion_top_categorias.sql.
-- No deja cambios: el índice alternativo y las inserciones se revierten.
-- =====================================================================

SET TimeZone = 'America/Argentina/Buenos_Aires';

CREATE FUNCTION pg_temp.medir(p_sql text, p_repeticiones int DEFAULT 30)
RETURNS TABLE (minimo_ms numeric, mediana_ms numeric, maximo_ms numeric)
LANGUAGE plpgsql
AS $fn$
DECLARE
    v_plan  json;
    v_t     numeric[] := '{}';
BEGIN
    FOR i IN 1..3 LOOP
        EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || p_sql INTO v_plan;
    END LOOP;
    FOR i IN 1..p_repeticiones LOOP
        EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || p_sql INTO v_plan;
        v_t := v_t || (v_plan -> 0 ->> 'Execution Time')::numeric;
    END LOOP;
    RETURN QUERY
    SELECT round(min(x), 3),
           round((percentile_cont(0.5) WITHIN GROUP (ORDER BY x))::numeric, 3),
           round(max(x), 3)
    FROM unnest(v_t) AS x;
END
$fn$;

-- == Original (4 tablas), 30 ejecuciones ==
SELECT * FROM pg_temp.medir($q$
SELECT c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido ped ON ped.id_pedido = dp.id_pedido
WHERE ped.fecha >= CURRENT_DATE AND ped.fecha < CURRENT_DATE + 1
  AND dp.deleted_at IS NULL AND ped.deleted_at IS NULL
GROUP BY c.nombre ORDER BY total_vendido DESC LIMIT 5
$q$);

-- == Desnormalizada (resumen), 30 ejecuciones ==
SELECT * FROM pg_temp.medir($q$
SELECT c.nombre AS categoria, r.total_vendido
FROM resumen_venta_diaria_categoria r
JOIN categoria c ON c.id_categoria = r.id_categoria
WHERE r.dia = CURRENT_DATE AND r.lineas > 0
ORDER BY r.total_vendido DESC LIMIT 5
$q$);

-- == Alternativa sin desnormalizar: índice sobre pedido(fecha) (se revierte) ==
BEGIN;
CREATE INDEX idx_tp6_alt_pedido_fecha_vigente ON pedido (fecha) WHERE deleted_at IS NULL;
ANALYZE pedido;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido ped ON ped.id_pedido = dp.id_pedido
WHERE ped.fecha >= CURRENT_DATE AND ped.fecha < CURRENT_DATE + 1
  AND dp.deleted_at IS NULL AND ped.deleted_at IS NULL
GROUP BY c.nombre ORDER BY total_vendido DESC LIMIT 5;
SELECT * FROM pg_temp.medir($q$
SELECT c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido ped ON ped.id_pedido = dp.id_pedido
WHERE ped.fecha >= CURRENT_DATE AND ped.fecha < CURRENT_DATE + 1
  AND dp.deleted_at IS NULL AND ped.deleted_at IS NULL
GROUP BY c.nombre ORDER BY total_vendido DESC LIMIT 5
$q$);
ROLLBACK;
ANALYZE pedido;

-- == Costo de escritura: INSERT de 1.000 detalles en 400 pedidos nuevos, 10 repeticiones ==
CREATE FUNCTION pg_temp.medir_insercion(p_con_disparadores boolean, p_repeticiones int DEFAULT 10)
RETURNS TABLE (escenario text, minimo_ms numeric, mediana_ms numeric, maximo_ms numeric)
LANGUAGE plpgsql
AS $fn$
DECLARE
    v_t  numeric[] := '{}';
    v_t0 timestamptz;
    v_ms numeric;
BEGIN
    FOR i IN 1..p_repeticiones LOOP
        BEGIN
            IF NOT p_con_disparadores THEN
                ALTER TABLE detalle_pedido DISABLE TRIGGER trg_tp6_resumen_detalle_ins;
            END IF;
            CREATE TEMP TABLE tmp_pedidos_medicion ON COMMIT DROP AS
            WITH nuevos AS (
                INSERT INTO pedido (fecha, id_cliente, forma_pago)
                SELECT now(), c.id_cliente, 'EFECTIVO'
                FROM (SELECT id_cliente FROM cliente ORDER BY id_cliente LIMIT 400) c
                RETURNING id_pedido
            )
            SELECT row_number() OVER (ORDER BY id_pedido) AS n, id_pedido FROM nuevos;

            v_t0 := clock_timestamp();
            INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
            SELECT t.id_pedido, p.id_producto, 1, p.precio_lista
            FROM tmp_pedidos_medicion t
            CROSS JOIN LATERAL generate_series(0, CASE WHEN t.n <= 200 THEN 2 ELSE 1 END) AS j
            JOIN producto p ON p.id_producto = (SELECT min(id_producto) FROM producto) + mod(t.n * 37 + j * 3001, 10000);
            v_ms := extract(epoch FROM clock_timestamp() - v_t0) * 1000;

            RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'revertir medicion';
        EXCEPTION WHEN raise_exception THEN
            v_t := v_t || v_ms;
        END;
    END LOOP;
    RETURN QUERY
    SELECT CASE WHEN p_con_disparadores THEN 'con disparador de resumen' ELSE 'sin disparador (deshabilitado)' END,
           round(min(x), 3),
           round((percentile_cont(0.5) WITHIN GROUP (ORDER BY x))::numeric, 3),
           round(max(x), 3)
    FROM unnest(v_t) AS x;
END
$fn$;

SELECT * FROM pg_temp.medir_insercion(false)
UNION ALL
SELECT * FROM pg_temp.medir_insercion(true);

-- == Control: la base no cambió (pedidos de hoy, filas del resumen y auditoría) ==
SELECT (SELECT count(*) FROM pedido WHERE fecha >= CURRENT_DATE) AS pedidos_hoy,
       (SELECT count(*) FROM resumen_venta_diaria_categoria)    AS filas_resumen,
       (SELECT count(*) FROM pg_trigger WHERE tgname LIKE 'trg_tp6_%' AND tgenabled = 'O') AS disparadores_activos;
