-- TPI Food Store - pruebas ejecutables de reglas, procedimiento, trigger y soft delete.
-- Todo ocurre dentro de ROLLBACK: la salida es evidencia, no deja datos de prueba.

BEGIN;

DO $$
DECLARE
    v_categoria BIGINT;
    v_producto BIGINT;
    v_producto_error BIGINT;
    v_cliente BIGINT;
    v_pedidos_antes BIGINT;
    v_pedidos_despues BIGINT;
    v_stock INTEGER;
    v_rechazado BOOLEAN := FALSE;
BEGIN
    INSERT INTO categoria (nombre, descripcion)
    VALUES ('TPI_PRUEBA_CATEGORIA', 'Datos reversibles de validacion')
    RETURNING id_categoria INTO v_categoria;
    INSERT INTO producto (nombre, precio_lista, stock, id_categoria)
    VALUES ('TPI_PRUEBA_PRODUCTO', 25.00, 3, v_categoria)
    RETURNING id_producto INTO v_producto;
    INSERT INTO cliente (nombre, apellido, email, telefono)
    VALUES ('TPI', 'Cliente', 'tpi.cliente@ejemplo.invalid', 'solo-prueba')
    RETURNING id_cliente INTO v_cliente;

    v_rechazado := FALSE;
    BEGIN
        INSERT INTO producto (nombre, precio_lista, stock, id_categoria)
        VALUES ('TPI_PRECIO_CERO', 0, 1, v_categoria);
    EXCEPTION WHEN check_violation THEN
        v_rechazado := TRUE;
    END;
    IF NOT v_rechazado THEN
        RAISE EXCEPTION 'Fallo de CHECK: se acepto precio de lista cero';
    END IF;

    v_rechazado := FALSE;
    BEGIN
        INSERT INTO producto (nombre, precio_lista, stock, id_categoria)
        VALUES ('   ', 1, 1, v_categoria);
    EXCEPTION WHEN check_violation THEN
        v_rechazado := TRUE;
    END;
    IF NOT v_rechazado THEN
        RAISE EXCEPTION 'Fallo de CHECK: se acepto nombre vacio';
    END IF;

    CALL sp_tpi_registrar_pedido(v_cliente, 'TARJETA', v_producto, 2);
    SELECT stock INTO v_stock FROM producto WHERE id_producto = v_producto;
    IF v_stock <> 1 THEN
        RAISE EXCEPTION 'Fallo de procedimiento: stock esperado 1, obtenido %', v_stock;
    END IF;

    v_rechazado := FALSE;
    BEGIN
        INSERT INTO producto (nombre, precio_lista, stock, id_categoria)
        VALUES ('TPI_PRODUCTO_PRECIO_DETALLE', 1, 1, v_categoria)
        RETURNING id_producto INTO v_producto_error;
        INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
        SELECT id_pedido, v_producto_error, 1, 0 FROM pedido WHERE id_cliente = v_cliente LIMIT 1;
    EXCEPTION WHEN check_violation THEN
        v_rechazado := TRUE;
    END;
    IF NOT v_rechazado THEN
        RAISE EXCEPTION 'Fallo de CHECK: se acepto precio unitario cero';
    END IF;

    SELECT count(*) INTO v_pedidos_antes FROM pedido WHERE id_cliente = v_cliente;
    BEGIN
        CALL sp_tpi_registrar_pedido(v_cliente, 'TARJETA', v_producto, 2);
    EXCEPTION WHEN OTHERS THEN
        v_rechazado := TRUE;
    END;
    SELECT count(*) INTO v_pedidos_despues FROM pedido WHERE id_cliente = v_cliente;
    IF NOT v_rechazado OR v_pedidos_antes <> v_pedidos_despues THEN
        RAISE EXCEPTION 'Fallo de atomicidad ante stock insuficiente';
    END IF;

    UPDATE producto SET activo = FALSE WHERE id_producto = v_producto;
    v_rechazado := FALSE;
    BEGIN
        INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
        SELECT id_pedido, v_producto, 1, 25.00
        FROM pedido WHERE id_cliente = v_cliente LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
        v_rechazado := TRUE;
    END;
    IF NOT v_rechazado THEN
        RAISE EXCEPTION 'Fallo de trigger: admitio un producto inactivo';
    END IF;

    CALL sp_tpi_baja_logica_cliente(v_cliente);
    IF EXISTS (SELECT 1 FROM vw_tpi_clientes_vigentes WHERE id_cliente = v_cliente) THEN
        RAISE EXCEPTION 'Fallo de soft delete: cliente aun visible en la vista';
    END IF;
    INSERT INTO cliente (nombre, apellido, email)
    VALUES ('TPI', 'Reincorporado', 'tpi.cliente@ejemplo.invalid');
    IF (SELECT count(*) FROM auditoria_producto WHERE id_producto = v_producto) < 2 THEN
        RAISE EXCEPTION 'Fallo de auditoria de producto';
    END IF;

    RAISE NOTICE 'PRUEBAS_TPI_OK: procedimiento, atomicidad, trigger, auditoria y soft delete validados';
END;
$$;

SELECT 'PRUEBAS_TPI_OK' AS resultado,
       'CHECK, procedimiento, atomicidad, trigger, auditoria y soft delete validados' AS alcance;

SELECT 'objetos_programables' AS control,
       (SELECT count(*) FROM pg_proc WHERE proname IN ('sp_tpi_registrar_pedido', 'sp_tpi_baja_logica_cliente')) AS procedimientos,
       (SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_tpi_detalle_producto_vigente', 'trg_tpi_auditoria_producto') AND NOT tgisinternal) AS triggers,
       (SELECT count(*) FROM pg_views WHERE viewname IN ('vw_tpi_clientes_vigentes', 'vw_tpi_productos_vigentes')) AS vistas;

ROLLBACK;
