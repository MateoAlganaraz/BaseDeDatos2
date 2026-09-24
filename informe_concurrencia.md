# Informe de concurrencia

Base de trabajo: `food_store_tp2`. Script de apoyo: `sql/03_laboratorio_concurrencia.sql`. Antes de abrir los escenarios, verificar la conexion conforme a `protocolo_seguridad.md` y definir el mismo marcador unico en ambas sesiones. Reemplazar `LAB_CONC_2026_CAMBIAR` por un valor unico antes de ejecutar.

```sql
\set ON_ERROR_STOP on
\set laboratorio_id 'LAB_CONC_2026_CAMBIAR'
```

## Preparacion (sesion A)

```sql
BEGIN;
DELETE FROM detalle_pedido WHERE id_producto IN (SELECT p.id_producto FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria WHERE c.descripcion = 'Semilla TP2: ' || :'laboratorio_id');
DELETE FROM producto p USING categoria c WHERE p.id_categoria = c.id_categoria AND c.descripcion = 'Semilla TP2: ' || :'laboratorio_id';
DELETE FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
INSERT INTO categoria (nombre, descripcion) VALUES (:'laboratorio_id', 'Semilla TP2: ' || :'laboratorio_id');
INSERT INTO producto (nombre, precio_lista, stock, activo, id_categoria) SELECT :'laboratorio_id' || '_PRECIO', 10.00, 10, TRUE, id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
INSERT INTO producto (nombre, precio_lista, stock, activo, id_categoria) SELECT :'laboratorio_id' || '_BLOQUEO', 15.00, 10, TRUE, id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
COMMIT;
```

## 1. Lectura no repetible

**Objetivo.** Comparar dos lecturas de `producto.precio_lista` dentro de una transaccion mientras otra sesion actualiza la fila.

**Orden de comandos.** Ejecutar primero en A el primer bloque y detenerse despues de su primer `SELECT`. Ejecutar B completo. Luego ejecutar en A las dos sentencias restantes. Repetir el mismo orden para `REPEATABLE READ`.

Sesion A, `READ COMMITTED`:

```sql
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT precio_lista FROM producto WHERE nombre = :'laboratorio_id' || '_PRECIO' AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
SELECT precio_lista FROM producto WHERE nombre = :'laboratorio_id' || '_PRECIO' AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;
```

Sesion B, entre los `SELECT` de A:

```sql
BEGIN;
UPDATE producto SET precio_lista = 20.00 WHERE nombre = :'laboratorio_id' || '_PRECIO' AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;
```

Sesion A, `REPEATABLE READ`:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT precio_lista FROM producto WHERE nombre = :'laboratorio_id' || '_PRECIO' AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
SELECT precio_lista FROM producto WHERE nombre = :'laboratorio_id' || '_PRECIO' AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;
```

Sesion B, entre los `SELECT` de A:

```sql
BEGIN;
UPDATE producto SET precio_lista = 30.00 WHERE nombre = :'laboratorio_id' || '_PRECIO' AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;
```

**Resultado esperado segun PostgreSQL.** En `READ COMMITTED`, cada sentencia ve una instantanea nueva y el segundo valor puede ser `20.00`. En `REPEATABLE READ`, ambas lecturas de A pertenecen a la instantanea inicial y deben conservar el mismo valor, aunque B confirme `30.00`.

**Observación real del motor.** PostgreSQL 18.4 en `food_store_tpi_verificacion_final`: `READ COMMITTED` leyó `10.00` y luego `20.00`; `REPEATABLE READ` leyó `10.00` en ambas consultas mientras B confirmó `30.00`. Salida completa: `tpi/evidencia/20260923_214500/06_concurrencia.txt`.

## 2. Lectura fantasma

**Objetivo.** Contar productos activos de la categoria de laboratorio mientras otra sesion inserta un nuevo producto activo.

Sesion A, `READ COMMITTED`:

```sql
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT count(*) AS activos FROM producto WHERE activo AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
SELECT count(*) AS activos FROM producto WHERE activo AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;
```

Sesion B, entre los conteos de A:

```sql
BEGIN;
INSERT INTO producto (nombre, precio_lista, stock, activo, id_categoria) SELECT :'laboratorio_id' || '_FANTASMA', 5.00, 1, TRUE, id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
COMMIT;
```

Antes de repetir con `REPEATABLE READ`, sesion B ejecuta la limpieza exacta:

```sql
BEGIN;
DELETE FROM detalle_pedido WHERE id_producto IN (SELECT p.id_producto FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria WHERE p.nombre = :'laboratorio_id' || '_FANTASMA' AND c.descripcion = 'Semilla TP2: ' || :'laboratorio_id');
DELETE FROM producto p USING categoria c WHERE p.id_categoria = c.id_categoria AND p.nombre = :'laboratorio_id' || '_FANTASMA' AND c.descripcion = 'Semilla TP2: ' || :'laboratorio_id';
COMMIT;
```

Sesion A, `REPEATABLE READ`:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT count(*) AS activos FROM producto WHERE activo AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
SELECT count(*) AS activos FROM producto WHERE activo AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id');
COMMIT;
```

