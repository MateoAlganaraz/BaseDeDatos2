# Parte B - Informe de auditoría

Servidor de desarrollo: PostgreSQL 16.15 (Ubuntu), clúster `16/main`, base `food_store_tp7_lab`. El log del servidor va por `stderr` al archivo `/var/log/postgresql/postgresql-16-main.log` (`logging_collector = off`, gestionado por el empaquetado de Debian/Ubuntu).

## 1. Parámetros modificados

Script: [`sql/configuracion_auditoria.sql`](../sql/configuracion_auditoria.sql). Se aplicó con `ALTER SYSTEM` (queda en `postgresql.auto.conf`) y `pg_reload_conf()`; ninguno requiere reinicio. Valores antes y después, tal como los devolvió `pg_settings` ([`evidencia/B_configuracion_auditoria.txt`](../evidencia/B_configuracion_auditoria.txt)):

| Parámetro | Antes | Después | Para qué |
|---|---|---|---|
| `log_connections` | `off` | `on` | Registra cada intento de conexión: origen, rol, base, método de autenticación y si usó SSL. |
| `log_disconnections` | `off` | `on` | Registra el fin de cada sesión con su duración. |
| `log_statement` | `none` | `mod` | Registra DDL e `INSERT`/`UPDATE`/`DELETE`/`TRUNCATE` de todos los roles. |
| `log_line_prefix` | `%m [%p] %q%u@%d ` | `%m [%p] %q%u@%d %h app=%a ` | Agrega **desde dónde** (`%h`, host de origen) y **con qué aplicación** (`%a`) a cada línea. |
| `log_min_error_statement` | `error` | `error` (explícito) | Toda sentencia que falla se registra completa, aunque `log_statement` no la cubra (por ejemplo, un `SELECT` denegado). |
| `log_timezone` | `Etc/UTC` | `America/Argentina/Buenos_Aires` | Las horas del log coinciden con la hora local de Food Store. |
| `log_statement` **del rol `app_web`** | (global) | `all` (`ALTER ROLE app_web SET log_statement = 'all'`) | La cuenta de la aplicación es la credencial más expuesta: en desarrollo se registran también sus lecturas. Es lo que permite ver la lectura masiva de la Parte C. |

Reversión (como superusuario):

```sql
ALTER SYSTEM RESET log_connections;  ALTER SYSTEM RESET log_disconnections;
ALTER SYSTEM RESET log_statement;    ALTER SYSTEM RESET log_line_prefix;
ALTER SYSTEM RESET log_min_error_statement;  ALTER SYSTEM RESET log_timezone;
ALTER ROLE app_web RESET log_statement;
SELECT pg_reload_conf();
```

## 2. Secuencia de prueba y fragmento de log

Script: [`sql/auditoria_test.sql`](../sql/auditoria_test.sql), ejecutado con `scripts/run_tp7.sh B` por conexiones TCP reales a `127.0.0.1`. Contiene una lectura, una inserción (pedido + detalle), una actualización (stock), una autenticación fallida de la aplicación (`fn_autenticar`), una operación privilegiada de `admin_datos` con `SET ROLE` y un inicio de sesión fallido contra el motor. Fragmento capturado: [`log_auditoria_prueba.txt`](log_auditoria_prueba.txt) (40 líneas). Salida del cliente: [`evidencia/B_salida_auditoria_test.txt`](../evidencia/B_salida_auditoria_test.txt).

## 3. Qué aporta el fragmento y qué queda fuera

**Información útil para auditoría**, señalada sobre líneas reales del fragmento:

