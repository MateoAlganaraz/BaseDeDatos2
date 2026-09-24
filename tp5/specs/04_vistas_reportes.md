# Spec Codex - Vistas de reportes Food Store

Crear cuatro vistas sin modificar tablas base:

1. Productos vigentes con categoría: id, nombre, descripción, precio, stock y categoría; filtrar producto y categoría activos.
2. Pedidos con cliente: id de pedido, fecha, forma de pago e identificación pública del cliente.
3. Detalle de pedido con producto: pedido, producto, nombre, cantidad, precio unitario y subtotal.
4. Clientes para reportes: id, nombre, apellido y email. No incluir teléfono. El esquema real no tiene una columna `contraseña`; la vista implementa el mismo criterio de mínimo privilegio al no exponer el dato de contacto no requerido.

Criterio de aceptación: cada vista devuelve exactamente el mismo conjunto que su consulta manual equivalente, comprobado con `EXCEPT` en ambos sentidos.
