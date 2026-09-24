-- Requiere las tres restricciones de 01_restricciones_integridad.sql aplicadas.
-- Prueba autocontenida: no deja filas persistentes porque finaliza con ROLLBACK.
-- Ejecutar en psql sin ON_ERROR_STOP: los tres errores posteriores son esperados.
-- Los errores esperados solo demuestran las reglas si la consulta siguiente muestra
-- las tres restricciones esperadas como presentes antes de iniciar la prueba.
SELECT conname AS restriccion_esperada, contype AS tipo
FROM pg_constraint
WHERE conname IN (
    'ck_producto_precio_positivo',
    'ck_producto_nombre_no_vacio',
    'ck_detalle_precio_positivo'
)
ORDER BY conname;

BEGIN;

CREATE TEMP TABLE prueba_refs (
    id_categoria BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    id_pedido BIGINT NOT NULL
) ON COMMIT DROP;

WITH categoria_nueva AS (
    INSERT INTO categoria (nombre, descripcion)
    VALUES ('PRUEBA_RESTRICCIONES', 'Fila temporal de laboratorio')
    RETURNING id_categoria
), producto_nuevo AS (
    INSERT INTO producto (nombre, descripcion, precio_lista, stock, id_categoria)
    SELECT 'Producto valido', 'Prueba valida', 10.50, 2, id_categoria
    FROM categoria_nueva
    RETURNING id_producto, id_categoria
), cliente_nuevo AS (
    INSERT INTO cliente (nombre, apellido, email)
    VALUES ('Prueba', 'Restricciones', 'prueba.restricciones@ejemplo.invalid')
    RETURNING id_cliente
), pedido_nuevo AS (
    INSERT INTO pedido (id_cliente, forma_pago)
    SELECT id_cliente, 'EFECTIVO'::forma_pago_enum FROM cliente_nuevo
    RETURNING id_pedido
)
INSERT INTO prueba_refs (id_categoria, id_producto, id_pedido)
SELECT producto_nuevo.id_categoria, producto_nuevo.id_producto, pedido_nuevo.id_pedido
FROM producto_nuevo CROSS JOIN pedido_nuevo;

-- Caso valido: debe insertar una linea de pedido.
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_pedido, id_producto, 1, 10.50 FROM prueba_refs;

-- Error esperado: ck_producto_precio_positivo rechaza precio_lista = 0.
SAVEPOINT precio_producto_invalido;
INSERT INTO producto (nombre, precio_lista, stock, id_categoria)
SELECT 'Precio cero', 0, 0, id_categoria FROM prueba_refs;
ROLLBACK TO SAVEPOINT precio_producto_invalido;
RELEASE SAVEPOINT precio_producto_invalido;

-- Error esperado: ck_producto_nombre_no_vacio rechaza un nombre con espacios.
SAVEPOINT nombre_producto_invalido;
INSERT INTO producto (nombre, precio_lista, stock, id_categoria)
SELECT '   ', 1, 0, id_categoria FROM prueba_refs;
ROLLBACK TO SAVEPOINT nombre_producto_invalido;
RELEASE SAVEPOINT nombre_producto_invalido;

-- Error esperado: ck_detalle_precio_positivo rechaza precio_unitario = 0.
SAVEPOINT precio_detalle_invalido;
WITH producto_para_error AS (
    INSERT INTO producto (nombre, precio_lista, stock, id_categoria)
    SELECT 'Producto para detalle invalido', 1, 0, id_categoria FROM prueba_refs
    RETURNING id_producto
)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT prueba_refs.id_pedido, producto_para_error.id_producto, 2, 0
FROM prueba_refs CROSS JOIN producto_para_error;
ROLLBACK TO SAVEPOINT precio_detalle_invalido;
RELEASE SAVEPOINT precio_detalle_invalido;

ROLLBACK;