| Pregunta | Dónde está | Ejemplo del fragmento |
|---|---|---|
| **Cuándo** | `%m`, al milisegundo, en hora local | `2026-10-26 09:41:02.179 -03` |
| **Quién** | `%u` (rol del motor) y la línea `connection authenticated: identity="app_web" method=scram-sha-256` | `app_web@food_store_tp7_lab`, `admin_datos@food_store_tp7_lab` |
| **Desde dónde** | `%h` y `connection received: host=127.0.0.1 port=36682` | `127.0.0.1` |
| **Con qué** | `%a` y `connection authorized: ... application_name=foodstore_web SSL enabled (protocol=TLSv1.3 ...)` | `foodstore_web`, `psql_admin` |
| **Qué** | `LOG: statement:` con el texto completo | el `WITH nuevo AS (INSERT INTO pedido ...)` y el `UPDATE producto SET stock = stock - 2` |
| **Qué falló** | `ERROR` + `STATEMENT`, `FATAL` + `DETAIL` | `permission denied for schema public` de `admin_datos` sin `SET ROLE`; `password authentication failed for user "app_web"` con la regla de `pg_hba.conf` que se aplicó |
| **Sesión** | `[PID]` y `disconnection: session time` | permite agrupar todas las líneas de una misma sesión (`[688]`, `[689]`) |

**Lo que este mecanismo nativo no registra** (y que en la Parte C hay que tener presente):

- **Qué filas se leyeron o cambiaron.** El log guarda el texto de la sentencia, no su resultado: no dice qué pedido se creó, cuál era el stock anterior ni cuántas filas devolvió un `SELECT`. pgaudit tampoco guarda valores de filas; para eso se necesitan triggers de auditoría o una tabla de historial como `auditoria_acceso`.
- **Lo que pasa dentro de una función.** `fn_autenticar` actualiza `usuario` e inserta en `auditoria_acceso`, pero el log solo muestra `SELECT fn_autenticar(...)`. Esos cambios quedan registrados en `auditoria_acceso` porque la función los escribe, no por el log. Esa tabla es el registro con vocación de **rendición de cuentas**: guarda el evento de negocio (`LOGIN_FALLIDO`, `id_usuario`, `rol_db`, `ip_origen`). El log del servidor es un registro **técnico**.
- **La identidad efectiva tras `SET ROLE`.** `%u` muestra el rol de sesión. El `COMMENT ON TABLE` se ejecutó como `food_store_owner`, pero el log lo atribuye a `admin_datos`, y el `SET ROLE` mismo no aparece, porque `mod` no registra `SET`.
- **Lecturas de los demás roles.** Con `mod`, un `SELECT` de soporte o reportes no deja rastro. Solo se ven las lecturas de `app_web`, gracias a la configuración por rol.
- **Granularidad por objeto.** pgaudit permitiría, en nociones: auditoría *de sesión* por clases (`pgaudit.log = 'read, write, role, ddl'`), que incluye `GRANT`/`SET ROLE`; auditoría *de objeto* (`pgaudit.role`), que registra solo los accesos a tablas elegidas como `usuario`, aunque ocurran dentro de funciones; y una línea `AUDIT:` estructurada con clase, comando y objeto, con el texto de la sentencia una sola vez. Reemplazaría el `log_statement = 'all'` de `app_web`, que es costoso y ruidoso.

## 4. ¿El archivo de log es un activo sensible?

Sí. El fragmento contiene emails y la contraseña tal cual se probó: `SELECT fn_autenticar('nadie.tp7audit@correo.test', 'TP7-AUDIT-clave-erronea')` aparece dos veces, en `statement:` y repetida en el `STATEMENT:` que acompaña al `RAISE LOG`. Además revela roles, tablas, reglas de `pg_hba.conf` y horarios de uso, así que tiene que tratarse como dato personal y como secreto. Solo debería poder leerlo la cuenta del servicio (`postgres`) y un grupo de auditoría reducido. En este servidor el archivo es `-rw-r----- postgres:adm` y el clúster usa `log_file_mode = 0600` ([`evidencia/B_permisos_archivo_log.txt`](../evidencia/B_permisos_archivo_log.txt)): conviene que el grupo `adm` (hoy solo con el usuario `ubuntu`) quede limitado a quien audita, con rotación y retención definidas. Dentro del motor, solo los superusuarios o miembros de `pg_read_server_files` pueden leerlo con `pg_read_file`; esa membresía no se le otorga a ningún rol de Food Store, y antes de compartir un fragmento —incluso con una IA— se anonimiza (Parte C).
