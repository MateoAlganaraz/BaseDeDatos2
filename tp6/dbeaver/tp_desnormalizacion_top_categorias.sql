
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 4 - Parte 2: top 5 de categorías por monto vendido en el día
-- Patrón elegido: tabla resumen precalculada + disparadores de sincronización.
--
-- Contenido (en orden de ejecución):
--   0. Sesión y prerrequisito de borrado lógico.
--   1. 5.2(a) Consulta original con EXPLAIN (ANALYZE, BUFFERS).
--   2. 5.2(c) Estructura desnormalizada, carga inicial y disparadores.
--   3. 5.2(d) Consultas que leen la estructura desnormalizada, con EXPLAIN ANALYZE,
--            y control de equivalencia con EXCEPT contra la consulta original.
--   4. 5.2(e) Auditoría de desincronización (resultado esperado: vacío).
--   5. Pruebas de sincronización (alta, baja lógica, cambio de fecha, cambio de categoría,
--      borrado físico) con auditoría luego de cada caso; todo dentro de ROLLBACK.
--
-- Versión DBeaver (sin metacomandos de psql). Original, después de 00_carga_laboratorio.sql:
--   psql -X -v ON_ERROR_STOP=1 -d food_store_tp6_lab -f tp6/tp_desnormalizacion_top_categorias.sql
--
-- Correspondencia entre la consigna y el esquema real del repositorio (schema.sql):
--   pr.id, c.id, ped.id           -> id_producto, id_categoria, id_pedido
--   dp.subtotal                   -> dp.cantidad * dp.precio_unitario
--   eliminado = FALSE             -> deleted_at IS NULL   (convención del TPI)
--   ped.fecha = CURRENT_DATE      -> ped.fecha >= CURRENT_DATE AND ped.fecha < CURRENT_DATE + 1
--                                    (pedido.fecha es TIMESTAMPTZ; día de negocio en Buenos Aires)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Sesión y prerrequisito
-- ---------------------------------------------------------------------
SET TimeZone = 'America/Argentina/Buenos_Aires';

ALTER TABLE pedido         ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE detalle_pedido ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Reejecución limpia del TP (no afecta datos de Food Store).
DROP TABLE IF EXISTS resumen_venta_diaria_categoria CASCADE;
DROP FUNCTION IF EXISTS fn_tp6_resumen_detalle() CASCADE;
DROP FUNCTION IF EXISTS fn_tp6_resumen_pedido() CASCADE;
DROP FUNCTION IF EXISTS fn_tp6_resumen_producto() CASCADE;
DROP FUNCTION IF EXISTS fn_tp6_resumen_truncate() CASCADE;
DROP FUNCTION IF EXISTS fn_tp6_reconstruir_resumen();
DROP FUNCTION IF EXISTS fn_tp6_dia_negocio(timestamptz);

-- ---------------------------------------------------------------------
-- 1. 5.2(a) Consulta original sobre las cuatro tablas
-- ---------------------------------------------------------------------
-- == 5.2(a) Resultado de la consulta original ==
SELECT c.nombre AS categoria,
       SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp
JOIN producto  pr  ON pr.id_producto  = dp.id_producto
JOIN categoria c   ON c.id_categoria  = pr.id_categoria
JOIN pedido    ped ON ped.id_pedido   = dp.id_pedido
WHERE ped.fecha >= CURRENT_DATE AND ped.fecha < CURRENT_DATE + 1
  AND dp.deleted_at IS NULL
  AND ped.deleted_at IS NULL
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

-- == 5.2(a) EXPLAIN ANALYZE de la consulta original (ANTES) ==
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria,
       SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp
JOIN producto  pr  ON pr.id_producto  = dp.id_producto
JOIN categoria c   ON c.id_categoria  = pr.id_categoria
JOIN pedido    ped ON ped.id_pedido   = dp.id_pedido
WHERE ped.fecha >= CURRENT_DATE AND ped.fecha < CURRENT_DATE + 1
  AND dp.deleted_at IS NULL
  AND ped.deleted_at IS NULL
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

