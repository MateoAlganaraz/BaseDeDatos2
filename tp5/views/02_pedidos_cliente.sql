-- Vista 2 - Pedidos con identificación pública del cliente.
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
