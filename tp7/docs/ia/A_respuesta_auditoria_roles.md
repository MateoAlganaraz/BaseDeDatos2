# Parte A - Respuesta completa de la IA (auditoría de roles.sql)

Texto devuelto por la IA, sin editar.

---

# Auditoría de `roles.sql` (Food Store, PostgreSQL 16)

En general el diseño va bien encaminado:

- Hay un rol dueño `NOLOGIN` separado de los usuarios que se conectan.
- `admin_datos` recibe al dueño con `INHERIT FALSE, SET TRUE` (opciones nuevas de PG16), así que tiene que hacer `SET ROLE` a propósito para cambiar la estructura.
- Se le saca a `PUBLIC` el acceso a la base, a los esquemas y a las funciones.
- `password_hash` queda oculto con permisos por columna.
- Hay borrado lógico en lugar de `DELETE`.
- `app_web` no tiene `TEMP` en la base. Eso protege de que alguien cree una tabla temporal con el mismo nombre que una tabla real para engañar a las funciones `SECURITY DEFINER`.

Igual encontré varios problemas: algunos impiden que soporte y reportes trabajen, y otros dejan más privilegios de los necesarios. Los ordené por gravedad.

---

## 1. Problemas que impiden que el sistema funcione

### 1.1 Soporte, reportes y auditoría no se pueden conectar
`rol_soporte`, `rol_reportes` y `rol_auditor` son `NOLOGIN`, no tienen ningún miembro que pueda iniciar sesión y tampoco tienen `CONNECT` sobre la base (solo lo tienen `app_web` y `admin_datos`). Así como está, nadie puede hacer tareas de soporte, reportes ni auditoría.

```sql
DO $conn$
BEGIN
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO rol_soporte, rol_reportes, rol_auditor',
                   current_database());
END
$conn$;

-- Usuarios con login (la contraseña se define fuera del repo, con \password o ALTER ROLE ... PASSWORD)
CREATE ROLE usr_soporte  LOGIN CONNECTION LIMIT 3 NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS IN ROLE rol_soporte;
CREATE ROLE usr_reportes LOGIN CONNECTION LIMIT 3 NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS IN ROLE rol_reportes;
CREATE ROLE usr_auditor  LOGIN CONNECTION LIMIT 2 NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS IN ROLE rol_auditor;
```
También hay que agregar `usr_soporte`, `usr_reportes` y `usr_auditor` al arreglo del bloque `$limpieza$`. `CONNECT` se hereda por membresía, así que alcanza con dárselo a los roles de grupo.

### 1.2 Funciones usadas en `DEFAULT`, `CHECK`, columnas generadas o triggers
Con `REVOKE EXECUTE ON ALL FUNCTIONS ... FROM PUBLIC`, una función propia que se llame desde un `DEFAULT`, un `CHECK` o una columna generada de `cliente`, `pedido` o `detalle_pedido` se ejecuta con los permisos de `app_web`. Como `app_web` ya no tiene `EXECUTE`, el `INSERT` falla.

Pasa algo parecido con los triggers. Si un trigger sobre `detalle_pedido` escribe en `auditoria_acceso` u otra tabla, corre con los permisos de quien hizo el `INSERT`, y `app_web` no tiene permiso sobre esa tabla. Hay dos salidas: hacer esa función de trigger `SECURITY DEFINER` (con `search_path` fijo) o darle a `app_web` el permiso puntual que le falta.

Con esta consulta revisás qué funciones de `public` puede ejecutar `app_web`:
```sql
SELECT p.oid::regprocedure AS funcion, p.prosecdef AS security_definer,
       has_function_privilege('app_web', p.oid, 'EXECUTE') AS app_web_puede
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public';
```

### 1.3 Procedimientos y secuencias que no son de identidad
- `ALL FUNCTIONS` no incluye procedimientos. Si tenés alguno (`CREATE PROCEDURE`), usá `ROUTINES`:
  ```sql
  REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;
  ```
- Las columnas `IDENTITY` no necesitan permisos sobre su secuencia. Pero el script menciona secuencias que no son de identidad. Si alguna se usa como `DEFAULT nextval(...)` en una tabla donde inserta la app (por ejemplo, un número de pedido), hace falta:
  ```sql
  GRANT USAGE ON SEQUENCE <nombre_secuencia> TO rol_app_escritura;
  ```

---

## 2. Privilegios de más (mínimo privilegio)

### 2.1 `ALTER DEFAULT PRIVILEGES ... GRANT SELECT ON TABLES TO rol_app_lectura`
Es el problema más serio de diseño. Cualquier tabla que se cree en el futuro, por ejemplo una de tokens de recuperación de contraseña, una copia de `usuario` o una de auditoría, va a quedar legible completa para la aplicación web. Esto anula el cuidado que tuviste al ocultar `password_hash` por columna. Los permisos sobre tablas nuevas tienen que darse explícitamente.

