
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 4 - Parte 1: FNBC sobre control_lote_almacen (Food Store mayorista)
--
-- Contenido (en orden de ejecución):
--   0. Esquema aislado "mayorista" y tablas maestras mínimas (lote, deposito, usuario).
--   1. Esquema original control_lote_almacen + instancia de ejemplo (consigna 4.1).
--   2. Verificación sobre los datos de las dependencias funcionales (4.2 a/b/c).
--   3. Demostración de las tres anomalías (4.2 d), dentro de transacciones revertidas.
--   4. Descomposición FNBC: tablas, PK, FK y vista de compatibilidad con NATURAL JOIN (4.2 e).
--   5. Migración de la instancia de ejemplo y verificación de equivalencia (4.2 f).
--   6. Pruebas sobre el esquema descompuesto (anomalías eliminadas, DF perdida protegida).
--
-- Versión DBeaver (sin metacomandos de psql). Original: psql -X -v ON_ERROR_STOP=1 -d food_store_tp6_lab -f tp6/tp_fnbc_control_lote.sql
-- El script es idempotente: reconstruye el esquema "mayorista" en cada ejecución y
-- no toca las tablas de Food Store (cliente, producto, pedido, ...).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Esquema aislado y tablas maestras
-- La consigna asume que lote y deposito ya existen (como sucursal en AsignacionEntrega).
-- El esquema base del repositorio no las tiene, ni tampoco usuario; se crea el mínimo
-- necesario para que las FOREIGN KEY de la consigna sean válidas.
-- ---------------------------------------------------------------------
DROP SCHEMA IF EXISTS mayorista CASCADE;
CREATE SCHEMA mayorista;
SET search_path = mayorista, public;

