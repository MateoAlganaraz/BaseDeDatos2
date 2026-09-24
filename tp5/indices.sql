-- Índices aceptados de TP5.
-- Se completa incrementalmente: cada bloque está además en índices/ para que el
-- historial de Git muestre la decisión individual y su medición correspondiente.

-- Q1: el filtro selectivo por producto queda primero y el pedido conserva el orden.
-- INCLUDE permite devolver cantidad y precio sin ampliar la clave de búsqueda.
CREATE INDEX idx_tp5_detalle_producto_pedido
    ON detalle_pedido (id_producto, id_pedido)
    INCLUDE (cantidad, precio_unitario);

ANALYZE detalle_pedido;

-- Q2: text_pattern_ops permite buscar un prefijo con LIKE; la condición parcial
-- evita indexar los productos inactivos que la consulta nunca muestra.
CREATE INDEX idx_tp5_producto_nombre_activo_prefijo
    ON producto (nombre text_pattern_ops)
    INCLUDE (id_producto, precio_lista, stock)
    WHERE activo;

ANALYZE producto;

-- Q3: el apellido se usa como prefijo y orden; nombre y email cubren la salida.
CREATE INDEX idx_tp5_cliente_apellido_prefijo
    ON cliente (apellido text_pattern_ops)
    INCLUDE (id_cliente, nombre, email);

ANALYZE cliente;
