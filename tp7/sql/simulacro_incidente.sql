\pset pager off

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 5 - Parte C.1: simulacro de incidente de acceso indebido.
--
-- SOLO contra la base de laboratorio propia (food_store_tp7_lab en localhost). No apuntar
-- este script a ningún servidor de terceros.
-- Se ejecuta ya conectado como app_web por TCP, como lo haría el atacante desde su equipo:
--   psql -X "host=127.0.0.1 dbname=food_store_tp7_lab user=app_web application_name=sqlcli sslmode=require" \
--        -f tp7/sql/simulacro_incidente.sql
-- (lo ejecuta scripts/run_tp7.sh C, que además prepara las credenciales y recorta el log)
--
-- Escenario: un atacante obtuvo la cadena de conexión de la aplicación (rol app_web) y la usa
-- desde fuera de la aplicación (application_name distinto del de la tienda):
--   1. cuatro intentos fallidos de inicio de sesión contra fn_autenticar para un operador;
--   2. un inicio de sesión exitoso (contraseña débil adivinada);
--   3. una lectura masiva de la tabla usuario;
--   4. intentos de escalamiento hacia admin_datos y de una operación reservada a soporte.
-- ON_ERROR_STOP desactivado a propósito: los pasos 3 (parcial) y 4 deben fallar.
-- Las consultas no llevan alias descriptivos (como haría un atacante real): así el log que se
-- entrega a la IA no contiene pistas escritas por el equipo.
-- =====================================================================

SELECT current_user, inet_client_addr(), current_setting('application_name');

\echo '== C.1 Paso 1: intentos fallidos contra fn_autenticar =='
SELECT fn_autenticar('tomas.morales.17@correo.test', '123456');
SELECT fn_autenticar('tomas.morales.17@correo.test', 'foodstore');
SELECT fn_autenticar('tomas.morales.17@correo.test', 'Mendoza2026');
SELECT fn_autenticar('tomas.morales.17@correo.test', 'FoodStore2025!');

\echo '== C.1 Paso 2: inicio de sesión exitoso =='
SELECT fn_autenticar('tomas.morales.17@correo.test', 'FoodStore2026!');

\echo '== C.1 Paso 3: lectura masiva de usuario =='
-- Primero intenta todas las columnas (incluye password_hash): debe fallar por permiso de columna.
SELECT * FROM usuario;
-- Luego se queda con las columnas que sí puede leer. La salida se descarta: solo se informa
-- cuántas filas obtuvo.
\o /dev/null
SELECT id_usuario, nombre, apellido, email, rol, activo FROM usuario;
\o
SELECT count(*) FROM usuario;

\echo '== C.1 Paso 4: intentos de escalamiento =='
-- 4.a Otorgar a un rol de bajo privilegio membresía en admin_datos.
GRANT admin_datos TO rol_reportes;
-- 4.b Otorgárselo a sí mismo.
GRANT admin_datos TO app_web;
-- 4.c Asumir admin_datos directamente.
SET ROLE admin_datos;
-- 4.d Operación reservada a soporte: resetear la contraseña de otra cuenta.
SELECT fn_resetear_password(1, 'Intrusion-2026-xx');
-- 4.e Operación reservada al dueño: borrar el registro de accesos para ocultar el rastro.
DELETE FROM auditoria_acceso;
\echo '== C.1 Fin del simulacro =='