CREATE TABLE deposito (
    id     BIGINT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE lote (
    id          BIGINT PRIMARY KEY,
    proveedor   VARCHAR(100) NOT NULL,
    descripcion VARCHAR(200) NOT NULL
);

CREATE TABLE usuario (
    id     BIGINT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);

INSERT INTO deposito (id, nombre) VALUES
    (30, 'Depósito Godoy Cruz'),
    (31, 'Depósito Luján de Cuyo'),
    (32, 'Depósito Maipú');

INSERT INTO lote (id, proveedor, descripcion) VALUES
    (501, 'Distribuidora Andina', 'Harina 000 x 1.200 bolsas'),
    (502, 'Lácteos del Valle',    'Leche larga vida x 3.000 u.'),
    (503, 'Bodega Los Álamos',    'Aceite de oliva x 800 u.'),
    (504, 'Frigorífico Cuyo',     'Congelados x 600 cajas');

INSERT INTO usuario (id, nombre) VALUES
    (801, 'Lucía Pereyra'),
    (802, 'Martín Sosa'),
    (803, 'Valentina Ríos'),
    (804, 'Joaquín Funes');

-- ---------------------------------------------------------------------
-- 1. Esquema original e instancia de ejemplo (tal como la consigna 4.1)
-- ---------------------------------------------------------------------
CREATE TABLE control_lote_almacen (
    lote_id               BIGINT NOT NULL REFERENCES lote(id),
    deposito_id           BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO control_lote_almacen VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- == 1. Instancia de ejemplo original ==
TABLE control_lote_almacen ORDER BY lote_id, deposito_id;

-- ---------------------------------------------------------------------
-- 2. Dependencias funcionales (ver README, sección Parte 1)
--   DF1: {LoteID, DepositoID} -> {ResponsableControlID}
--   DF2: {ResponsableControlID} -> {DepositoID}
-- Clausuras: {ResponsableControlID}+ = {ResponsableControlID, DepositoID}  (no es todo R)
--            {LoteID, DepositoID}+ = {LoteID, ResponsableControlID}+ = R
-- Claves candidatas: {LoteID, DepositoID} y {LoteID, ResponsableControlID}.
-- Las siguientes consultas comprueban que la instancia satisface DF1 y DF2
-- (una instancia no prueba una DF, pero sí podría refutarla): deben devolver 0.
-- ---------------------------------------------------------------------
-- == 2. Instancia vs. DF: filas que refutan DF1 y DF2 (esperado 0 y 0) ==
SELECT 'DF1 {LoteID,DepositoID} -> ResponsableControlID' AS dependencia,
       count(*) AS determinantes_con_mas_de_un_valor
FROM (SELECT lote_id, deposito_id
      FROM control_lote_almacen
      GROUP BY lote_id, deposito_id
      HAVING count(DISTINCT responsable_control_id) > 1) AS x
UNION ALL
SELECT 'DF2 ResponsableControlID -> DepositoID',
       count(*)
FROM (SELECT responsable_control_id
      FROM control_lote_almacen
      GROUP BY responsable_control_id
      HAVING count(DISTINCT deposito_id) > 1) AS y;

-- == 2. DF2 no es superclave: ResponsableControlID se repite en la instancia ==
SELECT responsable_control_id,
       count(*)                           AS filas,
       count(DISTINCT lote_id)            AS lotes_distintos,
       count(DISTINCT deposito_id)        AS depositos_distintos
FROM control_lote_almacen
GROUP BY responsable_control_id
ORDER BY responsable_control_id;

-- ---------------------------------------------------------------------
-- 3. Anomalías habilitadas por la violación de FNBC (cada bloque se revierte)
-- ---------------------------------------------------------------------

-- 3.a Anomalía de actualización: el hecho "801 pertenece al depósito 30" está
-- repetido en dos filas. Si se corrige solo una, la tabla acepta que 801 pertenezca a
-- dos depósitos, contradiciendo DF2. Ninguna restricción del esquema lo impide.
-- == 3.a Anomalía de actualización ==
BEGIN;
UPDATE control_lote_almacen
SET deposito_id = 32
WHERE lote_id = 501 AND responsable_control_id = 801;
SELECT responsable_control_id, array_agg(DISTINCT deposito_id ORDER BY deposito_id) AS depositos
FROM control_lote_almacen
GROUP BY responsable_control_id
HAVING count(DISTINCT deposito_id) > 1;
ROLLBACK;

-- 3.b Anomalía de inserción (1): no se puede registrar que la responsable 803 integra
-- la dotación del depósito 31 hasta que se le asigne un lote: lote_id es NOT NULL y forma
-- parte de la clave primaria.
-- == 3.b Anomalía de inserción: responsable sin lote (se espera ERROR controlado) ==
DO $anomalia_insercion$
BEGIN
    INSERT INTO control_lote_almacen (lote_id, deposito_id, responsable_control_id)
    VALUES (NULL, 31, 803);
    RAISE EXCEPTION 'No debería llegar aquí';
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'Inserción rechazada (%): no hay forma de registrar "803 pertenece al depósito 31" sin un lote.', SQLERRM;
END
$anomalia_insercion$;

-- 3.b Anomalía de inserción (2): el esquema acepta un lote nuevo con un responsable
-- ya asignado a otro depósito, porque solo valida DF1 (la PK), no DF2.
-- == 3.b Anomalía de inserción: 801 aparece en el depósito 31 y la tabla lo acepta ==
BEGIN;
INSERT INTO control_lote_almacen VALUES (504, 31, 801);
SELECT responsable_control_id, array_agg(DISTINCT deposito_id ORDER BY deposito_id) AS depositos
FROM control_lote_almacen
GROUP BY responsable_control_id
HAVING count(DISTINCT deposito_id) > 1;
ROLLBACK;

-- 3.c Anomalía de borrado: al cerrar el control del lote 503 y borrar su fila, se pierde
-- el único registro de que 802 pertenece al depósito 31.
-- == 3.c Anomalía de borrado ==
BEGIN;
DELETE FROM control_lote_almacen WHERE lote_id = 503;
SELECT count(*) AS filas_que_registran_802_en_deposito_31
FROM control_lote_almacen
WHERE responsable_control_id = 802;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 4. Descomposición FNBC (algoritmo: X -> Y violatoria => R1 = X+ , R2 = R - (X+ - X))
--   X = {ResponsableControlID}, X+ = {ResponsableControlID, DepositoID}
--   R1 = responsable_deposito(ResponsableControlID, DepositoID)    clave: ResponsableControlID
--   R2 = control_lote_responsable(LoteID, ResponsableControlID)    clave: (LoteID, ResponsableControlID)
-- ---------------------------------------------------------------------
CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT NOT NULL,
    deposito_id            BIGINT NOT NULL,
    CONSTRAINT pk_responsable_deposito PRIMARY KEY (responsable_control_id),
    CONSTRAINT fk_responsable_deposito_usuario
        FOREIGN KEY (responsable_control_id) REFERENCES usuario(id) ON DELETE RESTRICT,
    CONSTRAINT fk_responsable_deposito_deposito
        FOREIGN KEY (deposito_id) REFERENCES deposito(id) ON DELETE RESTRICT
);

CREATE INDEX idx_responsable_deposito_deposito ON responsable_deposito (deposito_id);

CREATE TABLE control_lote_responsable (
    lote_id                BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,
    CONSTRAINT pk_control_lote_responsable PRIMARY KEY (lote_id, responsable_control_id),
    CONSTRAINT fk_control_lote_responsable_lote
        FOREIGN KEY (lote_id) REFERENCES lote(id) ON DELETE RESTRICT,
    CONSTRAINT fk_control_lote_responsable_responsable
        FOREIGN KEY (responsable_control_id)
        REFERENCES responsable_deposito(responsable_control_id) ON DELETE RESTRICT
);

CREATE INDEX idx_control_lote_responsable_responsable
    ON control_lote_responsable (responsable_control_id);

-- La descomposición FNBC no preserva DF1 ({LoteID, DepositoID} -> ResponsableControlID):
-- sus atributos quedan repartidos en dos tablas. Para no perder la regla de negocio se la
-- controla con disparadores (no con una columna redundante, que reintroduciría DF2 en R2).
CREATE FUNCTION fn_control_lote_un_responsable_por_deposito()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
DECLARE
    v_deposito BIGINT;
    v_otro     BIGINT;
BEGIN
    -- Serializa las altas de un mismo lote para que dos transacciones concurrentes
    -- no puedan asignar dos responsables del mismo depósito.
    PERFORM 1 FROM lote WHERE id = NEW.lote_id FOR UPDATE;

    SELECT deposito_id INTO v_deposito
    FROM responsable_deposito
    WHERE responsable_control_id = NEW.responsable_control_id;

    SELECT clr.responsable_control_id INTO v_otro
    FROM control_lote_responsable AS clr
    JOIN responsable_deposito AS rd USING (responsable_control_id)
    WHERE clr.lote_id = NEW.lote_id
      AND rd.deposito_id = v_deposito
      AND clr.responsable_control_id <> NEW.responsable_control_id
    LIMIT 1;

    IF v_otro IS NOT NULL THEN
        RAISE EXCEPTION 'DF {LoteID, DepositoID} -> ResponsableControlID: el lote % ya tiene al responsable % en el depósito %',
            NEW.lote_id, v_otro, v_deposito
            USING ERRCODE = 'unique_violation';
    END IF;
    RETURN NEW;
END
$fn$;

CREATE TRIGGER trg_control_lote_un_responsable_por_deposito
BEFORE INSERT OR UPDATE ON control_lote_responsable
FOR EACH ROW EXECUTE FUNCTION fn_control_lote_un_responsable_por_deposito();

-- Mover a un responsable de depósito podría romper la misma regla en lotes que ya controla.
CREATE FUNCTION fn_responsable_cambio_deposito()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM control_lote_responsable AS propio
        JOIN control_lote_responsable AS otro
          ON otro.lote_id = propio.lote_id
         AND otro.responsable_control_id <> propio.responsable_control_id
        JOIN responsable_deposito AS rd
          ON rd.responsable_control_id = otro.responsable_control_id
        WHERE propio.responsable_control_id = NEW.responsable_control_id
          AND rd.deposito_id = NEW.deposito_id
    ) THEN
        RAISE EXCEPTION 'Mover al responsable % al depósito % dejaría un lote con dos responsables en ese depósito',
            NEW.responsable_control_id, NEW.deposito_id
            USING ERRCODE = 'unique_violation';
    END IF;
    RETURN NEW;
