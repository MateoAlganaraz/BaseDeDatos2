-- Vistas de reportes de TP5.
-- Se completa incrementalmente y cada vista queda además en views/.

-- Productos y categorías vigentes para el catálogo de reportes.
CREATE OR REPLACE VIEW vw_tp5_productos_vigentes_categoria AS
SELECT prod.id_producto,
       prod.nombre AS producto,
       prod.descripcion,
       prod.precio_lista,
       prod.stock,
       cat.id_categoria,
       cat.nombre AS categoria
FROM producto AS prod
JOIN categoria AS cat ON cat.id_categoria = prod.id_categoria
WHERE prod.activo
  AND cat.activo;

-- Pedidos con los datos de identificación necesarios del cliente.
CREATE OR REPLACE VIEW vw_tp5_pedidos_cliente AS
SELECT ped.id_pedido,
       ped.fecha,
       ped.forma_pago,
       cli.id_cliente,
       cli.nombre,
       cli.apellido,
       cli.email
FROM pedido AS ped
JOIN cliente AS cli ON cli.id_cliente = ped.id_cliente;

-- Detalle de cada pedido con nombre de producto y subtotal estandarizado.
CREATE OR REPLACE VIEW vw_tp5_detalle_pedido_producto AS
SELECT det.id_pedido,
       det.id_producto,
       prod.nombre AS producto,
       det.cantidad,
       det.precio_unitario,
       det.cantidad * det.precio_unitario AS subtotal
FROM detalle_pedido AS det
JOIN producto AS prod ON prod.id_producto = det.id_producto;

-- Mínimo privilegio para reportes. El esquema no tiene columna contraseña;
-- se omite teléfono, que no es necesario para identificar al cliente.
CREATE OR REPLACE VIEW vw_tp5_clientes_reportes AS
SELECT cli.id_cliente,
       cli.nombre,
       cli.apellido,
       cli.email
FROM cliente AS cli;
