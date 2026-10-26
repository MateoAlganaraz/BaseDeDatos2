# Parte C - Informe del simulacro de incidente de acceso indebido

Todo se ejecutó contra la base de laboratorio propia (`food_store_tp7_lab`, servidor PostgreSQL 16.15 en `localhost`). Ninguna parte del simulacro apunta a sistemas de terceros.

## 1. Escenario y script

Script: [`sql/simulacro_incidente.sql`](../sql/simulacro_incidente.sql), lanzado con `scripts/run_tp7.sh C` como `app_web` por TCP (`application_name=sqlcli`, distinto del `foodstore_web` de la tienda). Representa a un atacante que obtuvo la cadena de conexión de la aplicación y la usa por fuera de ella.

| Paso | Qué ejecuta | Resultado real ([`evidencia/C_salida_simulacro.txt`](../evidencia/C_salida_simulacro.txt)) |
|---|---|---|
| 1 | 4 × `fn_autenticar('tomas.morales.17@correo.test', <clave>)` con `123456`, `foodstore`, `Mendoza2026`, `FoodStore2025!` | `f`, `f`, `f`, `f` |
| 2 | `fn_autenticar(..., 'FoodStore2026!')` | `t`: la cuenta 17 (OPERADOR) tenía una contraseña débil |
| 3 | `SELECT * FROM usuario` y luego `SELECT id_usuario, nombre, apellido, email, rol, activo FROM usuario` | El primero falla (`permission denied for table usuario`, por `password_hash`). El segundo **devuelve las 2.000 filas** (`count(*) = 2000`) |
| 4 | `GRANT admin_datos TO rol_reportes`, `GRANT admin_datos TO app_web`, `SET ROLE admin_datos`, `fn_resetear_password(1, ...)`, `DELETE FROM auditoria_acceso` | Los cinco fallan con `permission denied` |

## 2. ¿El escalamiento falló?

**Sí.** Se verificó desde una sesión de administrador, no solo por los mensajes de error ([`sql/simulacro_verificacion.sql`](../sql/simulacro_verificacion.sql) → [`evidencia/C_verificacion_escalamiento.txt`](../evidencia/C_verificacion_escalamiento.txt)):

- `admin_datos` no tiene miembros, y `app_web` y `rol_reportes` conservan exactamente las membresías de `roles.sql`.
- No hay ningún evento `RESET_PASSWORD` para la cuenta 1.
- `auditoria_acceso` conserva los 5 eventos del simulacro (4 `LOGIN_FALLIDO` y 1 `LOGIN_OK`, `rol_db = app_web`, `ip_origen = 127.0.0.1`, `aplicacion = sqlcli`), así que el intento de borrarla no tuvo efecto.

El diseño de la Parte A **no** tiene un defecto de escalamiento. Sí aparecieron dos **hallazgos** que el simulacro dejó en evidencia, aunque no son escalamientos:

1. **Exposición masiva por un permiso de columna legítimo.** `rol_app_lectura` puede leer `nombre`, `apellido` y `email` de *todos* los usuarios (requisito R2.2). El permiso de columna protegió el hash, pero no evitó que se llevaran 2.000 emails.
2. **El bloqueo llega tarde.** `fn_autenticar` bloquea recién al quinto fallo consecutivo, así que cuatro intentos más el acierto entran justo. Además no hay retardo entre intentos: los cinco ocurrieron en 20 ms.

## 3. Log anonimizado

- Original (datos sintéticos de laboratorio; en un caso real no se versionaría): [`evidencia/C_log_simulacro_original.txt`](../evidencia/C_log_simulacro_original.txt).
- Anonimizado con [`scripts/anonimizar_log.py`](../scripts/anonimizar_log.py): [`log_simulacro_anonimizado.txt`](log_simulacro_anonimizado.txt). Los emails pasan a `usuario_N@ejemplo.invalid`, las contraseñas a `[CLAVE_REDACTADA]` y las IP a `ip_origen_N`. Los nombres de personas y el usuario del sistema del DBA también se reemplazan. Se conservan la hora, el PID, los roles del motor, las sentencias y los errores.
- Comprobación: el archivo anonimizado no contiene ninguna ocurrencia de `correo.test`, `Tomás`, `FoodStore2026` ni `127.0.0.1`.

## 4. Lo que se le entregó a la IA

[Prompt](ia/C_prompt_reconstruccion.md): solo la instrucción de la consigna ("reconstruí qué ocurrió y proponé una hipótesis de contención") y el log anonimizado, sin contexto sobre Food Store ni sobre el simulacro. Se usó una instancia separada de Claude, sin acceso al repositorio. [Respuesta completa](ia/C_respuesta_reconstruccion.md).

## 5. Contraste: reconstrucción de la IA vs. lo ejecutado

**Lo que acertó** (verificable contra el script y la evidencia):

