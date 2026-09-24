-- TPI Food Store - funciones, procedimientos, trigger, vistas y privilegios.
-- Requiere ejecutar antes 01_migracion_modelo_final.sql.

CREATE TABLE IF NOT EXISTS auditoria_producto (
    id_auditoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ocurrido_en TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    operacion TEXT NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    id_producto BIGINT,
    usuario_db NAME NOT NULL DEFAULT current_user,
    antes JSONB,
    despues JSONB
);

CREATE OR REPLACE FUNCTION fn_tpi_validar_producto_vigente()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM 1
    FROM producto
    WHERE id_producto = NEW.id_producto
      AND activo
      AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto % no esta vigente para agregarlo a un pedido', NEW.id_producto;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tpi_detalle_producto_vigente ON detalle_pedido;
CREATE TRIGGER trg_tpi_detalle_producto_vigente
BEFORE INSERT OR UPDATE OF id_producto ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION fn_tpi_validar_producto_vigente();

CREATE OR REPLACE FUNCTION fn_tpi_auditar_producto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO auditoria_producto (operacion, id_producto, antes, despues)
    VALUES (
        TG_OP,
        COALESCE(NEW.id_producto, OLD.id_producto),
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END
    );
    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_tpi_auditoria_producto ON producto;
CREATE TRIGGER trg_tpi_auditoria_producto
AFTER INSERT OR UPDATE OR DELETE ON producto
FOR EACH ROW EXECUTE FUNCTION fn_tpi_auditar_producto();

CREATE OR REPLACE PROCEDURE sp_tpi_registrar_pedido(
    p_id_cliente BIGINT,
    p_forma_pago forma_pago_enum,
    p_id_producto BIGINT,
    p_cantidad INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_pedido BIGINT;
    v_precio NUMERIC(12,2);
    v_stock INTEGER;
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser positiva';
    END IF;

    PERFORM 1 FROM cliente
    WHERE id_cliente = p_id_cliente AND deleted_at IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cliente % no existe o fue dado de baja', p_id_cliente;
    END IF;

    SELECT precio_lista, stock INTO v_precio, v_stock
    FROM producto
    WHERE id_producto = p_id_producto
      AND activo
      AND deleted_at IS NULL
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto % no existe o no esta vigente', p_id_producto;
    END IF;
    IF v_stock < p_cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente: disponible %, solicitado %', v_stock, p_cantidad;
    END IF;

    UPDATE producto SET stock = stock - p_cantidad
    WHERE id_producto = p_id_producto;
    INSERT INTO pedido (id_cliente, forma_pago)
    VALUES (p_id_cliente, p_forma_pago)
    RETURNING id_pedido INTO v_id_pedido;
    INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
    VALUES (v_id_pedido, p_id_producto, p_cantidad, v_precio);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_tpi_baja_logica_cliente(p_id_cliente BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE cliente
    SET deleted_at = clock_timestamp()
    WHERE id_cliente = p_id_cliente
      AND deleted_at IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cliente % no existe o ya estaba dado de baja', p_id_cliente;
    END IF;
END;
$$;

CREATE OR REPLACE VIEW vw_tpi_clientes_vigentes AS
SELECT id_cliente, nombre, apellido, email
FROM cliente
WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW vw_tpi_productos_vigentes AS
SELECT p.id_producto, p.nombre, p.descripcion, p.precio_lista, p.stock,
       p.id_categoria, c.nombre AS categoria
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE p.activo AND p.deleted_at IS NULL AND c.activo;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'food_store_reporter') THEN
        CREATE ROLE food_store_reporter NOLOGIN;
    END IF;
END;
$$;

GRANT USAGE ON SCHEMA public TO food_store_reporter;
GRANT SELECT ON vw_tpi_clientes_vigentes, vw_tpi_productos_vigentes TO food_store_reporter;
REVOKE ALL ON TABLE cliente, producto FROM food_store_reporter;
