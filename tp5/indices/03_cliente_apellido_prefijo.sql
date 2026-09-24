-- Q3 - Búsqueda de clientes por apellido.
CREATE INDEX idx_tp5_cliente_apellido_prefijo
    ON cliente (apellido text_pattern_ops)
    INCLUDE (id_cliente, nombre, email);

ANALYZE cliente;