-- ---------------------------------------------------------------------
-- 2. 5.2(c) Estructura desnormalizada y mecanismo de sincronización
-- ---------------------------------------------------------------------

-- Día de negocio de un pedido: fecha calendario en Buenos Aires, independiente del
-- TimeZone de la sesión que escriba. IMMUTABLE porque la zona está fijada.
CREATE FUNCTION fn_tp6_dia_negocio(p_fecha timestamptz)
RETURNS date
LANGUAGE sql
IMMUTABLE PARALLEL SAFE
RETURN (p_fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date;

-- Dato redundante: monto vendido y cantidad de líneas por (día, categoría).
-- Fuente de verdad: detalle_pedido x pedido x producto (no se modifica ninguna tabla base).
-- "lineas" permite saber si una categoría quedó sin ventas (lineas = 0) sin recalcular.
CREATE TABLE resumen_venta_diaria_categoria (
    dia            DATE          NOT NULL,
    id_categoria   BIGINT        NOT NULL,
    total_vendido  NUMERIC(16,2) NOT NULL,
    lineas         INTEGER       NOT NULL,
    actualizado_en TIMESTAMPTZ   NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_resumen_venta_diaria_categoria PRIMARY KEY (dia, id_categoria),
    CONSTRAINT fk_resumen_venta_categoria
        FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria) ON DELETE RESTRICT
);

COMMENT ON TABLE resumen_venta_diaria_categoria IS
    'Desnormalización controlada TP6: SUM(cantidad*precio_unitario) y COUNT(*) de detalles vigentes de pedidos vigentes por día de negocio y categoría actual del producto. Mantenida por disparadores; auditar con la sección 5.2(e).';

-- Reconstrucción completa desde la fuente de verdad: carga inicial y recuperación.
CREATE FUNCTION fn_tp6_reconstruir_resumen()
RETURNS bigint
LANGUAGE plpgsql
AS $fn$
DECLARE
    v_filas bigint;
BEGIN
    DELETE FROM resumen_venta_diaria_categoria;
    INSERT INTO resumen_venta_diaria_categoria (dia, id_categoria, total_vendido, lineas)
    SELECT fn_tp6_dia_negocio(ped.fecha), pr.id_categoria,
           SUM(dp.cantidad * dp.precio_unitario), COUNT(*)
    FROM detalle_pedido dp
    JOIN pedido   ped ON ped.id_pedido  = dp.id_pedido
    JOIN producto pr  ON pr.id_producto = dp.id_producto
    WHERE dp.deleted_at IS NULL
      AND ped.deleted_at IS NULL
    GROUP BY 1, 2;
    GET DIAGNOSTICS v_filas = ROW_COUNT;
    RETURN v_filas;
END
$fn$;