END
$fn$;

CREATE TRIGGER trg_responsable_cambio_deposito
BEFORE UPDATE OF deposito_id ON responsable_deposito
FOR EACH ROW EXECUTE FUNCTION fn_responsable_cambio_deposito();

-- Vista de compatibilidad: reconstruye la relación original con una reunión natural
-- sobre el único atributo común, responsable_control_id.
CREATE VIEW vw_control_lote_almacen AS
SELECT lote_id, deposito_id, responsable_control_id
FROM control_lote_responsable
NATURAL JOIN responsable_deposito;

-- ---------------------------------------------------------------------
-- 5. Migración de la instancia de ejemplo y verificación
-- ---------------------------------------------------------------------
BEGIN;

-- Precondición: los datos actuales deben cumplir DF2; si no, la proyección perdería
-- información y la migración debe abortar (no se "elige" un depósito al azar).
DO $precondicion$
BEGIN
    IF EXISTS (
        SELECT 1 FROM control_lote_almacen
        GROUP BY responsable_control_id
        HAVING count(DISTINCT deposito_id) > 1
    ) THEN
        RAISE EXCEPTION 'Hay responsables en más de un depósito: depurar antes de migrar';
    END IF;
END
$precondicion$;

-- R1 = proyección sobre {ResponsableControlID, DepositoID}
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM control_lote_almacen;

