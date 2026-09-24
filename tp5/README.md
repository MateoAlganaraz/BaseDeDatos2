# TP5 - Índices, vistas y vistas materializadas

Resolución de Unidad 3, Semana 1 sobre la base masiva heredada de TP3. Se usa el esquema real del repositorio: `cliente`, `categoria`, `producto`, `pedido` y `detalle_pedido`. No se alteran tablas, claves ni restricciones; se agregan índices y vistas solamente en una copia aislada.

## Bases de laboratorio

- `food_store_tp5_base`: mediciones sin los índices nuevos de este TP.
- `food_store_tp5_indices_vistas`: índices, vistas y vista materializada de TP5.

Ambas copias provienen de `food_store_tp3_mediciones`. Nunca ejecutar estos scripts sobre `practica_bd2` ni sobre una base usada por otro TP.

## Orden de ejecución

1. Ejecutar `00_preflight.sql` en ambas copias y guardar el resultado.
2. En `food_store_tp5_base`, ejecutar `01_consultas_frecuentes.sql` y `03_medicion_escritura.sql` para guardar el estado inicial.
3. En `food_store_tp5_indices_vistas`, crear cada índice de `indices/` en el orden indicado por `indices.sql`; luego ejecutar `01_consultas_frecuentes.sql` y `03_medicion_escritura.sql`.
4. En `food_store_tp5_indices_vistas`, ejecutar `views.sql`, `05_equivalencia_views.sql`, `materializadas.sql` y `07_medicion_materializada.sql`.
5. Completar o revisar `informe_mediciones.md` y `duia.md` solo con resultados que estén en `evidencia/`. La verificación posterior del TPI se conserva en `evidencia/20260923_tpi/`.

Para DBeaver, usar los archivos de `dbeaver/`, que no incluyen metacomandos de `psql`.

## Carga de trabajo elegida

| Consulta frecuente | Tabla grande sin índice específico al inicio | Decisión prevista |
|---|---|---|
| Detalles de ventas de un producto puntual | `detalle_pedido` (400.000 filas) | Índice compuesto por producto y pedido. |
| Autocompletado del catálogo de productos activos | `producto` (50.000 filas) | Índice parcial de prefijo sobre nombre. |
| Búsqueda de clientes por apellido | `cliente` (20.000 filas) | Índice de prefijo sobre apellido. |

Las especificaciones están en `specs/`. El uso real de Codex/OpenCode se registra en `registro_codex.md` y `duia.md`; los resultados y decisiones finales quedan trazados en `informe_mediciones.md`.