-- detalle_pedido: altas, modificaciones y borrados físicos.
-- Disparadores por sentencia con tablas de transición: una carga masiva aplica un único
-- upsert agregado por (día, categoría) en lugar de uno por fila.
CREATE FUNCTION fn_tp6_resumen_detalle()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        INSERT INTO resumen_venta_diaria_categoria AS r (dia, id_categoria, total_vendido, lineas)
        SELECT fn_tp6_dia_negocio(ped.fecha), pr.id_categoria,
               -SUM(v.cantidad * v.precio_unitario), -COUNT(*)
        FROM viejas v
        JOIN pedido   ped ON ped.id_pedido  = v.id_pedido
        JOIN producto pr  ON pr.id_producto = v.id_producto
        WHERE v.deleted_at IS NULL AND ped.deleted_at IS NULL
        GROUP BY 1, 2
        ORDER BY 1, 2
        ON CONFLICT (dia, id_categoria) DO UPDATE
           SET total_vendido  = r.total_vendido + EXCLUDED.total_vendido,
               lineas         = r.lineas + EXCLUDED.lineas,
               actualizado_en = clock_timestamp();
    END IF;

    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        INSERT INTO resumen_venta_diaria_categoria AS r (dia, id_categoria, total_vendido, lineas)
        SELECT fn_tp6_dia_negocio(ped.fecha), pr.id_categoria,
               SUM(n.cantidad * n.precio_unitario), COUNT(*)
        FROM nuevas n
        JOIN pedido   ped ON ped.id_pedido  = n.id_pedido
        JOIN producto pr  ON pr.id_producto = n.id_producto
        WHERE n.deleted_at IS NULL AND ped.deleted_at IS NULL
        GROUP BY 1, 2
        ORDER BY 1, 2
        ON CONFLICT (dia, id_categoria) DO UPDATE
           SET total_vendido  = r.total_vendido + EXCLUDED.total_vendido,
               lineas         = r.lineas + EXCLUDED.lineas,
               actualizado_en = clock_timestamp();
    END IF;

    IF EXISTS (SELECT 1 FROM resumen_venta_diaria_categoria WHERE lineas < 0 OR total_vendido < 0) THEN
        RAISE EXCEPTION 'resumen_venta_diaria_categoria quedó negativo: desincronización detectada';
    END IF;
    RETURN NULL;
END
$fn$;

CREATE TRIGGER trg_tp6_resumen_detalle_ins
AFTER INSERT ON detalle_pedido
REFERENCING NEW TABLE AS nuevas
FOR EACH STATEMENT EXECUTE FUNCTION fn_tp6_resumen_detalle();

CREATE TRIGGER trg_tp6_resumen_detalle_upd
AFTER UPDATE ON detalle_pedido
REFERENCING OLD TABLE AS viejas NEW TABLE AS nuevas
FOR EACH STATEMENT EXECUTE FUNCTION fn_tp6_resumen_detalle();

CREATE TRIGGER trg_tp6_resumen_detalle_del
AFTER DELETE ON detalle_pedido
REFERENCING OLD TABLE AS viejas
FOR EACH STATEMENT EXECUTE FUNCTION fn_tp6_resumen_detalle();

-- pedido: un cambio de fecha mueve las ventas de día; una baja/alta lógica las resta/suma.
-- (INSERT de pedido no aporta: aún no tiene detalles. DELETE físico está bloqueado por la
-- FK RESTRICT de detalle_pedido mientras tenga detalles.)
CREATE FUNCTION fn_tp6_resumen_pedido()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
    WITH cambiados AS (
        SELECT v.id_pedido,
               v.fecha AS fecha_vieja, v.deleted_at AS baja_vieja,
               n.fecha AS fecha_nueva, n.deleted_at AS baja_nueva
        FROM viejas v
        JOIN nuevas n ON n.id_pedido = v.id_pedido
        WHERE v.fecha IS DISTINCT FROM n.fecha
           OR (v.deleted_at IS NULL) <> (n.deleted_at IS NULL)
    ),
    deltas AS (
        SELECT fn_tp6_dia_negocio(c.fecha_vieja) AS dia, pr.id_categoria,
               -(dp.cantidad * dp.precio_unitario) AS monto, -1 AS lineas
        FROM cambiados c
        JOIN detalle_pedido dp ON dp.id_pedido = c.id_pedido AND dp.deleted_at IS NULL
        JOIN producto pr ON pr.id_producto = dp.id_producto
        WHERE c.baja_vieja IS NULL
        UNION ALL
        SELECT fn_tp6_dia_negocio(c.fecha_nueva), pr.id_categoria,
               dp.cantidad * dp.precio_unitario, 1
        FROM cambiados c
        JOIN detalle_pedido dp ON dp.id_pedido = c.id_pedido AND dp.deleted_at IS NULL
        JOIN producto pr ON pr.id_producto = dp.id_producto
        WHERE c.baja_nueva IS NULL
    )
    INSERT INTO resumen_venta_diaria_categoria AS r (dia, id_categoria, total_vendido, lineas)
    SELECT dia, id_categoria, SUM(monto), SUM(lineas)
    FROM deltas
    GROUP BY dia, id_categoria
    ORDER BY dia, id_categoria
    ON CONFLICT (dia, id_categoria) DO UPDATE
       SET total_vendido  = r.total_vendido + EXCLUDED.total_vendido,
           lineas         = r.lineas + EXCLUDED.lineas,
           actualizado_en = clock_timestamp();

    IF EXISTS (SELECT 1 FROM resumen_venta_diaria_categoria WHERE lineas < 0 OR total_vendido < 0) THEN
        RAISE EXCEPTION 'resumen_venta_diaria_categoria quedó negativo: desincronización detectada';
    END IF;
    RETURN NULL;