-- R2 = proyección sobre {LoteID, ResponsableControlID}
INSERT INTO control_lote_responsable (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id
FROM control_lote_almacen;

COMMIT;

-- == 5. Tablas descompuestas ==
TABLE responsable_deposito ORDER BY responsable_control_id;
TABLE control_lote_responsable ORDER BY lote_id, responsable_control_id;

-- == 5. Vista de compatibilidad (reunión natural) ==
SELECT * FROM vw_control_lote_almacen ORDER BY lote_id, deposito_id;

-- == 5. Equivalencia original vs. vista (esperado: 0, 0 y conteos iguales) ==
SELECT 'original EXCEPT vista' AS control, count(*) AS filas
FROM (TABLE control_lote_almacen EXCEPT SELECT lote_id, deposito_id, responsable_control_id FROM vw_control_lote_almacen) AS a
UNION ALL
SELECT 'vista EXCEPT original', count(*)
FROM (SELECT lote_id, deposito_id, responsable_control_id FROM vw_control_lote_almacen EXCEPT TABLE control_lote_almacen) AS b
UNION ALL
SELECT 'filas en original', count(*) FROM control_lote_almacen
UNION ALL
SELECT 'filas en vista', count(*) FROM vw_control_lote_almacen;

-- ---------------------------------------------------------------------
-- 6. Pruebas sobre el esquema descompuesto (todo se revierte)
-- ---------------------------------------------------------------------
-- == 6.a Inserción: 803 se registra en el depósito 31 sin tener lotes ==
BEGIN;
INSERT INTO responsable_deposito VALUES (803, 31);
SELECT * FROM responsable_deposito WHERE responsable_control_id = 803;
ROLLBACK;

-- == 6.b Actualización: el depósito de 801 se cambia en una sola fila y la vista lo refleja en todos sus lotes ==
BEGIN;
UPDATE responsable_deposito SET deposito_id = 32 WHERE responsable_control_id = 801;
SELECT * FROM vw_control_lote_almacen ORDER BY lote_id;
ROLLBACK;

-- == 6.c Borrado: se elimina el control del lote 503 y se conserva que 802 pertenece al depósito 31 ==
BEGIN;
DELETE FROM control_lote_responsable WHERE lote_id = 503;
SELECT * FROM responsable_deposito WHERE responsable_control_id = 802;
ROLLBACK;

-- == 6.d DF2 garantizada por la PK: 801 no puede figurar en un segundo depósito (se espera ERROR controlado) ==
DO $df2$
BEGIN
    INSERT INTO responsable_deposito VALUES (801, 31);
    RAISE EXCEPTION 'No debería llegar aquí';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Rechazado por la PK de responsable_deposito: %', SQLERRM;
END
$df2$;

-- == 6.e DF1 protegida por disparador: el lote 501 no puede tener otro responsable del depósito 30 (se espera ERROR controlado) ==
DO $df1$
BEGIN
    INSERT INTO responsable_deposito VALUES (804, 30);
    INSERT INTO control_lote_responsable VALUES (501, 804);
    RAISE EXCEPTION 'No debería llegar aquí';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Rechazado: %', SQLERRM;
END
$df1$;
SELECT count(*) AS responsable_804_tras_rechazo FROM responsable_deposito WHERE responsable_control_id = 804;

-- == 6.f Caso válido: el lote 501 se fracciona y también lo controla 802 desde el depósito 31 ==
BEGIN;
INSERT INTO control_lote_responsable VALUES (501, 802);
SELECT * FROM vw_control_lote_almacen WHERE lote_id = 501 ORDER BY deposito_id;
ROLLBACK;

-- == 6.g El responsable 801 no puede pasar al depósito 31 si con eso el lote 501 quedara con dos responsables del depósito 31 ==
BEGIN;
INSERT INTO control_lote_responsable VALUES (501, 802);   -- 501 controlado por 801 (dep. 30) y 802 (dep. 31)
DO $mover$
BEGIN
    UPDATE responsable_deposito SET deposito_id = 31 WHERE responsable_control_id = 801;
    RAISE EXCEPTION 'No debería llegar aquí';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Rechazado: %', SQLERRM;
END
$mover$;
ROLLBACK;

-- == Estado final: original y vista siguen siendo equivalentes ==
SELECT count(*) AS diferencias
FROM ((TABLE control_lote_almacen EXCEPT SELECT lote_id, deposito_id, responsable_control_id FROM vw_control_lote_almacen)
      UNION ALL
      (SELECT lote_id, deposito_id, responsable_control_id FROM vw_control_lote_almacen EXCEPT TABLE control_lote_almacen)) AS d;
