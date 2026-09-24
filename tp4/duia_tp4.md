# DUIA - TP4: reportes analíticos y optimización de joins

## Declaración transparente

Herramienta de asistencia: Codex / OpenAI. Se usó para formular consultas, proponer índices candidatos, producir alternativas de las specs y explicar un plan real. Cada propuesta se leyó y se contrastó con `EXPLAIN (ANALYZE, BUFFERS)` en una copia de laboratorio antes de decidir.

| Herramienta | Para qué se usó | Prompt o spec resumido | Decisión basada en evidencia |
|---|---|---|---|
| Codex / OpenAI | Q1 y Q2 | Proponer consultas con cuatro tablas, agregación y ranking, e índices que redujeran el join desde pedido hacia detalle. | Los índices se crearon y midieron. Q1 empeoró de 392,846 ms a 424,434 ms; se rechazó. Q2 bajó de 402,742 ms a 334,318 ms, pero mantuvo tres `Hash Join` y el `Seq Scan` relevante; no se aceptó una relación causal con el índice. |
| Codex / OpenAI | Q3 e índice puntual | Proponer un acceso selectivo para ventas mensuales de `id_producto = 100001` y justificarlo con el plan. | Aceptado: `idx_tp4_detalle_producto_pedido` reemplazó `Parallel Seq Scan` por `Index Only Scan`; 65,141 ms a 0,460 ms (141,61x). |
| Codex / OpenAI | Parte 2 | Explicar Q3 nodo por nodo, identificando entradas de cada `Nested Loop` y separando costos de tiempos. | Aceptado tras contrastar cada afirmación con `q_producto_despues.txt`; la explicación y correcciones están en `lectura_critica_plan.md`. |
| Codex / OpenAI | Parte 3 | Generar una alternativa estructural para un ranking y otra para una subconsulta correlacionada. | Aceptado porque los cuatro controles bidireccionales con `EXCEPT` devolvieron 0. |
| Codex / OpenAI | Competencia | Proponer una estrategia para una consulta común con cuatro tablas y agregación. | Se usó Q3 como consulta común. Se descartaron las hipótesis generales de Q1/Q2 y se aceptó solo el índice selectivo de Q3. |

## Registro de decisiones después de medir

| Fecha | Consulta | Propuesta de IA | Evidencia real revisada | Decisión y motivo |
|---|---|---|---|---|
| 2026-09-15 | Q1 facturación por categoría y mes | Índice temporal de pedido y cobertura de detalle. | 392,846 ms antes; 424,434 ms después. Persistieron `Hash Join` y `Seq Scan` sobre detalle. | Rechazado: empeoró y no hay nodo que justifique el índice. |
| 2026-09-15 | Q2 ranking de clientes por gasto | Misma cobertura por fecha y detalle. | 402,742 ms antes; 334,318 ms después. Persistieron los tres `Hash Join` y el acceso completo a detalle. | No aceptado como mejora causada por el índice: el cambio temporal no vino acompañado de un cambio de plan relevante. |
| 2026-09-15 | Q3 ventas mensuales de producto 100001 | `idx_tp4_detalle_producto_pedido` con cobertura de cantidad y precio. | `Parallel Seq Scan`: 65,141 ms. `Index Only Scan`: 0,460 ms. | Aceptado: 141,61x con el mismo reporte y filtro. |
| 2026-09-15 | Competencia | Índice inverso por producto sobre detalle. | La misma comparación antes/después de Q3: 65,141 ms y 0,460 ms. | Aceptado: mejor tiempo real y cambio de acceso verificable. |
