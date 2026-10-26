# Parte C - Respuesta completa de la IA (reconstrucción del incidente)

Texto devuelto por la IA, sin editar. El contraste con lo ejecutado está en `docs/informe_incidente.md`.

---

Reconstruyo el incidente en orden y cierro con la hipótesis de contención y las medidas que propongo.

## Qué ocurrió

**1. Conexión (09:42:57.197–.206)**
- Se abre una única sesión (PID 848) desde `ip_origen_1` con el usuario de base de datos `app_web`. Se autentica con SCRAM-SHA-256 por la regla de la línea 125 de `pg_hba.conf` y la conexión va cifrada con TLS 1.3.
- El cliente se presenta como `application_name=sqlcli`, o sea, una herramienta de línea de comandos y no la aplicación.
- Lo primero que hace es comprobar su contexto: `current_user`, IP de origen y `application_name`. Eso es típico de alguien que quiere confirmar con qué identidad entró.

**2. Intentos de login de la aplicación sobre `id_usuario=17`**
- Llama 5 veces seguidas a `fn_autenticar` con el mismo email, con unos 3–4 ms entre llamadas. A esa velocidad no escribe una persona: es un script.
- Los intentos 1 a 4 fallan y el contador sube de 1 a 4. El quinto devuelve "inicio de sesion correcto".
- Como las claves están redactadas, no sé si fue una prueba de varias contraseñas o una contraseña conocida enviada después de errores a propósito. En cualquier caso, la cuenta no se bloqueó antes del acierto. Eso indica una de dos cosas: el umbral de bloqueo es mayor que 4, o el bloqueo no se aplica dentro de la misma sesión.
- Ese login exitoso no cambia los privilegios de la sesión: sigue siendo `app_web`.

**3. Reconocimiento y lectura de datos**
- `SELECT * FROM usuario` es rechazado. Lo más probable es que haya permisos por columna y que la columna del hash de la contraseña esté excluida.
- `SELECT id_usuario, nombre, apellido, email, rol, activo` **funciona**. Esto es lo más grave del log: se leyeron datos personales de todos los usuarios.
- `SELECT count(*)` también funciona.

**4. Intentos de escalar privilegios, todos fallidos**
- `GRANT admin_datos TO rol_reportes` y `GRANT admin_datos TO app_web`: rechazados, porque `app_web` no tiene ADMIN OPTION sobre ese rol.
- `SET ROLE admin_datos`: rechazado.
- `fn_resetear_password(1, …)`: rechazado por falta de permiso EXECUTE. El objetivo era el usuario con id 1, probablemente un administrador.

**5. Intento de borrar huellas**
- `DELETE FROM auditoria_acceso`: rechazado.
- La sesión se cierra a los 34 ms de abrirse.

En resumen: alguien con las credenciales de `app_web` entró directamente por fuera de la aplicación, logró un login de usuario de la aplicación, leyó datos personales e intentó sin éxito ganar privilegios y borrar la auditoría. Los controles de privilegio mínimo funcionaron, salvo la lectura de columnas de `usuario`.

## Hipótesis de contención

**Hipótesis principal:** la credencial de `app_web` está comprometida. Puede haberse filtrado desde la configuración de la aplicación, un repositorio o variables de entorno, o bien `ip_origen_1` es un equipo comprometido. Lo que lo sugiere:
- Se usó un cliente SQL interactivo en lugar de la aplicación.
- Se ejecutó una secuencia guionada de reconocimiento, escalada y borrado.
- La regla 125 de `pg_hba.conf` acepta `app_web` desde un origen que permite este uso.

**Hipótesis alternativa:** como la base es `food_store_tp7_lab`, puede ser un script de verificación del trabajo práctico que prueba cada control a propósito: bloqueo, permisos por columna, GRANT, SET ROLE, EXECUTE y protección de la auditoría. Lo primero es confirmar si `ip_origen_1` y `sqlcli` corresponden a ese script. Si no corresponden, hay que tratarlo como incidente.

**Medidas de contención, si es un incidente:**
1. Cortar el acceso: rotar la contraseña de `app_web`, terminar las sesiones activas de ese rol y bloquear `ip_origen_1` en el firewall y en `pg_hba.conf`.
2. Restringir la regla 125 de `pg_hba.conf` a las IP de los servidores de la aplicación.
3. Para el usuario 17 de la aplicación: forzar el cambio de contraseña, invalidar sus sesiones y revisar si sus credenciales también están expuestas.
4. Revisar `fn_autenticar`: el umbral de bloqueo, el retardo entre intentos y si el contador se reinicia tras un acierto.
5. Tratar la lectura de la tabla `usuario` como una posible exposición de datos personales. Revisar si `app_web` necesita ver todas esas columnas de todos los usuarios o si debería acceder a través de una vista o función más acotada.
6. Preservar las evidencias: guardar los logs del servidor y el contenido de `auditoria_acceso`, y confirmar que esa tabla siga sin permisos de UPDATE ni DELETE para los roles de la aplicación.
7. Revisar otros logs: buscar otras sesiones desde `ip_origen_1` o con `application_name=sqlcli`, antes y después de las 09:42.

Revisé el análisis contra cada línea del log: secuencia, PIDs, contadores de intentos y el resultado de cada sentencia.

result: Reconstruí el log de PostgreSQL: una sesión guionada con la cuenta `app_web` hizo un login de aplicación tras 4 fallos sin que se bloqueara la cuenta, leyó datos personales de la tabla `usuario` y falló al intentar escalar privilegios y borrar la auditoría. La hipótesis es que la credencial de `app_web` está comprometida (o es un script de prueba del TP); para contener, propongo rotar esa credencial, restringir `pg_hba.conf`, bloquear la IP, endurecer el bloqueo y preservar la auditoría.