Sesion B, entre los conteos de A:

```sql
BEGIN;
INSERT INTO producto (nombre, precio_lista, stock, activo, id_categoria) SELECT :'laboratorio_id' || '_FANTASMA', 5.00, 1, TRUE, id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
COMMIT;
```

**Resultado esperado segun PostgreSQL.** En `READ COMMITTED`, el segundo conteo puede aumentar en uno. En `REPEATABLE READ`, el segundo conteo debe ser igual al primero porque A conserva su instantanea inicial; la fila insertada por B no es visible para esa transaccion.

**Observación real del motor.** En `READ COMMITTED`, el conteo pasó de `2` a `3` después del COMMIT de B. En `REPEATABLE READ`, permaneció en `2` aunque B insertó una fila. Salida completa: `tpi/evidencia/20260923_214500/06_concurrencia.txt`.

## 3. Espera por bloqueo

**Objetivo.** Evidenciar una espera de bloqueo de fila limitada a diez segundos.

Sesion A, conservar la transaccion abierta despues del `SELECT` mientras se ejecuta B:

```sql
BEGIN;
SET LOCAL lock_timeout = '10s';
SELECT id_producto FROM producto WHERE nombre = :'laboratorio_id' || '_BLOQUEO' AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id') FOR UPDATE;
COMMIT;
```

Sesion B, mientras A conserva el bloqueo:

```sql
BEGIN;
SET LOCAL lock_timeout = '10s';
SELECT id_producto FROM producto WHERE nombre = :'laboratorio_id' || '_BLOQUEO' AND id_categoria = (SELECT id_categoria FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id') FOR UPDATE;
COMMIT;
```

**Resultado esperado segun PostgreSQL.** Si A libera la fila mediante `COMMIT` o `ROLLBACK` antes de diez segundos, B puede terminar el `SELECT` y confirmar. Si A no la libera, B recibe un error de `lock timeout`; este es un resultado de seguridad controlado. PostgreSQL cancela la sentencia y la transaccion de B queda abortada, por lo que B debe ejecutar `ROLLBACK;` antes de continuar.

**Observación real del motor.** B inició a las `20:30:49.634868-03` y adquirió el bloqueo a las `20:30:52.401280-03`, en el mismo instante de la liberación de A (`20:30:52.401283-03`). La espera quedó dentro del límite de cinco segundos. Salida completa: `tpi/evidencia/20260923_214500/06_concurrencia.txt`.

## Limpieza final (sesion A)

```sql
BEGIN;
DELETE FROM detalle_pedido WHERE id_producto IN (SELECT p.id_producto FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria WHERE c.descripcion = 'Semilla TP2: ' || :'laboratorio_id');
DELETE FROM producto p USING categoria c WHERE p.id_categoria = c.id_categoria AND c.descripcion = 'Semilla TP2: ' || :'laboratorio_id';
DELETE FROM categoria WHERE descripcion = 'Semilla TP2: ' || :'laboratorio_id';
COMMIT;
```

## Checklist de evidencia real

- [x] Usar el mismo `laboratorio_id` único en ambas sesiones.
- [x] Ejecutar preparación y limpieza final en la base aislada `food_store_tpi_verificacion_final`.
- [x] Abrir dos sesiones `psql` independientes mediante el ejecutor reproducible `tpi/04_ejecutar_concurrencia.ps1`.
- [x] Guardar salidas reales, versión de PostgreSQL y niveles de aislamiento usados.
- [x] Diferenciar las expectativas de los resultados observados.
