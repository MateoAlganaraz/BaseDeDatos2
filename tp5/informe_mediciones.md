# TP5 - Informe de mediciones

## Entorno reproducible

Las mediciones se realizaron con PostgreSQL 18.4 en dos copias creadas desde `food_store_tp3_mediciones`:

- `food_store_tp5_base`, sin los índices de TP5.
- `food_store_tp5_indices_vistas`, con los objetos de TP5.

La carga heredada tiene 400.000 filas en `detalle_pedido`, 200.000 en `pedido`, 50.000 en `producto` y 20.000 en `cliente`. Los tiempos informados son `Execution Time` de `EXPLAIN (ANALYZE, BUFFERS)`; no son valores de `cost`.

## Parte A - Plan de indexado

| Consulta | Plan antes | Índice aceptado | Plan después | Antes | Después | Mejora |
|---|---|---|---|---:|---:|---:|
| Q1 Detalles del producto 100001 | `Parallel Seq Scan` en 400.000 detalles; removió 399.992 filas | `idx_tp5_detalle_producto_pedido (id_producto, id_pedido) INCLUDE (cantidad, precio_unitario)` | `Bitmap Index Scan` y `Bitmap Heap Scan` | 27,891 ms | 0,152 ms | 183,49x |
| Q2 Autocompletado de productos activos | `Seq Scan` en 50.000 productos; removió 49.050 filas | índice parcial `idx_tp5_producto_nombre_activo_prefijo` con `text_pattern_ops` | `Index Only Scan` | 8,988 ms | 1,446 ms | 6,22x |
| Q3 Clientes por apellido | `Seq Scan` en 20.000 clientes; removió 19.900 filas | `idx_tp5_cliente_apellido_prefijo` con `text_pattern_ops` | `Index Only Scan` | 3,518 ms | 0,176 ms | 19,99x |

Q2 escapa los guiones bajos con `ESCAPE '\'`: en `LIKE`, `_` es un comodín. Sin ese escape el prefijo no era literal y el planificador conservaba el `Seq Scan`.

### Costo sobre escritura

Se insertaron 600 filas válidas en `detalle_pedido` dentro de una transacción que terminó en `ROLLBACK`. La preparación del lote ocurrió antes de activar la medición.

| Escenario | Tiempo de `INSERT` | Lectura |
|---|---:|---|
| Sin índices de TP5 | 8,299 ms | Base de comparación. |
| Con índices de TP5 | 15,327 ms | 1,85x más lento: cada inserción debe mantener los índices nuevos. |

El aumento de escritura se acepta porque las tres lecturas optimizadas son frecuentes, selectivas y reducen recorridos de miles de filas a accesos indexados. La carga de escritura se mantiene bajo control y fue reversible.

### Propuesta descartada por sobreindexación

Se descarta `CREATE INDEX ... ON producto (activo)`. `activo` tiene baja cardinalidad: 47.500 productos activos y 2.500 inactivos. Además, el índice parcial de Q2 ya contiene únicamente activos. Crear un índice aislado sobre `activo` aumentaría el costo de mantenimiento sin resolver un filtro selectivo ni una consulta concreta.

## Parte B - Vistas y equivalencia

| Vista | Propósito | Controles `EXCEPT` |
|---|---|---|
| `vw_tp5_productos_vigentes_categoria` | Catálogo de productos y categorías activas. | 0 en ambos sentidos. |
| `vw_tp5_pedidos_cliente` | Pedido con identificación pública del cliente. | 0 en ambos sentidos. |
| `vw_tp5_detalle_pedido_producto` | Detalle de pedido con producto y subtotal. | 0 en ambos sentidos. |
| `vw_tp5_clientes_reportes` | Identificación mínima para reportes. | 0 en ambos sentidos. |

El esquema real no incluye una columna `contraseña`. La última vista aplica el mismo criterio de mínimo privilegio: expone id, nombre, apellido y email, pero no el teléfono. Así se puede otorgar `SELECT` sobre la vista sin conceder acceso a toda la tabla `cliente`.

## Parte C - Vista materializada

`mv_tp5_facturacion_categoria_mes` materializa el reporte de facturación por categoría y mes. Se creó con `WITH DATA` y tiene el índice único `(mes, id_categoria)`, requisito para ejecutar después `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

| Consulta | Plan | Tiempo real |
|---|---|---:|
| Reporte original con cuatro tablas, joins y agregación | `Parallel Seq Scan`, `Parallel Hash Join`, `Gather Merge` y `GroupAggregate` | 550,464 ms |
| Consulta sobre la vista materializada (65 filas) | `Seq Scan` de la vista materializada y `Sort` | 0,067 ms |

La consulta del resumen materializado fue 8.215,88x más rápida porque no recalcula los joins ni las agregaciones.

### Frecuencia de refresco

Para un reporte de gestión diaria, ejecutar una vez por noche:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tp5_facturacion_categoria_mes;
```

La prueba real de `REFRESH MATERIALIZED VIEW CONCURRENTLY` tomó 539,135 ms. `CONCURRENTLY` mantiene disponible la versión anterior durante el refresco, pero los usuarios verán datos desactualizados desde el último refresh. Si el negocio necesitara datos al minuto, esta vista no bastaría por sí sola: habría que aumentar la frecuencia o consultar el reporte original.

## Archivos y defensa oral

- Los índices individuales están en `indices/`; las vistas, en `views/`; la materializada, en `materializadas/`.
- `01_consultas_frecuentes.sql`, `03_medicion_escritura.sql`, `05_equivalencia_views.sql` y `07_medicion_materializada.sql` reproducen las mediciones.
- La defensa se sostiene explicando el filtro de cada índice, el cambio de plan, el costo de insert y la razón de descartar el índice de baja cardinalidad.
