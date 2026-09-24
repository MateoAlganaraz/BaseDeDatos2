# DUIA - TP3 Optimizacion de consultas

## Declaracion transparente

- Herramienta utilizada: Codex / OpenAI (asistencia de redaccion y SQL).
- Uso: proponer una carga masiva reproducible, tres consultas candidatas, indices sujetos a medicion, dos consultas especificadas y controles de equivalencia.
- Control humano obligatorio: leer cada sentencia, ejecutar solo en una copia, verificar planes reales y completar los campos pendientes. Ningun tiempo, plan o afirmacion de uso de indice fue fabricado.

| Herramienta | Para que se uso | Prompt / spec (resumen) | Se acepto o descarto y por que |
|---|---|---|---|
| Codex / OpenAI | Carga masiva | Generar datos PostgreSQL con `generate_series`: >=50k productos, >=20k clientes, >=200k pedidos y detalles, respetando PK/FK/UNIQUE/CHECK dentro de transaccion. | Aceptado y ejecutado en `food_store_tp3_carga`: conteos 20k, 50k, 200k y 400k confirmados. |
| Codex / OpenAI | Q1, Q2 y Q3 | Proponer consultas Food Store medibles y un indice por patron de filtro/orden, sin afirmar mejoras. | Q2 y Q3 aceptados por tiempos reales; Q1 documentado como no mejorado (44.727 ms a 45.011 ms). |
| Codex / OpenAI | Parte 4 | Redactar una spec de resumen y una de subconsulta, con filtros `activo`, columnas, orden y verificacion bidireccional con `EXCEPT`. | Aceptado: los cuatro controles `EXCEPT` devolvieron 0 filas distintas. |
| Codex / OpenAI | Parte 3 | Explicar el plan posterior de Q2 solo con su texto y distinguir costo estimado de tiempo real. | Aceptado: contraste documentado en `lectura_critica_plan.md`; se detecta como imprecision confundir costo con milisegundos. |
| Codex / OpenAI | Parte 5 | Proponer un indice para la consulta comun luego de leer el plan inicial con Seq Scan y Sort. | Aceptado: `idx_tp3_comp_producto_precio_activo` redujo 22.246 ms a 0.549 ms en la copia de competencia. |

## Registro de decisiones despues de ejecutar

| Fecha | Consulta | Propuesta de IA | Evidencia real revisada | Decision y motivo |
|---|---|---|---|---|
| 2026-09-07 | Q1 | indice parcial de producto | 44.727 ms antes; 45.011 ms despues | Descartado como mejora: el indice se uso, pero el tiempo total aumento levemente. |
| 2026-09-07 | Q2 | indice de forma de pago y fecha | 26.940 ms antes; 0.553 ms despues | Aceptado: Index Scan sin Sort, mejora 48.72x. |
| 2026-09-07 | Q3 | indice de fecha de pedido | 68.061 ms antes; 52.491 ms despues | Aceptado: Bitmap Index Scan temporal, mejora 1.30x. |
| 2026-09-07 | Parte 5 | indice parcial por precio e identificador | 22.246 ms antes; 0.549 ms despues | Aceptado: Index Only Scan, mejora 40.52x. |