| Afirmación de la IA | Verificación |
|---|---|
| Una sola sesión (PID 848) de `app_web`, SCRAM y TLS 1.3, desde una herramienta de línea de comandos y no desde la aplicación. | Correcto: `application_name=sqlcli`. |
| La primera consulta es reconocimiento de identidad. | Correcto: `current_user`, `inet_client_addr()`, `application_name`. |
| Cinco llamadas automatizadas a `fn_autenticar` sobre la cuenta 17: cuatro fallos y un acierto, sin bloqueo intermedio. | Correcto (el script las ejecuta seguidas). |
| `SELECT *` rechazado probablemente por permisos de columna que excluyen el hash. | Correcto: `password_hash` no está en el `GRANT` de `rol_app_lectura`. |
| La lectura parcial de `usuario` fue lo más grave. | Correcto, y coincide con el hallazgo 1. |
| Los cuatro intentos de escalar y el borrado de la auditoría fallaron, por las causas indicadas. | Correcto. |
| Recomendaciones: rotar `app_web`, restringir `pg_hba.conf`, endurecer el bloqueo, revisar el acceso de `app_web` a `usuario`, preservar evidencia. | Pertinentes. |

**Afirmaciones que el log no sustenta:**

1. **"El objetivo era el usuario con id 1, probablemente un administrador."** El log solo muestra `fn_resetear_password(1, ...)`: no dice nada del rol de esa cuenta. En la base, el usuario 1 es `OPERADOR`, no administrador. Es una causa asumida sin evidencia.
2. **"El bloqueo no se aplica dentro de la misma sesión"**, propuesta como una de dos explicaciones. El log no permite distinguirlas. La correcta es la otra: el umbral es 5 (`00_base_usuarios.sql`) y el acierto llegó en el quinto intento.
3. **"Se leyeron datos personales de todos los usuarios"** como hecho. El log muestra que la sentencia no dio error, pero no registra cuántas filas devolvió. Que fueron 2.000 lo sabemos por la salida del cliente, no por el log (ver Parte B: el log nativo no registra resultados).

**Lo que omitió o no podía saber:**

1. **El origen era el propio servidor.** La anonimización convirtió `127.0.0.1` en `ip_origen_1`, y la IA propuso bloquear esa IP en el firewall. Sobre el log real esa medida no sirve: quien usó la credencial lo hizo desde la máquina de la base, lo que apunta a un acceso al host y obliga a investigar quién tenía shell ahí. **Lección:** al anonimizar, conviene conservar la *categoría* del dato (`ip_loopback`, `ip_red_interna`, `ip_externa`) en lugar de borrarla del todo.
2. **El nombre de la base filtró contexto.** La "hipótesis alternativa" de que fuera un script del TP salió del nombre `food_store_tp7_lab`, que el anonimizador no reemplazó. Acertó, pero por una pista que no debía estar.
3. **No mencionó el impacto de rotar `app_web` en la tienda.** Cambiar la contraseña sin desplegar la nueva en la aplicación deja la tienda sin base de datos.
4. **No marcó la posible obligación legal.** Se expusieron nombres y emails de 2.000 personas: según la Ley 25.326 de Protección de Datos Personales, hay que evaluar el incidente y notificar a la AAIP y a los afectados.
5. **No señaló que el log original contiene las contraseñas probadas en claro** (ver Parte B, punto 4). Para la IA era invisible por la redacción, pero define quién puede ver el log original durante la investigación.

**Fechas y horas:** la IA usó bien la hora local del log (`09:42`, `-03`). Durante la verificación se detectó un riesgo propio de confusión: `auditoria_acceso.fecha`, consultada desde una sesión en UTC, mostraba `12:42`. Se fijó `TimeZone` en la consulta de verificación para que ambos registros se comparen en la misma zona.

## 6. Decisión de contención del equipo

La decisión se toma a partir de la evidencia sin anonimizar (log original, `auditoria_acceso` y verificación de roles). La reconstrucción de la IA sirvió para ordenar hipótesis, no para decidir. Nada de lo siguiente se ejecuta automáticamente.

**Contener (inmediato):**
1. Terminar las sesiones de `app_web` que no sean de la aplicación: `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'app_web' AND application_name <> 'foodstore_web';`.
2. Rotar la contraseña de `app_web` **coordinada con el despliegue de la aplicación** (secreto nuevo en el gestor de secretos y reinicio controlado), para no tirar la tienda.
3. Restringir en `pg_hba.conf` a `app_web` solo desde las IP de los servidores de aplicación. Como el origen real fue `127.0.0.1`, se escala además la revisión de accesos al host de la base (usuarios con shell, `sudo`, claves SSH).

**Proteger a los afectados:**
4. Cuenta 17: resetear la contraseña con `fn_resetear_password` (lo hace soporte, queda registrado), invalidar sesiones de la aplicación y avisar al usuario.
5. Exposición de 2.000 emails y nombres: abrir el registro del incidente, evaluar la notificación a la AAIP y a los afectados, y advertir sobre posibles correos de phishing.

**Corregir el diseño** (cambios propuestos para `roles.sql` y `fn_autenticar`, a aplicar después de revisarlos y probarlos como en la Parte A):
6. Reemplazar el `SELECT` por columnas de `rol_app_lectura` sobre `usuario` por una función `SECURITY DEFINER` que devuelva solo el perfil del usuario autenticado, o por RLS. Es el permiso que permitió la lectura masiva.
7. Bajar el umbral de bloqueo a 3, agregar retardo progresivo y alertar cuando haya varios `LOGIN_FALLIDO` del mismo origen en `auditoria_acceso`.
8. Reemplazar `log_statement = 'all'` de `app_web` por pgaudit de objeto sobre `usuario`, para que las contraseñas no lleguen al log.

**Lo que no se hace:** no se revoca ningún rol ni se "revierte" ninguna membresía. La verificación del punto 2 muestra que el escalamiento no cambió nada, y tocar roles sin evidencia solo agregaría riesgo.
