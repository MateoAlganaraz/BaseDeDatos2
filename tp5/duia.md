# DUIA - TP5: índices, vistas y vista materializada

## Registro de uso de IA y decisiones

| Herramienta | Propósito | Prompt o spec conservado | Resultado y decisión |
|---|---|---|---|
| OpenCode, sesión `ses_f31719b28ffeDr69oZrSEcV7Qg` | Leer las tres specs de índices sin editar archivos ni ejecutar SQL. | “Proponé sentencias `CREATE INDEX` precisas y un índice descartado por sobreindexación.” | Propuso los tres `CREATE INDEX` finalmente medidos: detalle por producto, nombre activo con `text_pattern_ops` y apellido con `text_pattern_ops`. Se aceptaron solo después de leer el SQL y verificar los planes; el índice aislado sobre `producto.activo` se descartó por baja cardinalidad. |
| Codex / OpenAI | Especificar los objetos antes de generar SQL, preparar scripts PostgreSQL/DBeaver, revisar sintaxis y contrastar planes antes/después. | “A partir del esquema real Food Store, definir tres consultas con `Seq Scan`, sus criterios de aceptación, vistas equivalentes y una vista materializada; no aceptar cambios sin medición.” | Se conservaron cinco specs y un registro de Codex. Se aceptaron tres índices tras ver `Bitmap Index Scan` o `Index Only Scan`; se rechazó el índice aislado sobre `producto.activo` por baja cardinalidad. |
| Codex / OpenAI | Definir vistas y comprobaciones formales. | `specs/04_vistas_reportes.md`: columnas, filtros y mínimo privilegio. | Cuatro vistas creadas. Los ocho controles de equivalencia con `EXCEPT` devolvieron 0. |
| Codex / OpenAI | Diseñar el reporte materializado y su refresco. | `specs/05_vista_materializada.md`: facturación mensual, `WITH DATA` e índice único. | Se aceptó la materializada: 550,464 ms para el reporte original frente a 0,067 ms en el resumen. |

## Registro de especificación con Codex

El flujo aplicado fue: especificar en `specs/`, generar propuestas con Codex/OpenCode, leer el SQL y medirlo en copias aisladas de PostgreSQL antes de aceptarlo. `registro_codex.md` documenta las interacciones reales y sus resultados verificables en el repositorio.

El repositorio no declara como aceptada ninguna propuesta que no haya sido comprendida y medida en PostgreSQL.
