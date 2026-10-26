# Consigna 6 - Prompt enviado a la IA

Asistente: Claude (Anthropic), instancia separada sin acceso al repositorio ni a la base; recibió solo este texto (más la línea técnica "No uses herramientas ni leas archivos: respondé solo con texto, en español, a partir de este mensaje."). El prompt menciona, como pide la consigna, el modelo actual, el acceso frecuente a pedidos completos y la necesidad de conservar la coherencia de cantidades y precios.

## Prompt (literal)

Tengo una tienda online, Food Store, con este modelo relacional en PostgreSQL 16: cliente(id_cliente, nombre, apellido, email, telefono, deleted_at), categoria(id_categoria, nombre), producto(id_producto, nombre, precio_lista, stock, id_categoria, deleted_at), pedido(id_pedido, fecha, id_cliente, forma_pago, deleted_at) y detalle_pedido(id_pedido, id_producto, cantidad, precio_unitario, deleted_at) con clave primaria (id_pedido, id_producto) y claves foráneas a pedido y producto. Hay CHECK de cantidad > 0 y precio > 0, borrado lógico con deleted_at y unos 600.000 pedidos con 1.500.000 detalles.

La aplicación accede con mucha frecuencia a pedidos completos: el pedido con su cliente y todas sus líneas, por ejemplo para mostrar el historial o el detalle de una compra. Al mismo tiempo, necesito conservar la coherencia de cantidades y precios: el precio cobrado en cada línea (precio histórico) no debe cambiar aunque cambie el precio de lista del producto, el total del pedido tiene que coincidir con sus líneas, y al vender hay que descontar el stock sin que dos compras simultáneas vendan más de lo disponible.

Compará PostgreSQL y MongoDB para almacenar y consultar los pedidos de Food Store en este escenario. Indicá ventajas y desventajas de cada uno, cómo modelarías los pedidos en MongoDB y qué recomendarías: mantener PostgreSQL, pasar los pedidos a MongoDB o combinar ambos.