**Corrección:** borrar esa sentencia. Dejá solo el `REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` global, que está bien hecho: sin `IN SCHEMA`, como corresponde para revocar un permiso por defecto.

### 2.2 `UPDATE` sobre tablas enteras
`GRANT INSERT, UPDATE ON cliente, pedido, detalle_pedido` permite que la app cambie cualquier columna: el `id_cliente` de un pedido, totales, precios unitarios, fechas o `deleted_at` en cualquier sentido. Conviene limitar el `UPDATE` a las columnas que la app realmente modifica. Los nombres de abajo son de ejemplo y hay que ajustarlos a tu modelo:

```sql
GRANT INSERT ON cliente, pedido, detalle_pedido TO rol_app_escritura;
GRANT UPDATE (nombre, apellido, email, telefono, direccion, deleted_at) ON cliente        TO rol_app_escritura;
GRANT UPDATE (estado, deleted_at)                                       ON pedido         TO rol_app_escritura;
GRANT UPDATE (cantidad, deleted_at)                                     ON detalle_pedido TO rol_app_escritura;
```
Un `UPDATE ... WHERE id = ...` también necesita `SELECT` sobre las columnas del `WHERE`. Hoy funciona porque `app_web` tiene los dos roles. Para que `rol_app_escritura` no dependa de eso, podés hacer:
```sql
GRANT rol_app_lectura TO rol_app_escritura;
```

### 2.3 `UPDATE (stock)` deja poner cualquier valor
Con ese permiso, la app (o alguien que explote una inyección SQL) puede subir el stock, ponerlo negativo, o generar una condición de carrera si primero lee el stock y después lo escribe. Es mejor descontarlo con una función que valide y lo haga en una sola operación:

```sql
ALTER TABLE producto ADD CONSTRAINT ck_producto_stock_no_negativo CHECK (stock >= 0);

CREATE OR REPLACE FUNCTION fn_descontar_stock(p_id_producto bigint, p_cantidad integer)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_stock integer;
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'Cantidad inválida: %', p_cantidad;
    END IF;

    UPDATE public.producto
       SET stock = stock - p_cantidad
     WHERE id_producto = p_id_producto
       AND stock >= p_cantidad
    RETURNING stock INTO v_stock;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock insuficiente o producto inexistente (id %)', p_id_producto;
    END IF;
    RETURN v_stock;
END
$$;

ALTER FUNCTION fn_descontar_stock(bigint, integer) OWNER TO food_store_owner;
REVOKE EXECUTE ON FUNCTION fn_descontar_stock(bigint, integer) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_descontar_stock(bigint, integer) TO rol_app_escritura;
-- y eliminar: GRANT UPDATE (stock) ON producto TO rol_app_escritura;
```
Si hoy descontás el stock con un trigger en `detalle_pedido`, mantené `UPDATE (stock)` o hacé ese trigger `SECURITY DEFINER`. Si no, el `INSERT` del detalle va a fallar.

### 2.4 `fn_resetear_password(bigint, text)`
- Si `log_statement` o `log_min_duration_statement` están activos, la contraseña nueva en texto plano queda en el log del servidor. Es mejor que la función genere una contraseña temporal y la devuelva, o que obligue a cambiarla en el próximo login.
- Dentro de la función conviene impedir que se resetee la contraseña de un usuario con rol administrador.
- Registrá cada reseteo en `auditoria_acceso` usando `session_user`, no `current_user`. Dentro de una función `SECURITY DEFINER`, `current_user` vale `food_store_owner`.

---

## 3. Endurecer las funciones `SECURITY DEFINER`

`fn_autenticar` y `fn_resetear_password` tienen que tener un `search_path` fijo. Si no lo tienen, el `search_path` lo define quien las llama:

```sql
ALTER FUNCTION fn_autenticar(text, text)          SET search_path = public, extensiones, pg_temp;
ALTER FUNCTION fn_resetear_password(bigint, text) SET search_path = public, extensiones, pg_temp;

-- Explícito, por si alguna se recrea después del REVOKE masivo:
REVOKE EXECUTE ON FUNCTION fn_autenticar(text, text)          FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_resetear_password(bigint, text) FROM PUBLIC;
```
`pg_temp` tiene que ir al final de la lista. Lo ideal es además calificar con el esquema dentro del cuerpo (`public.usuario`, `extensiones.crypt(...)`).

Un detalle de diseño: autenticarse no es "escribir". Podrías crear un `rol_app_auth` solo con `EXECUTE` sobre `fn_autenticar` y dárselo a `app_web`.

---

