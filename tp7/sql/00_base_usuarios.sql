\set ON_ERROR_STOP on
\pset pager off

-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 5 - Paso previo: reconstrucción de los artefactos de las Clases 1 y 2.
--
-- La consigna asume una tabla usuario y las funciones fn_autenticar y
-- fn_resetear_password trabajadas en clase. El esquema del repositorio (schema.sql)
-- no las tenía, así que se reconstruyen aquí (ver BITACORA.md, registro R0).
--
-- Ejecutar como superusuario, sobre la copia de laboratorio poblada
-- (schema.sql + tp6/00_carga_laboratorio.sql):
--   psql -X -v ON_ERROR_STOP=1 -d food_store_tp7_lab -f tp7/sql/00_base_usuarios.sql
--
-- Todos los usuarios son sintéticos (dominio .test). Las contraseñas de laboratorio
-- son débiles a propósito: una de ellas es la que "adivina" el simulacro de la Parte C.
-- =====================================================================

-- pgcrypto en un esquema propio: así se le puede quitar EXECUTE a PUBLIC sobre las
-- funciones del esquema public sin romper crypt() y gen_salt() (ver roles.sql).
CREATE SCHEMA IF NOT EXISTS extensiones;
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensiones;

-- Reejecución limpia: si roles.sql ya se aplicó, los objetos son de food_store_owner;
-- se recrean como superusuario y roles.sql vuelve a transferir la propiedad.
DROP FUNCTION IF EXISTS fn_autenticar(text, text);
DROP FUNCTION IF EXISTS fn_resetear_password(bigint, text);
DROP TABLE IF EXISTS auditoria_acceso;
DROP TABLE IF EXISTS usuario CASCADE;

-- Usuarios de la aplicación Food Store (no confundir con los roles del motor).
CREATE TABLE usuario (
    id_usuario        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre            VARCHAR(100) NOT NULL,
    apellido          VARCHAR(100) NOT NULL,
    email             VARCHAR(254) NOT NULL,
    telefono          VARCHAR(30),
    rol               VARCHAR(20)  NOT NULL,
    password_hash     TEXT         NOT NULL,
    fecha_alta        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    activo            BOOLEAN      NOT NULL DEFAULT TRUE,
    intentos_fallidos INTEGER      NOT NULL DEFAULT 0,
    bloqueado_hasta   TIMESTAMPTZ,
    CONSTRAINT uq_usuario_email UNIQUE (email),
    CONSTRAINT ck_usuario_rol CHECK (rol IN ('ADMIN', 'OPERADOR', 'REPARTIDOR', 'CLIENTE')),
    CONSTRAINT ck_usuario_intentos CHECK (intentos_fallidos >= 0)
);

-- Registro de accesos con vocación de rendición de cuentas: lo escribe fn_autenticar
-- (y fn_resetear_password) aunque el log del servidor no registre lo que pasa dentro
-- de una función.
CREATE TABLE auditoria_acceso (
    id_evento     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha         TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    evento        VARCHAR(30) NOT NULL,
    email_intento VARCHAR(254),
    id_usuario    BIGINT,
    rol_db        NAME        NOT NULL DEFAULT session_user,
    ip_origen     INET                 DEFAULT inet_client_addr(),
    aplicacion    TEXT                 DEFAULT current_setting('application_name', true),
    CONSTRAINT ck_auditoria_evento CHECK (evento IN ('LOGIN_OK', 'LOGIN_FALLIDO', 'LOGIN_BLOQUEADO', 'RESET_PASSWORD'))
);