END
$fn$;

CREATE TRIGGER trg_tp6_resumen_pedido_upd
AFTER UPDATE ON pedido
REFERENCING OLD TABLE AS viejas NEW TABLE AS nuevas
FOR EACH STATEMENT EXECUTE FUNCTION fn_tp6_resumen_pedido();

-- producto: el reporte agrupa por la categoría ACTUAL del producto; si se recategoriza,
-- sus ventas históricas se mueven de categoría (igual que en la consulta original).
CREATE FUNCTION fn_tp6_resumen_producto()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
    WITH cambiados AS (
        SELECT v.id_producto, v.id_categoria AS cat_vieja, n.id_categoria AS cat_nueva
        FROM viejas v
        JOIN nuevas n ON n.id_producto = v.id_producto
        WHERE v.id_categoria <> n.id_categoria
    ),
    ventas AS (
        SELECT fn_tp6_dia_negocio(ped.fecha) AS dia, c.cat_vieja, c.cat_nueva,
               dp.cantidad * dp.precio_unitario AS monto
        FROM cambiados c
        JOIN detalle_pedido dp ON dp.id_producto = c.id_producto AND dp.deleted_at IS NULL
        JOIN pedido ped ON ped.id_pedido = dp.id_pedido AND ped.deleted_at IS NULL
    ),
    deltas AS (
        SELECT dia, cat_vieja AS id_categoria, -monto AS monto, -1 AS lineas FROM ventas
        UNION ALL
        SELECT dia, cat_nueva, monto, 1 FROM ventas
    )
    INSERT INTO resumen_venta_diaria_categoria AS r (dia, id_categoria, total_vendido, lineas)
    SELECT dia, id_categoria, SUM(monto), SUM(lineas)
    FROM deltas
    GROUP BY dia, id_categoria
    ORDER BY dia, id_categoria
    ON CONFLICT (dia, id_categoria) DO UPDATE
       SET total_vendido  = r.total_vendido + EXCLUDED.total_vendido,
           lineas         = r.lineas + EXCLUDED.lineas,
           actualizado_en = clock_timestamp();

    IF EXISTS (SELECT 1 FROM resumen_venta_diaria_categoria WHERE lineas < 0 OR total_vendido < 0) THEN
        RAISE EXCEPTION 'resumen_venta_diaria_categoria quedó negativo: desincronización detectada';
    END IF;
    RETURN NULL;
END
$fn$;

CREATE TRIGGER trg_tp6_resumen_producto_upd
AFTER UPDATE ON producto
REFERENCING OLD TABLE AS viejas NEW TABLE AS nuevas
FOR EACH STATEMENT EXECUTE FUNCTION fn_tp6_resumen_producto();

-- TRUNCATE no dispara triggers de fila ni de transición: se vacía también el resumen.
CREATE FUNCTION fn_tp6_resumen_truncate()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
    DELETE FROM resumen_venta_diaria_categoria;
    RETURN NULL;
END
$fn$;

CREATE TRIGGER trg_tp6_resumen_detalle_truncate
AFTER TRUNCATE ON detalle_pedido
FOR EACH STATEMENT EXECUTE FUNCTION fn_tp6_resumen_truncate();

