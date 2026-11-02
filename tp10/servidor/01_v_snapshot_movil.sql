-- =====================================================================
-- Mateo Algañaraz - Base de Datos II - 2026
-- TP N.º 8 (Unidad 8) - Consigna 2.a: instantánea para la tablet, en el PostgreSQL de PRUEBAS.
--
-- Se ejecuta sobre una COPIA de foodstore (nunca sobre la base original):
--   createdb -T foodstore foodstore_tp10_lab
--   psql -X -v ON_ERROR_STOP=1 -d foodstore_tp10_lab -f tp10/servidor/01_v_snapshot_movil.sql
-- Sin metacomandos de psql: también corre en DBeaver (Alt+X).
--
-- Qué viaja (consigna 1.a): id, nombre, precio en centavos, stock, disponible y eliminado.
-- No viajan clientes, pedidos, descripción ni categoría. Los productos dados de baja viajan
-- como lápidas (eliminado = true) para que la tablet sepa que ya no existen.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS movil;

CREATE OR REPLACE VIEW movil.v_snapshot_movil AS
SELECT p.id_producto                          AS id,
       p.nombre,
       (p.precio_lista * 100)::bigint         AS precio_centavos,   -- NUMERIC(12,2) a centavos, sin redondeo
       p.stock,
       (p.activo AND p.deleted_at IS NULL)    AS disponible,
       (p.deleted_at IS NOT NULL)             AS eliminado,         -- lápida: la fila viaja igual
       to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS copiado_en
FROM public.producto p;

COMMENT ON VIEW movil.v_snapshot_movil IS
    'Instantánea del catálogo para la tablet (TP N.º 8). Solo lectura; incluye lápidas de bajas lógicas.';

-- ---------------------------------------------------------------------
-- Línea base para el control final: cantidad de pedidos y detalles, y stock de cada producto
-- antes de cualquier simulación. Si la tablet no toca el servidor, al final debe coincidir.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS movil.linea_base_stock;
DROP TABLE IF EXISTS movil.linea_base;
CREATE TABLE movil.linea_base (
    tomada_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
    pedidos          BIGINT      NOT NULL,
    detalles         BIGINT      NOT NULL,
    stock_total      BIGINT      NOT NULL
);
INSERT INTO movil.linea_base (pedidos, detalles, stock_total)
SELECT (SELECT count(*) FROM public.pedido),
       (SELECT count(*) FROM public.detalle_pedido),
       (SELECT sum(stock) FROM public.producto);

CREATE TABLE movil.linea_base_stock AS
SELECT id_producto, stock FROM public.producto;
ALTER TABLE movil.linea_base_stock ADD PRIMARY KEY (id_producto);

SELECT 'v_snapshot_movil' AS objeto, count(*) AS filas,
       count(*) FILTER (WHERE disponible) AS disponibles,
       count(*) FILTER (WHERE eliminado) AS lapidas
FROM movil.v_snapshot_movil;

SELECT * FROM movil.linea_base;
