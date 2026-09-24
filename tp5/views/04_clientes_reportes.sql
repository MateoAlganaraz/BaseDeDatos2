-- Vista 4 - Identificación mínima de clientes para reportes.
-- No existe columna contraseña en cliente; se evita además exponer telefono.
CREATE OR REPLACE VIEW vw_tp5_clientes_reportes AS
SELECT cli.id_cliente,
       cli.nombre,
       cli.apellido,
       cli.email
FROM cliente AS cli;