-- Carga inicial bajo bloqueo: ninguna escritura concurrente puede colarse entre la
-- reconstrucción y la activación efectiva de los disparadores.
BEGIN;
LOCK TABLE detalle_pedido, pedido, producto IN SHARE ROW EXCLUSIVE MODE;
SELECT fn_tp6_reconstruir_resumen() AS filas_resumen_cargadas;
COMMIT;

VACUUM ANALYZE resumen_venta_diaria_categoria;

-- ---------------------------------------------------------------------
-- 3. 5.2(d) Consulta que lee la estructura desnormalizada
-- ---------------------------------------------------------------------
-- == 5.2(d) Resultado leyendo el resumen ==
SELECT c.nombre AS categoria,
       r.total_vendido
FROM resumen_venta_diaria_categoria r
JOIN categoria c ON c.id_categoria = r.id_categoria
WHERE r.dia = CURRENT_DATE
  AND r.lineas > 0
ORDER BY r.total_vendido DESC
LIMIT 5;

-- == 5.2(d) EXPLAIN ANALYZE leyendo el resumen (DESPUÉS) ==
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria,
       r.total_vendido
FROM resumen_venta_diaria_categoria r
JOIN categoria c ON c.id_categoria = r.id_categoria
WHERE r.dia = CURRENT_DATE
  AND r.lineas > 0
ORDER BY r.total_vendido DESC
LIMIT 5;

-- Segunda consulta que aprovecha la misma estructura: top 5 de los últimos 7 días.
-- == 5.2(d) Consulta adicional: top 5 de los últimos 7 días leyendo el resumen ==
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria,
       SUM(r.total_vendido) AS total_vendido
FROM resumen_venta_diaria_categoria r
JOIN categoria c ON c.id_categoria = r.id_categoria
WHERE r.dia > CURRENT_DATE - 7 AND r.dia <= CURRENT_DATE
  AND r.lineas > 0
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

-- == Equivalencia: original vs. resumen, hoy y últimos 7 días, sin LIMIT (esperado 0 en los cuatro) ==
WITH original_hoy AS (
    SELECT c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id_producto = dp.id_producto
    JOIN categoria c ON c.id_categoria = pr.id_categoria
    JOIN pedido ped ON ped.id_pedido = dp.id_pedido
    WHERE ped.fecha >= CURRENT_DATE AND ped.fecha < CURRENT_DATE + 1
      AND dp.deleted_at IS NULL AND ped.deleted_at IS NULL
    GROUP BY c.nombre
),
resumen_hoy AS (
    SELECT c.nombre AS categoria, r.total_vendido
    FROM resumen_venta_diaria_categoria r
    JOIN categoria c ON c.id_categoria = r.id_categoria
    WHERE r.dia = CURRENT_DATE AND r.lineas > 0
),
original_7d AS (
    SELECT c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id_producto = dp.id_producto
    JOIN categoria c ON c.id_categoria = pr.id_categoria
    JOIN pedido ped ON ped.id_pedido = dp.id_pedido
    WHERE ped.fecha >= CURRENT_DATE - 6 AND ped.fecha < CURRENT_DATE + 1
      AND dp.deleted_at IS NULL AND ped.deleted_at IS NULL
    GROUP BY c.nombre
),
resumen_7d AS (
    SELECT c.nombre AS categoria, SUM(r.total_vendido) AS total_vendido
    FROM resumen_venta_diaria_categoria r
    JOIN categoria c ON c.id_categoria = r.id_categoria
    WHERE r.dia > CURRENT_DATE - 7 AND r.dia <= CURRENT_DATE AND r.lineas > 0
    GROUP BY c.nombre
)
SELECT 'hoy: original EXCEPT resumen' AS control, count(*) AS filas FROM (TABLE original_hoy EXCEPT TABLE resumen_hoy) a
UNION ALL SELECT 'hoy: resumen EXCEPT original', count(*) FROM (TABLE resumen_hoy EXCEPT TABLE original_hoy) b
UNION ALL SELECT '7 días: original EXCEPT resumen', count(*) FROM (TABLE original_7d EXCEPT TABLE resumen_7d) c
UNION ALL SELECT '7 días: resumen EXCEPT original', count(*) FROM (TABLE resumen_7d EXCEPT TABLE original_7d) d;

