# TP4 - Reportes analiticos asistidos por IA sobre Food Store

Esta carpeta contiene la resolución reproducible del TP4 sobre el esquema Food Store: `cliente`, `categoria`, `producto`, `pedido` y `detalle_pedido`. La evaluación se basa en planes medidos; los índices que no produjeron un cambio justificable se conservaron como propuestas descartadas, no como mejoras declaradas.

## Estructura y ejecución

| Archivo | Contenido |
|---|---|
| `00_preflight.sql` | Comprobaciones iniciales de la copia de laboratorio. |
| `01_consultas_analiticas.sql` | Q1, Q2 y Q3 con `EXPLAIN (ANALYZE, BUFFERS)`. |
| `02_indices.sql` | Tres índices candidatos y `ANALYZE`. |
| `03_specs_equivalencia.sql` | Dos especificaciones, alternativas SQL y controles `EXCEPT`. |
| `04_consulta_comun_competencia.sql` | Consulta común de competencia: Q3. |
| `05_validacion.sql` | Controles de integridad y equivalencia. |
| `evidencia/` | Salidas completas de PostgreSQL antes y después. |
| `lectura_critica_plan.md` | Parte 2: lectura de Q3 y contraste con la IA. |
| `plantillas_evidencia.md` | Tablas finales de resultados reales. |
| `duia_tp4.md` | Declaración de Uso de IA completa. |

Se ejecutó sobre copias aisladas de la base masiva del TP3, nunca sobre `practica_bd2`. Para repetir la medición: ejecutar `01_consultas_analiticas.sql`, guardar la salida como estado inicial, aplicar `02_indices.sql` y volver a ejecutar el mismo archivo. Los scripts en `dbeaver/` no incluyen metacomandos de `psql`.

## Parte 1 - consultas analíticas y medición

Las consultas Q1 y Q2 usan la ventana de los 90 días previos a `max(pedido.fecha)`, que es la ventana exacta de las salidas almacenadas. Todas cruzan al menos cuatro tablas y usan agregación; Q2 además usa `RANK()`.

| Consulta | Algoritmos antes | Cambio aplicado | Algoritmos después | Tiempo antes | Tiempo después | Resultado |
|---|---|---|---|---:|---:|---|
| Q1 Facturación por categoría y mes | `Parallel Hash Join` detalle-pedido y detalle-producto; `Hash Join` producto-categoría | Índices por fecha de pedido y cobertura de detalle | Tres `Hash Join`; persiste `Seq Scan` sobre detalle | 392,846 ms | 424,434 ms | 0,93x. Rechazado: el plan no usó los índices nuevos y empeoró. |
| Q2 Ranking de clientes por gasto | Tres `Hash Join`, `HashAggregate` y `WindowAgg`; `Seq Scan` sobre detalle | Misma hipótesis de índices | Tres `Hash Join`, `HashAggregate` y `WindowAgg`; mismo acceso relevante | 402,742 ms | 334,318 ms | 1,20x observado, no aceptado como causal: no cambió el nodo de join ni el acceso a detalle. |
| Q3 Ventas mensuales del producto 100001 | `Parallel Seq Scan` sobre detalle y `Nested Loop` | `idx_tp4_detalle_producto_pedido` | `Index Only Scan` sobre detalle y `Nested Loop` | 65,141 ms | 0,460 ms | 141,61x. Aceptado: el acceso selectivo reemplazó el recorrido completo de detalle. |

Las salidas completas de Q1 y Q2 están en `evidencia/20260915_205300/01_planes_antes.txt` y `03_planes_despues.txt`. Las de Q3 están en `evidencia/20260915_producto/q_producto_antes.txt` y `q_producto_despues.txt`.

Los índices propuestos fueron:

- `idx_tp4_pedido_fecha_id_cliente (fecha DESC, id_pedido) INCLUDE (id_cliente)`.
- `idx_tp4_detalle_pedido_cobertura (id_pedido) INCLUDE (id_producto, cantidad, precio_unitario)`.
- `idx_tp4_detalle_producto_pedido (id_producto, id_pedido) INCLUDE (cantidad, precio_unitario)`, aceptado únicamente para Q3.

## Parte 2 - lectura crítica

Se eligió Q3 porque el plan posterior conserva varios joins y muestra el cambio de acceso real. La interpretación, el prompt y el contraste están en `lectura_critica_plan.md`. El punto central es no confundir `cost` con milisegundos: el tiempo verificable es `Execution Time`.

## Parte 3 - especificaciones y equivalencia

`03_specs_equivalencia.sql` fija dos especificaciones completas:

1. Ranking de clientes por gasto: tablas `cliente`, `pedido`, `detalle_pedido` y `producto`; una fila por cliente; gasto de los últimos 90 días; productos activos; `RANK()` por gasto descendente y desempate final por `id_cliente`.
2. Productos activos sin ventas: tablas `categoria`, `producto`, `detalle_pedido` y `pedido`; categorías y productos activos; sin ventas en los últimos 90 días; orden por categoría, producto e identificador.

Cada spec se implementó con dos estructuras distintas y se comparó en ambos sentidos con `EXCEPT`. Los cuatro controles devolvieron `0`; la salida está en `evidencia/20260915_205300/05_validacion.txt`.

## Parte 4 - competencia y DUIA

La consulta común es Q3: combina producto, categoría, detalle y pedido, con agregación mensual. La estrategia aceptada fue el índice inverso desde `id_producto` hacia `detalle_pedido`; pasó de 65,141 ms a 0,460 ms (141,61x). `duia_tp4.md` registra tanto Q1/Q2 descartados como Q3 aceptado, y `plantillas_evidencia.md` concentra las tablas solicitadas.

El archivo para subir a la plataforma es `DB_Mateo_Algañaraz.pdf`.
