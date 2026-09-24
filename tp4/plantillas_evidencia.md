# TP4 - Evidencia y resultados reales

Los tiempos son `Execution Time` de `EXPLAIN (ANALYZE, BUFFERS)`, no estimaciones `cost`. Los archivos con los planes completos se indican en cada sección.

## Parte 1 - medición antes y después

| Consulta | Algoritmo(s) de join antes | Cambio aplicado | Algoritmo(s) de join después | Antes (ms) | Después (ms) | Mejora | Decisión |
|---|---|---|---|---:|---:|---:|---|
| Q1 Facturación por categoría y mes | `Parallel Hash Join` (detalle-pedido y detalle-producto), `Hash Join` (producto-categoría) | Índice por fecha de pedido y cobertura de detalle | Tres `Hash Join`; `Seq Scan` de detalle | 392,846 | 424,434 | 0,93x | Rechazado: no se usó el índice nuevo y empeoró. |
| Q2 Ranking de clientes por gasto | Tres `Hash Join`; `HashAggregate` y `WindowAgg` | Misma hipótesis de cobertura | Tres `Hash Join`; `HashAggregate` y `WindowAgg` | 402,742 | 334,318 | 1,20x | No aceptado como causal: no cambió el join ni el acceso relevante. |
| Q3 Ventas mensuales de producto 100001 | `Parallel Seq Scan` de detalle y `Nested Loop` | `idx_tp4_detalle_producto_pedido` | `Index Only Scan` de detalle y `Nested Loop` | 65,141 | 0,460 | 141,61x | Aceptado: menos lectura y cambio verificable de acceso. |

- Q1 y Q2 antes: `evidencia/20260915_205300/01_planes_antes.txt`.
- Q1 y Q2 después: `evidencia/20260915_205300/03_planes_despues.txt`.
- Q3 antes y después: `evidencia/20260915_producto/q_producto_antes.txt` y `q_producto_despues.txt`.

## Parte 3 - equivalencia formal

| Control | Resultado esperado | Resultado real |
|---|---:|---:|
| `spec_1_ia_menos_propia` | 0 | 0 |
| `spec_1_propia_menos_ia` | 0 | 0 |
| `spec_2_ia_menos_propia` | 0 | 0 |
| `spec_2_propia_menos_ia` | 0 | 0 |

La salida de validación está en `evidencia/20260915_205300/05_validacion.txt`.

## Parte 4 - competencia

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora | Nodos que justifican la decisión |
|---|---|---:|---:|---:|---|
| Mateo Algañaraz | Índice `(id_producto, id_pedido)` con `INCLUDE (cantidad, precio_unitario)` sobre `detalle_pedido`. | 65,141 | 0,460 | 141,61x | `Parallel Seq Scan` fue reemplazado por `Index Only Scan`; ambos planes conservan los joins necesarios con producto, categoría y pedido. |
