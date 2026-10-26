\set ON_ERROR_STOP on
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP Unidad 6 - Rol de respaldo con mínimo privilegio (SPEC_U6, regla 2).
--
-- pg_read_all_data (PostgreSQL 14+) da SELECT sobre todas las tablas, vistas y secuencias,
-- que es lo único que pg_dump necesita para un respaldo lógico. No puede escribir ni crear
-- objetos. La contraseña NO se define aquí: se fija fuera del repositorio, por ejemplo con
--   psql -c "\password foodstore_backup"
-- y se guarda en ~/.pgpass (Linux) o %APPDATA%\postgresql\pgpass.conf (Windows).
--   psql -X -d postgres -f tp8/sql/00_rol_respaldo.sql
-- =====================================================================
DO $rol$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'foodstore_backup') THEN
        CREATE ROLE foodstore_backup LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
END
$rol$;
GRANT pg_read_all_data TO foodstore_backup;
GRANT CONNECT ON DATABASE foodstore TO foodstore_backup;
ALTER ROLE foodstore_backup CONNECTION LIMIT 2;
COMMENT ON ROLE foodstore_backup IS 'Respaldo lógico de foodstore (solo lectura). TP Unidad 6.';
\du foodstore_backup
