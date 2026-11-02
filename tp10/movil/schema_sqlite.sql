PRAGMA foreign_keys = ON;
-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP N.º 8 (Unidad 8) - Consigna 1.b: la base de la tablet (SQLite 3.37+).
--
--   cd tp10/movil
--   sqlite3 foodstore_movil.db < schema_sqlite.sql
--
-- Regla de oro: el móvil propone, el servidor dispone. La tablet guarda una copia del
-- catálogo (producto_cache) y sus propios borradores; precio, stock y ventas los decide
-- PostgreSQL. Ninguna tabla de acá se sincroniza de vuelta como venta.
--
-- Crea la base desde cero: si las tablas ya existen, las borra (en orden inverso a las FK).
-- Todas las tablas son STRICT: SQLite rechaza un valor que no sea del tipo declarado.
-- =====================================================================

DROP VIEW IF EXISTS catalogo_disponible;
DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;
DROP TABLE IF EXISTS snapshot_servidor;

-- ---------------------------------------------------------------------
-- Copia del catálogo que viaja desde el servidor (consigna 1.a).
-- La fila de un producto dado de baja NO se borra: queda con eliminado = 1 (lápida),
-- porque los borradores viejos la referencian y la tablet tiene que saber que ya no existe.
-- ---------------------------------------------------------------------
CREATE TABLE producto_cache (
    id              INTEGER PRIMARY KEY,                 -- producto.id_producto del servidor
    nombre          TEXT    NOT NULL CHECK (length(trim(nombre)) > 0),
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),   -- entero: sin errores de redondeo
    stock_visto     INTEGER NOT NULL CHECK (stock_visto >= 0),       -- lo que había al copiar; no es una reserva
    disponible      INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado       INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    copiado_en      TEXT    NOT NULL                     -- fecha de la instantánea del servidor
) STRICT;

-- ---------------------------------------------------------------------
-- Borrador de pedido armado en la feria. id_local es un UUID v4 generado en la tablet:
-- no depende del servidor y no choca con los de otras tablets.
-- usuario es el operador de la tablet (sin datos personales).
-- ---------------------------------------------------------------------
CREATE TABLE pedido_borrador (
    id_local   TEXT PRIMARY KEY CHECK (
                   length(id_local) = 36 AND id_local NOT GLOB '*[^0-9a-f-]*'
                   AND substr(id_local, 9, 1) = '-' AND substr(id_local, 14, 1) = '-'
                   AND substr(id_local, 15, 1) = '4' AND substr(id_local, 19, 1) = '-'
                   AND substr(id_local, 20, 1) IN ('8', '9', 'a', 'b') AND substr(id_local, 24, 1) = '-'),
    usuario    TEXT NOT NULL CHECK (length(trim(usuario)) > 0),
    forma_pago TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;

-- ---------------------------------------------------------------------
-- Ítems del borrador. precio_centavos_visto es el precio que el cliente vio en la tablet;
-- el semáforo lo compara con el del servidor.
-- ---------------------------------------------------------------------
CREATE TABLE item_borrador (
    id_local              TEXT    NOT NULL REFERENCES pedido_borrador (id_local) ON DELETE CASCADE,
    producto_id           INTEGER NOT NULL REFERENCES producto_cache (id),
    cantidad              INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)              -- un producto una sola vez por borrador, como en el servidor
) STRICT;

CREATE INDEX ix_item_borrador_producto ON item_borrador (producto_id);

-- La tablet solo arma borradores con lo que su catálogo muestra disponible.
CREATE TRIGGER tr_item_solo_catalogo_disponible
BEFORE INSERT ON item_borrador
WHEN EXISTS (SELECT 1 FROM producto_cache p
             WHERE p.id = NEW.producto_id AND (p.disponible = 0 OR p.eliminado = 1))
BEGIN
    SELECT RAISE(ABORT, 'producto no disponible en el catálogo de la tablet');
END;

-- ---------------------------------------------------------------------
-- Solicitudes de sincronización. solicitud_uuid es la clave de idempotencia: reenviar la
-- misma solicitud choca con la PK. Una solicitud evaluada ya no vuelve a PENDIENTE.
-- SIMULADO_APROBADO significa "el servidor la aceptaría hoy": NO es una venta.
-- ---------------------------------------------------------------------
CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY CHECK (
                       length(solicitud_uuid) = 36 AND solicitud_uuid NOT GLOB '*[^0-9a-f-]*'
                       AND substr(solicitud_uuid, 9, 1) = '-' AND substr(solicitud_uuid, 14, 1) = '-'
                       AND substr(solicitud_uuid, 15, 1) = '4' AND substr(solicitud_uuid, 19, 1) = '-'
                       AND substr(solicitud_uuid, 20, 1) IN ('8', '9', 'a', 'b')
                       AND substr(solicitud_uuid, 24, 1) = '-'),
    id_local       TEXT NOT NULL REFERENCES pedido_borrador (id_local),
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE'
                       CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo         TEXT,
    creada_en      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    evaluada_en    TEXT,
    CHECK ((estado = 'PENDIENTE') = (evaluada_en IS NULL))   -- evaluada si y solo si dejó de estar pendiente
) STRICT;

CREATE INDEX ix_cola_sync_estado ON cola_sync (estado);

-- ---------------------------------------------------------------------
-- Instantánea tal como llega del servidor (consigna 2.a): v_snapshot_movil exportada a CSV.
-- Los booleanos de PostgreSQL llegan como 't' / 'f'. Se reemplaza entera en cada carga.
-- ---------------------------------------------------------------------
CREATE TABLE snapshot_servidor (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock           INTEGER NOT NULL CHECK (stock >= 0),
    disponible      TEXT    NOT NULL CHECK (disponible IN ('t', 'f')),
    eliminado       TEXT    NOT NULL CHECK (eliminado IN ('t', 'f')),
    copiado_en      TEXT    NOT NULL
) STRICT;

-- Catálogo que ve el vendedor (caso C1): no necesita conexión con el servidor.
CREATE VIEW catalogo_disponible AS
SELECT id, nombre, precio_centavos, stock_visto, copiado_en
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0;

SELECT 'schema_sqlite.sql' AS script, sqlite_version() AS sqlite,
       (SELECT foreign_keys FROM pragma_foreign_keys) AS foreign_keys,
       (SELECT count(*) FROM sqlite_schema WHERE type = 'table') AS tablas;