-- ---------------------------------------------------------------------
-- 4. 5.2(e) Auditoría: diferencias entre el dato redundante y su fuente de verdad.
-- Recalcula todo el historial y lo compara con el resumen. Resultado esperado: 0 filas.
-- Una fila con lineas = 0 equivale a "sin ventas" y se compara como 0.
-- ---------------------------------------------------------------------
-- == 5.2(e) Auditoría completa (esperado: 0 filas) ==
WITH fuente AS (
    SELECT fn_tp6_dia_negocio(ped.fecha) AS dia, pr.id_categoria,
           SUM(dp.cantidad * dp.precio_unitario) AS total_vendido, COUNT(*) AS lineas
    FROM detalle_pedido dp
    JOIN pedido   ped ON ped.id_pedido  = dp.id_pedido
    JOIN producto pr  ON pr.id_producto = dp.id_producto
    WHERE dp.deleted_at IS NULL AND ped.deleted_at IS NULL
    GROUP BY 1, 2
)
SELECT COALESCE(f.dia, r.dia)                   AS dia,
       COALESCE(f.id_categoria, r.id_categoria) AS id_categoria,
       f.total_vendido AS total_fuente,  r.total_vendido AS total_resumen,
       f.lineas        AS lineas_fuente, r.lineas        AS lineas_resumen
FROM fuente f
FULL JOIN resumen_venta_diaria_categoria r
       ON r.dia = f.dia AND r.id_categoria = f.id_categoria
WHERE COALESCE(f.total_vendido, 0) <> COALESCE(r.total_vendido, 0)
   OR COALESCE(f.lineas, 0)        <> COALESCE(r.lineas, 0)
   OR r.lineas < 0 OR r.total_vendido < 0
ORDER BY 1, 2;

-- ---------------------------------------------------------------------
-- 5. Pruebas de sincronización: cada operación se audita (esperado: 0 diferencias).
-- Todo se revierte al final; la base queda igual que antes de las pruebas.
-- ---------------------------------------------------------------------
CREATE TEMP VIEW tmp_auditoria_resumen AS
WITH fuente AS (
    SELECT fn_tp6_dia_negocio(ped.fecha) AS dia, pr.id_categoria,
           SUM(dp.cantidad * dp.precio_unitario) AS total_vendido, COUNT(*) AS lineas
    FROM detalle_pedido dp
    JOIN pedido   ped ON ped.id_pedido  = dp.id_pedido
    JOIN producto pr  ON pr.id_producto = dp.id_producto
    WHERE dp.deleted_at IS NULL AND ped.deleted_at IS NULL
    GROUP BY 1, 2
)
SELECT COALESCE(f.dia, r.dia) AS dia, COALESCE(f.id_categoria, r.id_categoria) AS id_categoria
FROM fuente f
FULL JOIN resumen_venta_diaria_categoria r
       ON r.dia = f.dia AND r.id_categoria = f.id_categoria
WHERE COALESCE(f.total_vendido, 0) <> COALESCE(r.total_vendido, 0)
   OR COALESCE(f.lineas, 0)        <> COALESCE(r.lineas, 0);

BEGIN;

CREATE TEMP TABLE tmp_prueba_pedido ON COMMIT DROP AS
WITH nuevo AS (
    INSERT INTO pedido (fecha, id_cliente, forma_pago)
    SELECT now(), min(id_cliente), 'TARJETA' FROM cliente
    RETURNING id_pedido
)
SELECT id_pedido FROM nuevo;

