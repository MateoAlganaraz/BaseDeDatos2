# Design - Food Store en la feria

## Componentes

| Componente | Motor | Archivo | Responsabilidad |
|---|---|---|---|
| Instantánea | PostgreSQL (copia de pruebas) | `servidor/01_v_snapshot_movil.sql` | Vista `movil.v_snapshot_movil`: id, nombre, precio en centavos, stock, disponible y eliminado (lápidas incluidas). Solo lectura. |
| Base de la tablet | SQLite (STRICT) | `movil/schema_sqlite.sql` | `producto_cache`, `pedido_borrador`, `item_borrador`, `cola_sync`, más `snapshot_servidor` y la vista `catalogo_disponible`. |
| Carga | SQLite | `movil/cargar_snapshot.sql` | Reemplaza `snapshot_servidor` con el CSV y actualiza `producto_cache` por UPSERT, sin borrar filas. |
| Semáforo | SQLite | `movil/semaforo.sql` | Un único `UPDATE … FROM` sobre las solicitudes `PENDIENTE`. |
| Orquestación | bash | `run_tp10.sh` | Ejecuta todo desde cero y guarda la evidencia. |

## Decisiones

1. **Precio en centavos (`INTEGER`).** `NUMERIC(12,2)` × 100 es exacto, así que la tablet compara enteros sin errores de redondeo.
2. **Lápidas.** Una baja lógica viaja como fila con `eliminado = true`. La tablet nunca borra filas de `producto_cache`: los borradores las referencian por clave foránea.
3. **Identidad local.** `id_local` y `solicitud_uuid` son UUID v4 validados con `CHECK`. `solicitud_uuid` es la clave de idempotencia: un reenvío choca con la clave primaria.
4. **Estados terminales.** El semáforo solo toca solicitudes `PENDIENTE`, y un `CHECK` exige `evaluada_en` cuando el estado no es `PENDIENTE`. Aceptar un precio nuevo (C2) crea una solicitud nueva y la que quedó en `CONFLICTO` se conserva como registro.
5. **Prioridad de colores.** Rojo (inexistente, no disponible, baja o sin stock) le gana a amarillo (precio distinto). Se calcula con `CASE` sobre `sum()` de condiciones por ítem, con `LEFT JOIN` de `item_borrador` a `snapshot_servidor` para detectar productos inexistentes.
6. **El catálogo manda en la tablet.** Un trigger impide agregar a un borrador un producto que el caché muestra como no disponible o dado de baja.

## Flujo de un caso

`borrador en la tablet → (cambio preparado en la copia del servidor) → \copy de v_snapshot_movil a CSV → cargar_snapshot.sql → semaforo.sql → control final en PostgreSQL`.
