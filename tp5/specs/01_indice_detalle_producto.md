# Spec Codex - Índice de detalles por producto

Objetivo: acelerar la consulta frecuente que recupera los detalles de venta de un producto puntual y los ordena por pedido.

Consulta afectada: `detalle_pedido` filtrada por `id_producto = 100001`, con salida de pedido, cantidad y precio unitario ordenada por `id_pedido`.

Frecuencia: consulta de historial de ventas al abrir un producto en un reporte de catálogo.

Columnas candidatas: `id_producto` es el filtro altamente selectivo; `id_pedido` satisface el orden; `cantidad` y `precio_unitario` se usan como cobertura de lectura.

Criterio de aceptación: el plan cambia de `Parallel Seq Scan` a `Index Scan`, `Index Only Scan` o `Bitmap Heap Scan`, manteniendo exactamente las mismas filas y reduciendo el tiempo real.
