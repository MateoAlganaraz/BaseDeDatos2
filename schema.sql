-- Mateo Algañaraz - Base de Datos II - 2026
-- Food Store: esquema final de referencia para el TPI.

CREATE TYPE forma_pago_enum AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);

CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(254) NOT NULL,
    telefono VARCHAR(30),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT ck_cliente_nombre_no_vacio CHECK (btrim(nombre) <> ''),
    CONSTRAINT ck_cliente_apellido_no_vacio CHECK (btrim(apellido) <> '')
);

CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(500),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_categoria_nombre_no_vacio CHECK (btrim(nombre) <> '')
);

CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion VARCHAR(500),
    precio_lista NUMERIC(12,2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at TIMESTAMPTZ,
    id_categoria BIGINT NOT NULL,
    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
        ON DELETE RESTRICT,
    CONSTRAINT ck_producto_precio_positivo
        CHECK (precio_lista > 0),
    CONSTRAINT ck_producto_stock_no_negativo
        CHECK (stock >= 0),
    CONSTRAINT ck_producto_nombre_no_vacio CHECK (btrim(nombre) <> '')
);

CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    id_cliente BIGINT NOT NULL,
    forma_pago forma_pago_enum NOT NULL,
    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES cliente(id_cliente)
        ON DELETE RESTRICT
);

CREATE TABLE detalle_pedido (
    id_pedido BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(12,2) NOT NULL,
    CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_pedido, id_producto),
    CONSTRAINT fk_detalle_pedido_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido) ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_pedido_producto
        FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT,
    CONSTRAINT ck_detalle_cantidad_positiva CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_precio_positivo CHECK (precio_unitario > 0)
);

CREATE UNIQUE INDEX ux_cliente_email_vigente
    ON cliente (email) WHERE deleted_at IS NULL;
CREATE INDEX idx_pedido_cliente_fecha ON pedido (id_cliente, fecha DESC);
CREATE INDEX idx_producto_categoria_activo_vigente
    ON producto (id_categoria, activo) WHERE deleted_at IS NULL;
