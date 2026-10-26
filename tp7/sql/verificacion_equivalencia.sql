\pset pager off

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 5 - Parte D.3: ¿anonimizar distorsiona los agregados?
--
-- Ejecuta, sin modificar, las dos consultas que generó la IA (docs/ia/D_respuesta_...):
--   Q_anon: sobre usuario_anon, como rol_reportes (el rol que la va a usar).
--   Q_real: sobre usuario, como superusuario.
-- y compara sus resultados: lado a lado, EXCEPT en ambos sentidos y totales.
--   psql -X -d food_store_tp7_lab -f tp7/sql/verificacion_equivalencia.sql
-- =====================================================================

-- Q_anon (generada por la IA)
CREATE TEMP VIEW q_anon AS
SELECT
    rol,
    mes_alta,
    count(*)                         AS cantidad_usuarios,
    count(*) FILTER (WHERE activo)   AS cantidad_activos
FROM usuario_anon
GROUP BY rol, mes_alta
ORDER BY mes_alta, rol;

-- Q_real (generada por la IA)
CREATE TEMP VIEW q_real AS
SELECT
    rol,
    date_trunc('month', fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS mes_alta,
    count(*)                         AS cantidad_usuarios,
    count(*) FILTER (WHERE activo)   AS cantidad_activos
FROM usuario
GROUP BY rol, date_trunc('month', fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
ORDER BY mes_alta, rol;

\echo '== D.3.1 La agregación de Q_anon, ejecutada como rol_reportes (solo tiene SELECT sobre usuario_anon) =='
BEGIN;
SET LOCAL ROLE rol_reportes;
SELECT count(*) AS filas_q_anon, sum(cantidad_usuarios) AS usuarios, sum(cantidad_activos) AS activos
FROM (SELECT rol, mes_alta, count(*) AS cantidad_usuarios, count(*) FILTER (WHERE activo) AS cantidad_activos
      FROM usuario_anon GROUP BY rol, mes_alta) x;
ROLLBACK;

\echo '== D.3.2 Resultados lado a lado (Q_real | Q_anon) =='
SELECT coalesce(r.mes_alta, a.mes_alta) AS mes_alta,
       coalesce(r.rol, a.rol)           AS rol,
       r.cantidad_usuarios AS usuarios_real,  a.cantidad_usuarios AS usuarios_anon,
       r.cantidad_activos  AS activos_real,   a.cantidad_activos  AS activos_anon,
       (r IS NOT DISTINCT FROM a)        AS igual
FROM q_real r
FULL JOIN q_anon a ON a.rol = r.rol AND a.mes_alta = r.mes_alta
ORDER BY 1, 2;

\echo '== D.3.3 Equivalencia formal (esperado: 0 y 0) =='
SELECT 'Q_real EXCEPT Q_anon' AS control, count(*) AS filas FROM (TABLE q_real EXCEPT TABLE q_anon) x
UNION ALL
SELECT 'Q_anon EXCEPT Q_real', count(*) FROM (TABLE q_anon EXCEPT TABLE q_real) y
UNION ALL
SELECT 'grupos en Q_real', count(*) FROM q_real
UNION ALL
SELECT 'grupos en Q_anon', count(*) FROM q_anon;

\echo '== D.3.4 Totales por rol (los mismos en ambas) =='
SELECT rol, sum(cantidad_usuarios) FILTER (WHERE src = 'real') AS usuarios_real,
            sum(cantidad_usuarios) FILTER (WHERE src = 'anon') AS usuarios_anon,
            sum(cantidad_activos)  FILTER (WHERE src = 'real') AS activos_real,
            sum(cantidad_activos)  FILTER (WHERE src = 'anon') AS activos_anon
FROM (SELECT 'real' AS src, * FROM q_real UNION ALL SELECT 'anon', * FROM q_anon) t
GROUP BY rol ORDER BY rol;

\echo '== D.3.5 Tipos de columna de ambas consultas (deben coincidir) =='
SELECT 'q_real' AS consulta, attname, format_type(atttypid, atttypmod) AS tipo
FROM pg_attribute WHERE attrelid = 'q_real'::regclass AND attnum > 0
UNION ALL
SELECT 'q_anon', attname, format_type(atttypid, atttypmod)
FROM pg_attribute WHERE attrelid = 'q_anon'::regclass AND attnum > 0
ORDER BY 2, 1;

\echo '== D.3.6 Control negativo: la versión "ingenua" sin AT TIME ZONE, en una sesión con otra zona horaria =='
-- Demuestra que la equivalencia no es automática: si se agrupa por date_trunc('month', fecha_alta)
-- y la sesión está en Asia/Tokyo (UTC+9), las altas de la tarde del último día del mes en Buenos
-- Aires caen en el mes siguiente.
BEGIN;
SET LOCAL TimeZone = 'Asia/Tokyo';
SELECT count(*) AS grupos_distintos
FROM ((SELECT rol, date_trunc('month', fecha_alta)::date AS mes_alta, count(*), count(*) FILTER (WHERE activo)
       FROM usuario GROUP BY 1, 2)
      EXCEPT TABLE q_anon) d;
ROLLBACK;