-- ---------------------------------------------------------------------
-- fn_autenticar: valida email + contraseña sin exponer password_hash al llamador.
-- SECURITY DEFINER para que app_web no necesite leer password_hash.
-- Bloqueo de 15 minutos al quinto intento fallido consecutivo.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_autenticar(p_email TEXT, p_password TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensiones, pg_temp
AS $fn$
DECLARE
    v_usuario usuario%ROWTYPE;
BEGIN
    SELECT * INTO v_usuario FROM usuario WHERE email = lower(p_email) FOR UPDATE;

    IF NOT FOUND THEN
        -- Se calcula igual un hash para no revelar por tiempo de respuesta si el email existe.
        PERFORM crypt(p_password, gen_salt('bf', 6));
        INSERT INTO auditoria_acceso (evento, email_intento) VALUES ('LOGIN_FALLIDO', lower(p_email));
        RAISE LOG 'fn_autenticar: intento fallido (email inexistente)';
        RETURN FALSE;
    END IF;

    IF v_usuario.bloqueado_hasta IS NOT NULL AND v_usuario.bloqueado_hasta > now() THEN
        INSERT INTO auditoria_acceso (evento, email_intento, id_usuario)
        VALUES ('LOGIN_BLOQUEADO', lower(p_email), v_usuario.id_usuario);
        RAISE LOG 'fn_autenticar: cuenta bloqueada id_usuario=%', v_usuario.id_usuario;
        RETURN FALSE;
    END IF;

    IF v_usuario.activo AND v_usuario.password_hash = crypt(p_password, v_usuario.password_hash) THEN
        UPDATE usuario SET intentos_fallidos = 0, bloqueado_hasta = NULL
        WHERE id_usuario = v_usuario.id_usuario;
        INSERT INTO auditoria_acceso (evento, email_intento, id_usuario)
        VALUES ('LOGIN_OK', lower(p_email), v_usuario.id_usuario);
        RAISE LOG 'fn_autenticar: inicio de sesion correcto id_usuario=%', v_usuario.id_usuario;
        RETURN TRUE;
    END IF;

    UPDATE usuario
    SET intentos_fallidos = intentos_fallidos + 1,
        bloqueado_hasta = CASE WHEN intentos_fallidos + 1 >= 5 THEN now() + interval '15 minutes' END
    WHERE id_usuario = v_usuario.id_usuario;
    INSERT INTO auditoria_acceso (evento, email_intento, id_usuario)
    VALUES ('LOGIN_FALLIDO', lower(p_email), v_usuario.id_usuario);
    RAISE LOG 'fn_autenticar: intento fallido id_usuario=% intentos=%', v_usuario.id_usuario, v_usuario.intentos_fallidos + 1;
    RETURN FALSE;
END
$fn$;

-- ---------------------------------------------------------------------
-- fn_resetear_password: reservado a soporte. Desbloquea la cuenta y deja rastro.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_resetear_password(p_id_usuario BIGINT, p_nueva TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensiones, pg_temp
AS $fn$
BEGIN
    IF length(p_nueva) < 12 THEN
        RAISE EXCEPTION 'La contraseña nueva debe tener al menos 12 caracteres';
    END IF;
    -- Soporte no puede tomar control de una cuenta administradora (sugerencia de la IA
    -- aceptada en la Parte A; ver BITACORA.md, registro A2).
    IF EXISTS (SELECT 1 FROM usuario WHERE id_usuario = p_id_usuario AND rol = 'ADMIN') THEN
        RAISE EXCEPTION 'Las cuentas ADMIN no se resetean desde soporte' USING ERRCODE = 'insufficient_privilege';
    END IF;
    UPDATE usuario
    SET password_hash = crypt(p_nueva, gen_salt('bf', 10)),
        intentos_fallidos = 0,
        bloqueado_hasta = NULL
    WHERE id_usuario = p_id_usuario;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el usuario %', p_id_usuario;
    END IF;
    INSERT INTO auditoria_acceso (evento, id_usuario) VALUES ('RESET_PASSWORD', p_id_usuario);
END
$fn$;

-- ---------------------------------------------------------------------
-- Datos sintéticos: 2.000 usuarios con alta entre enero de 2025 y octubre de 2026.
-- Costo bcrypt 6 solo para que la carga de laboratorio sea rápida.
-- ---------------------------------------------------------------------
INSERT INTO usuario (nombre, apellido, email, telefono, rol, password_hash, fecha_alta, activo)
SELECT nom.v, ape.v,
       lower(format('%s.%s.%s@correo.test', translate(nom.v, 'áéíóúñ', 'aeioun'), translate(ape.v, 'áéíóúñ', 'aeioun'), s.n)),
       format('+54 261 4%s', lpad(mod(s.n * 7919, 1000000)::text, 6, '0')),
       CASE
           WHEN mod(s.n, 100) = 0 THEN 'ADMIN'
           WHEN mod(s.n, 100) < 7 THEN 'OPERADOR'
           WHEN mod(s.n, 100) < 15 THEN 'REPARTIDOR'
           ELSE 'CLIENTE'
       END,
       extensiones.crypt(CASE WHEN s.n = 17 THEN 'FoodStore2026!' ELSE format('Lab-%s-%s', s.n, md5(s.n::text)) END, extensiones.gen_salt('bf', 6)),
       timestamptz '2025-01-01 09:00-03' + (mod(s.n * 37, 664) * interval '1 day') + (mod(s.n * 911, 36000) * interval '1 second'),
       mod(s.n, 23) <> 0                                   -- ~4 % de cuentas deshabilitadas
FROM generate_series(1, 2000) AS s(n)
CROSS JOIN LATERAL (SELECT (ARRAY['Ana','Bruno','Carla','Diego','Elena','Facundo','Gabriela','Hernán','Inés','Julián',
                                  'Lucía','Martín','Natalia','Oscar','Paula','Ramiro','Sofía','Tomás','Valentina','Joaquín'])[1 + mod(s.n, 20)] AS v) AS nom
CROSS JOIN LATERAL (SELECT (ARRAY['Gómez','Pereyra','Sosa','Ríos','Funes','Videla','Molina','Correa','Ortiz','Lucero',
                                  'Quiroga','Morales','Aguirre','Domínguez','Ponce','Navarro','Herrera','Zapata'])[1 + mod(s.n * 7, 18)] AS v) AS ape;

-- La cuenta objetivo del simulacro (id 17) es un OPERADOR con contraseña débil.
UPDATE usuario SET rol = 'OPERADOR' WHERE id_usuario = 17;

ANALYZE usuario;

\echo '== Usuarios por rol =='
SELECT rol, count(*) FROM usuario GROUP BY rol ORDER BY rol;
\echo '== Prueba rápida de fn_autenticar (dentro de ROLLBACK) =='
BEGIN;
SELECT fn_autenticar('no.existe@correo.test', 'x') AS email_inexistente,
       fn_autenticar((SELECT email FROM usuario WHERE id_usuario = 17), 'FoodStore2026!') AS clave_correcta;
SELECT evento, id_usuario FROM auditoria_acceso ORDER BY id_evento;
ROLLBACK;