-- == 5.1 Alta de pedido de hoy con 3 detalles ==
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT t.id_pedido, p.id_producto, 2, p.precio_lista
FROM tmp_prueba_pedido t
CROSS JOIN LATERAL (SELECT id_producto, precio_lista FROM producto ORDER BY id_producto LIMIT 3) p;
SELECT 'alta' AS caso, count(*) AS diferencias FROM tmp_auditoria_resumen;

-- == 5.2 Modificación de cantidad de un detalle ==
UPDATE detalle_pedido SET cantidad = cantidad + 5
WHERE id_pedido = (SELECT id_pedido FROM tmp_prueba_pedido)
  AND id_producto = (SELECT min(id_producto) FROM producto);
SELECT 'cantidad' AS caso, count(*) AS diferencias FROM tmp_auditoria_resumen;

-- == 5.3 Baja lógica de un detalle ==
UPDATE detalle_pedido SET deleted_at = now()
WHERE id_pedido = (SELECT id_pedido FROM tmp_prueba_pedido)
  AND id_producto = (SELECT max(id_producto) FROM (SELECT id_producto FROM producto ORDER BY id_producto LIMIT 3) x);
SELECT 'baja logica detalle' AS caso, count(*) AS diferencias FROM tmp_auditoria_resumen;

-- == 5.4 Cambio de fecha del pedido a ayer y vuelta a hoy ==
UPDATE pedido SET fecha = fecha - interval '1 day' WHERE id_pedido = (SELECT id_pedido FROM tmp_prueba_pedido);
SELECT 'fecha ayer' AS caso, count(*) AS diferencias FROM tmp_auditoria_resumen;
UPDATE pedido SET fecha = fecha + interval '1 day' WHERE id_pedido = (SELECT id_pedido FROM tmp_prueba_pedido);
SELECT 'fecha hoy' AS caso, count(*) AS diferencias FROM tmp_auditoria_resumen;

-- == 5.5 Baja lógica masiva: 100 pedidos de hoy ==
UPDATE pedido SET deleted_at = now()
WHERE id_pedido IN (SELECT id_pedido FROM pedido
                    WHERE fecha >= CURRENT_DATE AND deleted_at IS NULL
                    ORDER BY id_pedido LIMIT 100);
SELECT 'baja logica 100 pedidos' AS caso, count(*) AS diferencias FROM tmp_auditoria_resumen;

-- == 5.6 Recategorización de un producto con ventas ==
UPDATE producto
SET id_categoria = (SELECT max(id_categoria) FROM categoria)
WHERE id_producto = (SELECT min(id_producto) FROM producto
                     WHERE id_categoria <> (SELECT max(id_categoria) FROM categoria));
SELECT 'recategorizacion' AS caso, count(*) AS diferencias FROM tmp_auditoria_resumen;

-- == 5.7 Borrado físico de los detalles y del pedido de prueba ==
DELETE FROM detalle_pedido WHERE id_pedido = (SELECT id_pedido FROM tmp_prueba_pedido);
DELETE FROM pedido WHERE id_pedido = (SELECT id_pedido FROM tmp_prueba_pedido);
SELECT 'borrado fisico' AS caso, count(*) AS diferencias FROM tmp_auditoria_resumen;

-- == 5.8 Control negativo: se corrompe el resumen a mano y la auditoría debe detectarlo (esperado 1) ==
UPDATE resumen_venta_diaria_categoria
SET total_vendido = total_vendido + 1
WHERE dia = CURRENT_DATE
  AND id_categoria = (SELECT min(id_categoria) FROM categoria);
SELECT 'corrupcion manual' AS caso, count(*) AS diferencias FROM tmp_auditoria_resumen;

ROLLBACK;

-- == Auditoría final tras el ROLLBACK de las pruebas (esperado 0) ==
SELECT count(*) AS diferencias FROM tmp_auditoria_resumen;
