-- Abrir dos consolas independientes con los parametros verificados del protocolo.
-- En AMBAS sesiones, ejecutar estas dos lineas antes de copiar su bloque:
\set ON_ERROR_STOP on
\set laboratorio_id 'LAB_CONC_2026_CAMBIAR'
-- Reemplazar el valor por un identificador unico de esta ejecucion y usar exactamente
-- el mismo valor en ambas sesiones. No reutilizar un marcador de otra practica.
-- Copiar cada bloque en la sesion indicada y respetar el orden. No hay salida fabricada.

-- PREPARACION (Sesion A, una vez; ejecutar y confirmar antes de los escenarios)
BEGIN;
DELETE FROM detalle_pedido
WHERE id_producto IN (
    SELECT p.id_producto
    FROM producto p
    JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE c.descripcion = 'Semilla TP2: ' || :'laboratorio_id'
);
DELETE FROM producto p
USING categoria c
WHERE p.id_categoria = c.id_categoria
  AND c.descripcion = 'Semilla TP2: ' || :'laboratorio_id';
DELETE FROM categoria
WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
INSERT INTO categoria (nombre, descripcion)
VALUES (:'laboratorio_id', 'Semilla TP2: ' || :'laboratorio_id');
INSERT INTO producto (nombre, precio_lista, stock, activo, id_categoria)
SELECT :'laboratorio_id' || '_PRECIO', 10.00, 10, TRUE, id_categoria
FROM categoria
WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
INSERT INTO producto (nombre, precio_lista, stock, activo, id_categoria)
SELECT :'laboratorio_id' || '_BLOQUEO', 15.00, 10, TRUE, id_categoria
FROM categoria
WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
COMMIT;

-- ESCENARIO 1: lectura no repetible en READ COMMITTED.
-- Sesion A
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT precio_lista FROM producto
WHERE nombre = :'laboratorio_id' || '_PRECIO'
  AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
-- Esperar a que Sesion B confirme; luego ejecutar el SELECT siguiente.
SELECT precio_lista FROM producto
WHERE nombre = :'laboratorio_id' || '_PRECIO'
  AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;

-- Sesion B (entre los dos SELECT de Sesion A)
BEGIN;
UPDATE producto SET precio_lista = 20.00
WHERE nombre = :'laboratorio_id' || '_PRECIO'
  AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;

-- ESCENARIO 1B: la misma lectura en REPEATABLE READ.
-- Sesion A
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT precio_lista FROM producto
WHERE nombre = :'laboratorio_id' || '_PRECIO'
  AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
-- Esperar a que Sesion B confirme; luego repetir el SELECT.
SELECT precio_lista FROM producto
WHERE nombre = :'laboratorio_id' || '_PRECIO'
  AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;

-- Sesion B (entre los dos SELECT de Sesion A)
BEGIN;
UPDATE producto SET precio_lista = 30.00
WHERE nombre = :'laboratorio_id' || '_PRECIO'
  AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;

-- ESCENARIO 2: lectura fantasma de productos activos en READ COMMITTED.
-- Sesion A
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT count(*) AS activos FROM producto
WHERE activo AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
-- Esperar el COMMIT de Sesion B y repetir.
SELECT count(*) AS activos FROM producto
WHERE activo AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;

-- Sesion B (entre los dos conteos de Sesion A)
BEGIN;
INSERT INTO producto (nombre, precio_lista, stock, activo, id_categoria)
SELECT :'laboratorio_id' || '_FANTASMA', 5.00, 1, TRUE, id_categoria
FROM categoria
WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
COMMIT;

-- ESCENARIO 2B: lectura fantasma en REPEATABLE READ.
-- Sesion B (limpieza previa)
BEGIN;
DELETE FROM detalle_pedido
WHERE id_producto IN (
    SELECT p.id_producto
    FROM producto p
    JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE p.nombre = :'laboratorio_id' || '_FANTASMA'
      AND c.descripcion = 'Semilla TP2: ' || :'laboratorio_id'
);
DELETE FROM producto p
USING categoria c
WHERE p.id_categoria = c.id_categoria
  AND p.nombre = :'laboratorio_id' || '_FANTASMA'
  AND c.descripcion = 'Semilla TP2: ' || :'laboratorio_id';
COMMIT;

-- Sesion A
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT count(*) AS activos FROM producto
WHERE activo AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
-- Esperar el COMMIT de Sesion B y repetir.
SELECT count(*) AS activos FROM producto
WHERE activo AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;

-- Sesion B (entre los dos conteos de Sesion A)
BEGIN;
INSERT INTO producto (nombre, precio_lista, stock, activo, id_categoria)
SELECT :'laboratorio_id' || '_FANTASMA', 5.00, 1, TRUE, id_categoria
FROM categoria
WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
COMMIT;

-- ESCENARIO 3: espera por bloqueo de fila, limitada a diez segundos.
-- Sesion A
BEGIN;
SET LOCAL lock_timeout = '10s';
SELECT id_producto FROM producto
WHERE nombre = :'laboratorio_id' || '_BLOQUEO'
  AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id')
FOR UPDATE;
-- Mantener abierta la transaccion; ejecutar Sesion B. Confirmar o revertir A para liberarla.
COMMIT;

-- Sesion B (mientras Sesion A conserva el FOR UPDATE)
BEGIN;
SET LOCAL lock_timeout = '10s';
SELECT id_producto FROM producto
WHERE nombre = :'laboratorio_id' || '_BLOQUEO'
  AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id')
FOR UPDATE;
-- Si A libera antes de diez segundos, B puede ejecutar COMMIT.
COMMIT;
-- Si vence el tiempo, PostgreSQL cancela esta sentencia con lock timeout y deja la
-- transaccion de B abortada: ejecutar ROLLBACK (no COMMIT) antes de continuar.

-- LIMPIEZA FINAL (Sesion A, al terminar todas las observaciones)
BEGIN;
DELETE FROM detalle_pedido
WHERE id_producto IN (
    SELECT p.id_producto
    FROM producto p
    JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE c.descripcion = 'Semilla TP2: ' || :'laboratorio_id'
);
DELETE FROM producto p
USING categoria c
WHERE p.id_categoria = c.id_categoria
  AND c.descripcion = 'Semilla TP2: ' || :'laboratorio_id';
DELETE FROM categoria
WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
COMMIT;
