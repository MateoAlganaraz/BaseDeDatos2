
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 5 - Parte D.1: usuario_anon, copia anonimizada y determinista de usuario.
--
-- Ejecutar como superusuario (o admin_datos con SET ROLE food_store_owner):
-- Versión DBeaver: sin metacomandos de psql (ejecutar con Alt+X).
-- En DBeaver la sal de laboratorio ('foodstore-lab-2026') está escrita en la consulta. La sal
-- define el orden de los seudónimos; en un
-- entorno real se guarda fuera del repositorio.
--
-- Técnicas por columna:
--   id_usuario     -> id_anon: seudónimo secuencial asignado en el orden de md5(sal || id).
--                     No conserva el orden de alta ni permite volver al id real sin la sal.
--   nombre, apellido, email -> reemplazo por valores sintéticos derivados de id_anon.
--   telefono, password_hash, intentos_fallidos, bloqueado_hasta -> suprimidos (no se copian).
--   fecha_alta     -> generalizada a mes_alta (primer día del mes, hora de Buenos Aires).
--   rol, activo    -> se conservan: son los atributos que el análisis agregado necesita.
-- Determinismo: con la misma tabla usuario y la misma sal, la tabla resultante es idéntica.
-- =====================================================================


BEGIN;

DROP TABLE IF EXISTS usuario_anon;

CREATE TABLE usuario_anon AS
WITH seudonimos AS (
    SELECT u.*,
           row_number() OVER (ORDER BY md5('foodstore-lab-2026' || u.id_usuario::text), u.id_usuario) AS id_anon
    FROM usuario u
)
SELECT id_anon::bigint                                             AS id_anon,
       format('Nombre_%s', lpad(id_anon::text, 5, '0'))            AS nombre,
       format('Apellido_%s', lpad(id_anon::text, 5, '0'))          AS apellido,
       format('usuario_%s@ejemplo.invalid', lpad(id_anon::text, 5, '0')) AS email,
       rol,
       date_trunc('month', fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS mes_alta,
       activo
FROM seudonimos;

ALTER TABLE usuario_anon ADD CONSTRAINT pk_usuario_anon PRIMARY KEY (id_anon);
ALTER TABLE usuario_anon ALTER COLUMN rol SET NOT NULL;
ALTER TABLE usuario_anon ALTER COLUMN mes_alta SET NOT NULL;
COMMENT ON TABLE usuario_anon IS
    'Copia anonimizada de usuario (TP Unidad 5, Parte D). Sin datos personales: apta para reportes y para compartir con asistentes de IA.';

-- Misma política que el resto de los objetos (roles.sql): dueño sin login y lectura solo para reportes (R5.2).
ALTER TABLE usuario_anon OWNER TO food_store_owner;
GRANT SELECT ON usuario_anon TO rol_reportes;

COMMIT;

ANALYZE usuario_anon;

-- == D.1 Muestra de usuario_anon ==
SELECT * FROM usuario_anon ORDER BY id_anon LIMIT 5;

-- == D.1 Controles de anonimización (esperado: 0 coincidencias en las dos primeras filas) ==
SELECT 'emails reales presentes en usuario_anon' AS control,
       count(*) AS valor
FROM usuario_anon a JOIN usuario u ON lower(u.email) = lower(a.email)
UNION ALL
SELECT 'nombre + apellido reales presentes', count(*)
FROM usuario_anon a JOIN usuario u ON u.nombre = a.nombre AND u.apellido = a.apellido
UNION ALL
SELECT 'filas en usuario', count(*) FROM usuario
UNION ALL
SELECT 'filas en usuario_anon', count(*) FROM usuario_anon;

-- == D.1 Columnas de usuario_anon (no hay telefono, password_hash ni fecha exacta) ==
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'usuario_anon'
ORDER BY ordinal_position;

-- == D.1 Tamaño mínimo de grupo por (rol, mes_alta): riesgo de reidentificación ==
SELECT min(n) AS grupo_minimo, count(*) FILTER (WHERE n < 3) AS grupos_con_menos_de_3
FROM (SELECT rol, mes_alta, count(*) AS n FROM usuario_anon GROUP BY rol, mes_alta) g;

-- == D.1 Permisos: reportes lee usuario_anon pero no usuario ==
SELECT has_table_privilege('rol_reportes', 'usuario_anon', 'SELECT') AS reportes_lee_anon,
       has_table_privilege('rol_reportes', 'usuario', 'SELECT')      AS reportes_lee_usuario,
       has_any_column_privilege('rol_reportes', 'usuario', 'SELECT') AS reportes_alguna_columna_usuario;
