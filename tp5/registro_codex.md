# Registro de especificación con Codex

## Interacción 1 - Plan de indexado

Propósito: transformar las consultas frecuentes de Food Store en especificaciones medibles antes de crear objetos.

Instrucción aplicada a Codex: identificar consultas frecuentes sobre tablas de volumen considerable, describir filtro, orden, frecuencia y criterio de aceptación; proponer un índice solo si podía verificarse con `EXPLAIN (ANALYZE, BUFFERS)`.

Resultado verificable:

- Se crearon `specs/01_indice_detalle_producto.md`, `02_indice_producto_nombre.md` y `03_indice_cliente_apellido.md`.
- Las tres consultas iniciales mostraron `Seq Scan` en `detalle_pedido`, `producto` y `cliente`.
- Los índices aceptados están en `indices/` y los planes finales están resumidos en `informe_mediciones.md`.
- Se rechazó un índice aislado sobre `producto.activo` por su baja cardinalidad y porque no resolvía una consulta selectiva.

## Interacción 2 - Vistas y equivalencia

Propósito: definir columnas expuestas, filtros de vigencia y criterio de mínimo privilegio antes de crear las vistas.

Instrucción aplicada a Codex: generar vistas para catálogo, pedidos, detalle y clientes de reportes, junto con una consulta manual equivalente para comprobar cada resultado en ambos sentidos con `EXCEPT`.

Resultado verificable:

- Las cuatro vistas están en `views.sql` y `views/`.
- `05_equivalencia_views.sql` produjo ocho controles con resultado `0`.
- La vista de clientes no expone `telefono`; el esquema real no contiene una columna contraseña.

## Interacción 3 - Vista materializada

Propósito: precalcular la facturación por categoría y mes sin modificar tablas base.

Instrucción aplicada a Codex: crear una vista materializada con `WITH DATA`, una clave única apta para `REFRESH MATERIALIZED VIEW CONCURRENTLY` y una medición comparativa contra el reporte original.

Resultado verificable:

- `materializadas.sql` crea `mv_tp5_facturacion_categoria_mes` e `idx_mv_tp5_facturacion_categoria_mes`.
- El reporte original tomó 550,464 ms; la consulta sobre la vista materializada tomó 0,067 ms.
- El refresh concurrente fue ejecutado correctamente y tomó 539,135 ms.

Las decisiones finales se basan en esos archivos y en las mediciones de PostgreSQL, no en una recomendación de IA sin validar.
