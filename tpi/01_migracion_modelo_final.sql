-- TPI Food Store - migracion idempotente hacia el modelo final.
-- Ejecutar sobre una copia de trabajo y guardar la salida real en evidencia/.
-- Las consultas de precondicion deben devolver cero filas antes del COMMIT.

BEGIN;

ALTER TABLE cliente ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE producto ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

SELECT 'categoria_nombre_duplicado' AS control, nombre
FROM categoria GROUP BY nombre HAVING count(*) > 1
UNION ALL
SELECT 'cliente_email_vigente_duplicado', email
FROM cliente WHERE deleted_at IS NULL GROUP BY email HAVING count(*) > 1
UNION ALL
SELECT 'cliente_nombre_vacio', id_cliente::text FROM cliente WHERE btrim(nombre) = ''
UNION ALL
SELECT 'cliente_apellido_vacio', id_cliente::text FROM cliente WHERE btrim(apellido) = ''
UNION ALL
SELECT 'categoria_nombre_vacio', id_categoria::text FROM categoria WHERE btrim(nombre) = '';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_cliente_nombre_no_vacio') THEN
        ALTER TABLE cliente ADD CONSTRAINT ck_cliente_nombre_no_vacio CHECK (btrim(nombre) <> '');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_cliente_apellido_no_vacio') THEN
        ALTER TABLE cliente ADD CONSTRAINT ck_cliente_apellido_no_vacio CHECK (btrim(apellido) <> '');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_categoria_nombre_no_vacio') THEN
        ALTER TABLE categoria ADD CONSTRAINT ck_categoria_nombre_no_vacio CHECK (btrim(nombre) <> '');
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        WHERE c.conrelid = 'categoria'::regclass
          AND c.contype = 'u'
          AND c.conkey = ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid = 'categoria'::regclass AND attname = 'nombre')]::SMALLINT[]
    ) THEN
        ALTER TABLE categoria ADD CONSTRAINT uq_categoria_nombre UNIQUE (nombre);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_producto_precio_positivo') THEN
        ALTER TABLE producto DROP CONSTRAINT IF EXISTS ck_producto_precio_no_negativo;
        ALTER TABLE producto ADD CONSTRAINT ck_producto_precio_positivo CHECK (precio_lista > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_producto_nombre_no_vacio') THEN
        ALTER TABLE producto ADD CONSTRAINT ck_producto_nombre_no_vacio CHECK (btrim(nombre) <> '');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_detalle_precio_positivo') THEN
        ALTER TABLE detalle_pedido DROP CONSTRAINT IF EXISTS ck_detalle_precio_no_negativo;
        ALTER TABLE detalle_pedido ADD CONSTRAINT ck_detalle_precio_positivo CHECK (precio_unitario > 0);
    END IF;
END;
$$;

ALTER TABLE cliente DROP CONSTRAINT IF EXISTS cliente_email_key;
CREATE UNIQUE INDEX IF NOT EXISTS ux_cliente_email_vigente
    ON cliente (email) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tpi_cliente_vigente_apellido_nombre
    ON cliente (apellido, nombre) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tpi_producto_vigente_categoria
    ON producto (id_categoria, activo) WHERE deleted_at IS NULL;

COMMIT;
