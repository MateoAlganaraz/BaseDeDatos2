\set ON_ERROR_STOP on
\pset pager off

-- Solo lectura. Ejecutar siempre sobre la COPIA de laboratorio antes de cargar TP3.
-- Este archivo exige el marcador de lote que tambien usa 01 y 05.
\if :{?tp3_lote}
\else
  \echo 'ERROR: ejecutar con -v tp3_lote=IDENTIFICADOR_ALFANUMERICO'
  \quit
\endif

SELECT current_database() AS base_conectada,
       current_user AS rol_conectado,
       version() AS version_postgresql,
       now() AS fecha_verificacion;

DO $preflight$
DECLARE
    lote text := :'tp3_lote';
BEGIN
    IF lote !~ '^[A-Za-z0-9_]+$' THEN
        RAISE EXCEPTION 'tp3_lote solo puede contener letras, numeros y guion bajo: %', lote;
    END IF;
    IF to_regclass('public.cliente') IS NULL
       OR to_regclass('public.categoria') IS NULL
       OR to_regclass('public.producto') IS NULL
       OR to_regclass('public.pedido') IS NULL
       OR to_regclass('public.detalle_pedido') IS NULL THEN
        RAISE EXCEPTION 'Faltan tablas Food Store; aplicar schema.sql a una copia antes de TP3';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM categoria) THEN
        RAISE EXCEPTION 'No hay categorias: la carga distribuye productos en categorias existentes';
    END IF;
END
$preflight$;

SELECT 'categorias_existentes' AS control, count(*) AS cantidad FROM categoria
UNION ALL SELECT 'clientes_existentes', count(*) FROM cliente
UNION ALL SELECT 'productos_existentes', count(*) FROM producto
UNION ALL SELECT 'pedidos_existentes', count(*) FROM pedido
UNION ALL SELECT 'detalles_existentes', count(*) FROM detalle_pedido;

SELECT conrelid::regclass AS tabla, conname AS restriccion, contype, convalidated
FROM pg_constraint
WHERE conrelid IN ('cliente'::regclass, 'producto'::regclass, 'pedido'::regclass, 'detalle_pedido'::regclass)
ORDER BY conrelid::regclass::text, conname;