## 4. Que soporte y reportes puedan hacer su trabajo

**Soporte.** Puede ver y desactivar usuarios, pero no desbloquear a uno bloqueado por intentos fallidos, que es la tarea más común. Lo prolijo es hacerlo con una función:
```sql
-- Opción simple:
GRANT UPDATE (intentos_fallidos, bloqueado_hasta) ON usuario TO rol_soporte;
-- Opción mejor: una función fn_desbloquear_usuario(bigint) SECURITY DEFINER que además audite.
```
Si el enunciado pide que soporte consulte los pedidos de un cliente, dale `SELECT` sobre `pedido` y `detalle_pedido`, y sobre `cliente` solo las columnas necesarias.

**Reportes.** Hoy ve también las filas borradas lógicamente, así que los números pueden salir mal. Es mejor exponer vistas que ya filtren las borradas y dar permiso sobre la vista, no sobre las tablas base:
```sql
CREATE VIEW vw_ventas AS
SELECT p.id_pedido, p.fecha, dp.id_producto, pr.nombre AS producto, c.nombre AS categoria,
       dp.cantidad, dp.precio_unitario
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido AND dp.deleted_at IS NULL
JOIN producto pr       ON pr.id_producto = dp.id_producto
JOIN categoria c       ON c.id_categoria = pr.id_categoria;

ALTER VIEW vw_ventas OWNER TO food_store_owner;
REVOKE SELECT ON categoria, producto, pedido, detalle_pedido FROM rol_reportes;
GRANT  SELECT ON vw_ventas TO rol_reportes;
```
Ajustá las columnas y agregá el filtro de borrado en `pedido` si esa tabla también tiene `deleted_at`. La vista se ejecuta con los permisos de su dueño, por eso alcanza con el `GRANT` sobre la vista.

---

## 5. Configuración por rol

Los `ALTER ROLE ... SET` **no se heredan** de los roles de grupo. Hay que definirlos en los roles que inician sesión:
```sql
ALTER ROLE app_web      SET search_path = public, pg_temp;
ALTER ROLE app_web      SET statement_timeout = '10s';
ALTER ROLE app_web      SET idle_in_transaction_session_timeout = '30s';
ALTER ROLE usr_reportes SET default_transaction_read_only = on;
ALTER ROLE usr_reportes SET statement_timeout = '120s';
ALTER ROLE admin_datos  VALID UNTIL '2027-03-31';
```
Además: `password_encryption = 'scram-sha-256'`, `hostssl` en `pg_hba.conf`, y ninguna contraseña dentro de `roles.sql`.

---

## 6. Detalles menores

- **Bloque de limpieza:** `REASSIGN OWNED` y `DROP OWNED` solo actúan en la base actual. Si alguno de esos roles tiene objetos o permisos en otra base, `DROP ROLE` falla. Para un TP alcanza con dejarlo comentado en el script.
- **Seguridad por filas (RLS):** `rol_app_lectura` puede leer todos los clientes y pedidos. Si querés ir más allá, podés activar RLS sobre `pedido` filtrando por `current_setting('app.id_cliente')`.

---

## 7. Pruebas para verificar

```sql
SET ROLE app_web;
SELECT password_hash FROM usuario;                 -- debe FALLAR
SELECT id_usuario, email FROM usuario LIMIT 1;     -- debe funcionar
INSERT INTO cliente (nombre, apellido, email) VALUES ('Test', 'Test', 't@t.com') RETURNING id_cliente;  -- debe funcionar
SELECT fn_descontar_stock(1, 1);                   -- debe funcionar (o fallar por stock insuficiente)
UPDATE producto SET stock = 9999 WHERE id_producto = 1;  -- debe FALLAR
DELETE FROM pedido WHERE id_pedido = 1;            -- debe FALLAR
SELECT * FROM auditoria_acceso;                    -- debe FALLAR
RESET ROLE;

SET ROLE usr_reportes;
SELECT count(*) FROM vw_ventas;                    -- debe funcionar
SELECT * FROM cliente;                             -- debe FALLAR
RESET ROLE;
```

Antes de cerrar volví a revisar el pedido: que la app pueda registrar clientes, pedidos y detalles, descontar stock y autenticar, y que soporte y reportes puedan trabajar. Cada corrección de arriba apunta a alguno de esos puntos. Los nombres de columnas (`estado`, `direccion`, `precio_unitario`, `id_categoria`) los supuse; ajustalos a tu esquema.

result: La auditoría de roles.sql encontró que soporte, reportes y auditoría no se pueden conectar y que los permisos por defecto exponen las tablas futuras; incluye las correcciones en SQL (funciones con search_path fijo, UPDATE por columnas, descuento de stock con función, vistas para reportes) y pruebas para verificarlas.