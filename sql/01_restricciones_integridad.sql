-- Ejecutar primero en una transaccion MANUAL despues de revisar los SELECT.
-- Este archivo no abre ni confirma transacciones automaticamente.
-- Si cualquiera de las consultas de revision devuelve filas, corregir esos datos
-- antes de aplicar los ALTER TABLE. Un ROLLBACK revierte todos los cambios.

SELECT id_producto, precio_lista
FROM producto
WHERE precio_lista <= 0;

SELECT id_producto, nombre
FROM producto
WHERE btrim(nombre) = '';

SELECT id_pedido, id_producto, precio_unitario
FROM detalle_pedido
WHERE precio_unitario <= 0;

-- Reglas revisadas: reemplazan los CHECK originales que admitian cero y
-- agregan la prohibicion de nombres compuestos solo por espacios.
ALTER TABLE producto
    DROP CONSTRAINT IF EXISTS ck_producto_precio_no_negativo,
    ADD CONSTRAINT ck_producto_precio_positivo CHECK (precio_lista > 0),
    ADD CONSTRAINT ck_producto_nombre_no_vacio CHECK (btrim(nombre) <> '');

ALTER TABLE detalle_pedido
    DROP CONSTRAINT IF EXISTS ck_detalle_precio_no_negativo,
    ADD CONSTRAINT ck_detalle_precio_positivo CHECK (precio_unitario > 0);
