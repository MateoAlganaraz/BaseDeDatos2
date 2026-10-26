# TP6 - Unidad 4: Forma Normal de Boyce-Codd y desnormalización controlada

Resolución del Trabajo Práctico de la Unidad 4 sobre Food Store. La Parte 1 lleva a FNBC la extensión mayorista `control_lote_almacen`; la Parte 2 desnormaliza de forma deliberada el reporte "top 5 de categorías por monto vendido en el día". Ninguna decisión se toma por intuición: la Parte 1 se apoya en dependencias funcionales y clausuras, y la Parte 2 en `EXPLAIN (ANALYZE, BUFFERS)` ejecutado sobre PostgreSQL.

Todas las cifras de este documento salen de las salidas reales guardadas en `evidencia/` (PostgreSQL 16.15, base de laboratorio `food_store_tp6_lab`).

## Entregables

| Consigna | Archivo |
|---|---|
| 1. Script Parte 1 | [`tp_fnbc_control_lote.sql`](tp_fnbc_control_lote.sql): esquema original, instancia de ejemplo, anomalías, tablas descompuestas, vista de compatibilidad, migración verificada y pruebas. |
| 2. Script Parte 2 | [`tp_desnormalizacion_top_categorias.sql`](tp_desnormalizacion_top_categorias.sql): consulta original medida, estructura desnormalizada, disparadores de sincronización, consulta 5.2(d), equivalencia, auditoría 5.2(e) y pruebas de sincronización. |
| 3. Informe breve | [`DB_Mateo_Algañaraz.pdf`](DB_Mateo_Algañaraz.pdf) (generado con `build_informe_pdf.py`). Este README contiene la misma resolución en texto. |

Archivos de apoyo:

| Archivo | Contenido |
|---|---|
| `00_carga_laboratorio.sql` | Prerrequisito de borrado lógico y carga de una instancia razonablemente poblada (600.000 pedidos, 1.500.000 detalles). |
| `01_mediciones_repetidas.sql` | 30 ejecuciones por consulta (mínimo / mediana / máximo), alternativa "solo índice" y costo de escritura de los disparadores. Todo reversible. |
| `evidencia/00_carga_laboratorio.txt` | Salida de la carga y volúmenes. |
| `evidencia/01_fnbc_control_lote.txt` | Salida completa de la Parte 1. |
| `evidencia/02_desnormalizacion_top_categorias.txt` | Salida completa de la Parte 2: planes antes y después, equivalencia, auditoría y pruebas. |
| `evidencia/03_mediciones_repetidas.txt` | Mediciones repetidas y costo de escritura. |
| `dbeaver/` | Los mismos scripts sin metacomandos de `psql`, para ejecutar en DBeaver. |

## Ejecución

Siempre sobre una copia de laboratorio, nunca sobre `practica_bd2` (ver `../protocolo_seguridad.md`).

```bash
createdb food_store_tp6_lab
psql -X -d food_store_tp6_lab -f schema.sql
psql -X -v ON_ERROR_STOP=1 -d food_store_tp6_lab -f tp6/tp_fnbc_control_lote.sql
psql -X -v ON_ERROR_STOP=1 -d food_store_tp6_lab -f tp6/00_carga_laboratorio.sql
psql -X -v ON_ERROR_STOP=1 -d food_store_tp6_lab -f tp6/tp_desnormalizacion_top_categorias.sql
psql -X -v ON_ERROR_STOP=1 -d food_store_tp6_lab -f tp6/01_mediciones_repetidas.sql
python tp6/build_informe_pdf.py
```

La Parte 1 trabaja en un esquema aislado `mayorista` y es idempotente (lo reconstruye en cada ejecución). La Parte 2 crea un único objeto de datos nuevo (`resumen_venta_diaria_categoria`) y sus disparadores; las pruebas terminan en `ROLLBACK`.

---

## Parte 1 - FNBC sobre `control_lote_almacen`

Esquema: `R(LoteID, DepositoID, ResponsableControlID)`, con `PRIMARY KEY (lote_id, deposito_id)`.

La consigna asume que `lote` y `deposito` ya existen; el esquema del repositorio no las tiene, ni tampoco `usuario`. El script crea en el esquema `mayorista` las tres tablas maestras mínimas para que las `FOREIGN KEY` de la consigna sean válidas, y luego crea `control_lote_almacen` exactamente como está enunciada.

### a) Dependencias funcionales

De la regla de negocio:

- **DF1:** `{LoteID, DepositoID} → {ResponsableControlID}` (para un lote y un depósito interviniente, el responsable queda unívocamente determinado).
- **DF2:** `{ResponsableControlID} → {DepositoID}` (cada responsable pertenece a un único depósito).

No hay más dependencias no triviales: `LoteID` no determina nada por sí solo (un lote grande se controla desde varios depósitos) y `DepositoID` tampoco (un depósito tiene varios responsables y varios lotes).

### b) Clausuras y claves candidatas

`LoteID` no aparece en el lado derecho de ninguna DF, por lo tanto debe estar en toda clave candidata.

| Conjunto X | X⁺ | ¿Superclave? |
|---|---|---|
| {LoteID} | {LoteID} | No |
| {DepositoID} | {DepositoID} | No |
| {ResponsableControlID} | {ResponsableControlID, DepositoID} | No |
| {LoteID, DepositoID} | {LoteID, DepositoID, ResponsableControlID} (por DF1) | **Sí, y mínima** |
| {LoteID, ResponsableControlID} | {LoteID, ResponsableControlID, DepositoID} (por DF2) | **Sí, y mínima** |
| {DepositoID, ResponsableControlID} | {DepositoID, ResponsableControlID} | No (falta LoteID) |

Ambas superclaves de dos atributos son mínimas porque ninguno de sus subconjuntos de un atributo es superclave. Cualquier conjunto de tres atributos contiene a una de ellas, así que no es mínimo.

**Claves candidatas (conjunto completo):** `{LoteID, DepositoID}` y `{LoteID, ResponsableControlID}`.

**Atributos primos:** `LoteID`, `DepositoID` y `ResponsableControlID` (los tres pertenecen a alguna clave candidata). **No primos:** ninguno.

### c) ¿Cumple FNBC?

Definición: R está en FNBC si para toda DF no trivial `X → Y` que vale en R, `X` es superclave de R.

- DF1: `{LoteID, DepositoID}` es clave candidata → cumple.
- **DF2: `{ResponsableControlID} → {DepositoID}` viola FNBC.** Es no trivial (DepositoID ∉ {ResponsableControlID}) y su determinante no es superclave: `{ResponsableControlID}⁺ = {ResponsableControlID, DepositoID} ≠ R`, porque no determina `LoteID`. La instancia lo muestra: el responsable 801 aparece en dos filas (lotes 501 y 502), por lo que no identifica una fila.

**Conclusión: `control_lote_almacen` no está en FNBC.** (Sí está en 3FN, porque `DepositoID` es primo; justamente por eso la definición de 3FN no detecta el problema y hay que usar la de FNBC.)

Evidencia (`evidencia/01_fnbc_control_lote.txt`, sección 2): las consultas que buscan contraejemplos de DF1 y DF2 devuelven `0` y `0`, y el conteo por responsable muestra a 801 en 2 filas y 2 lotes distintos.

### d) Anomalías sobre la instancia de ejemplo

Cada escenario se ejecutó en el script dentro de `BEGIN ... ROLLBACK` (sección 3 de la evidencia).

**Actualización.** El hecho "801 pertenece al depósito 30" está guardado dos veces (filas de los lotes 501 y 502). Si logística traslada a 801 al depósito 32 y se actualiza solo la fila del lote 501, la tabla acepta el cambio y queda registrando que 801 pertenece a los depósitos 30 y 32 a la vez, contradiciendo DF2. Evidencia: tras el `UPDATE`, la consulta de control devuelve `801 | {30,32}`.

**Inserción.** Si se incorpora a la dotación la responsable 803 en el depósito 31, no hay forma de registrarlo hasta que se le asigne un lote: `lote_id` es parte de la clave primaria y es `NOT NULL`. Evidencia: `null value in column "lote_id" ... violates not-null constraint`. Además, la tabla acepta un lote nuevo con un responsable ya asignado a otro depósito, porque la PK solo controla DF1: `INSERT (504, 31, 801)` se acepta y 801 pasa a figurar en `{30,31}`.

**Borrado.** Cuando termina el control del lote 503 y se borra su fila, se pierde el único registro de que 802 pertenece al depósito 31. Evidencia: tras el `DELETE`, la cantidad de filas que registran a 802 es `0`.

### e) Descomposición sin pérdida y script

Algoritmo de descomposición FNBC: tomando la DF violatoria `X → Y` con `X = {ResponsableControlID}`, se reemplaza R por

- `R1 = X⁺ = (ResponsableControlID, DepositoID)` → tabla `responsable_deposito`, PK `responsable_control_id`.
- `R2 = R − (X⁺ − X) = (LoteID, ResponsableControlID)` → tabla `control_lote_responsable`, PK `(lote_id, responsable_control_id)`.

Verificación de FNBC de cada parte: en R1 la única DF no trivial proyectada es DF2 y su determinante es la clave de R1; en R2 no queda ninguna DF no trivial (DF1 no se proyecta porque `DepositoID ∉ R2`), así que la única clave es el par completo. Ambas están en FNBC y el algoritmo termina.

Restricciones (script, sección 4):

- `responsable_deposito`: PK `(responsable_control_id)`; FK a `usuario(id)` y a `deposito(id)`. La PK hace cumplir DF2: un responsable no puede tener dos depósitos.
- `control_lote_responsable`: PK `(lote_id, responsable_control_id)`; FK a `lote(id)` y FK a `responsable_deposito(responsable_control_id)`, que obliga a que todo responsable que controla un lote tenga depósito asignado.
- Vista de compatibilidad `vw_control_lote_almacen`: `SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_responsable NATURAL JOIN responsable_deposito`.

**Dependencia no preservada.** Como en todo caso de esta forma, la descomposición FNBC no preserva DF1: sus tres atributos ya no están en una misma tabla. Para no perder la regla de negocio se la controla con disparadores: `trg_control_lote_un_responsable_por_deposito` impide asignar a un lote un segundo responsable del mismo depósito (bloquea la fila del lote para serializar altas concurrentes) y `trg_responsable_cambio_deposito` impide mover a un responsable a un depósito donde eso duplicaría el responsable de alguno de sus lotes. Se descartó la alternativa de guardar `deposito_id` también en R2 con `UNIQUE (lote_id, deposito_id)`: reintroduce DF2 dentro de R2 y la tabla volvería a violar FNBC.

### f) Justificación de la reunión sin pérdida, migración y verificación

Criterio: una descomposición de R en R1 y R2 es sin pérdida si el atributo común `R1 ∩ R2` determina funcionalmente a R1 o a R2 (es superclave de alguna de las dos). Aquí `R1 ∩ R2 = {ResponsableControlID}` y `{ResponsableControlID} → {DepositoID}` (DF2), así que `{ResponsableControlID}⁺ ⊇ R1`: el atributo común es clave de R1. Por lo tanto cada fila de R2 se combina con exactamente una fila de R1 en la reunión natural y `R1 ⋈ R2 = R`, sin tuplas espurias.

Migración (script, sección 5): primero se verifica que la instancia cumple DF2 (si un responsable tuviera dos depósitos, la migración aborta en vez de elegir uno arbitrariamente); luego `R1` y `R2` se cargan como proyecciones `SELECT DISTINCT` de la tabla original, en una transacción.

Resultado verificado (`evidencia/01_fnbc_control_lote.txt`, sección 5):

| Control | Resultado |
|---|---:|
| `control_lote_almacen EXCEPT vw_control_lote_almacen` | 0 |
| `vw_control_lote_almacen EXCEPT control_lote_almacen` | 0 |
| Filas en la tabla original | 3 |
| Filas en la vista | 3 |

`responsable_deposito` quedó con `(801, 30)` y `(802, 31)`; `control_lote_responsable` con `(501, 801)`, `(502, 801)` y `(503, 802)`.

Pruebas sobre el esquema descompuesto (sección 6, todas revertidas): 803 se registra en el depósito 31 sin lote; el traslado de 801 se hace en una sola fila y la vista lo refleja en sus dos lotes; borrar el control del lote 503 conserva `(802, 31)`; un segundo depósito para 801 es rechazado por la PK; un segundo responsable del depósito 30 para el lote 501 es rechazado por el disparador; el fraccionamiento válido (501 controlado por 801 desde el depósito 30 y por 802 desde el 31) se acepta.

---

## Parte 2 - Top 5 de categorías por monto vendido en el día

### Adaptación al esquema real

El esquema del repositorio (`schema.sql`) usa nombres propios y no tiene `subtotal` ni `eliminado`. La consulta se tradujo sin cambiar su semántica:

| Consigna | Esquema Food Store |
|---|---|
| `pr.id`, `c.id`, `ped.id` | `id_producto`, `id_categoria`, `id_pedido` |
| `dp.subtotal` | `dp.cantidad * dp.precio_unitario` |
| `eliminado = FALSE` | `deleted_at IS NULL` (convención de borrado lógico del TPI) |
| `ped.fecha = CURRENT_DATE` | `ped.fecha >= CURRENT_DATE AND ped.fecha < CURRENT_DATE + 1` (`fecha` es `TIMESTAMPTZ`; día de negocio en `America/Argentina/Buenos_Aires`) |

`pedido` y `detalle_pedido` no tenían borrado lógico; `00_carga_laboratorio.sql` agrega `deleted_at TIMESTAMPTZ` a ambas (con `ADD COLUMN IF NOT EXISTS`, también repetido al inicio del script de la Parte 2).

Instancia medida (`evidencia/00_carga_laboratorio.txt`): 12 categorías, 10.000 productos, 20.000 clientes, 600.000 pedidos en los últimos 365 días (12.000 con baja lógica), 1.500.000 detalles (6.186 con baja lógica) y 1.643 pedidos del día.

### a) Medición de la consulta original

`EXPLAIN (ANALYZE, BUFFERS)` (`evidencia/02_desnormalizacion_top_categorias.txt`):

- **Execution Time: 33,129 ms.**
- **Nodo dominante: `Parallel Seq Scan on pedido`**, 20,062 ms de los 25,439 ms que tarda el subárbol de joins en cada proceso (≈ 79 %). Recorre los 600.000 pedidos para quedarse con 1.643: `Rows Removed by Filter: 199452` en cada uno de los 3 procesos. No hay índice que permita filtrar por fecha.
- Después, para cada pedido del día, `Nested Loop` con `Index Scan using pk_detalle_pedido` (1.643 búsquedas) y otro `Nested Loop` con `Index Scan using producto_pkey` (4.091 búsquedas), `Hash Join` con categoría, `Sort` + `Partial GroupAggregate`, `Gather Merge` y `Sort` top-N.

Con 30 ejecuciones (`evidencia/03_mediciones_repetidas.txt`): mínimo 28,197 ms, **mediana 28,695 ms**, máximo 32,629 ms.

### b) Patrón elegido y justificación

Se eligió una **tabla resumen precalculada mantenida por disparadores** (`resumen_venta_diaria_categoria`, una fila por día y categoría). La evidencia de (a) muestra que casi todo el costo es encontrar los pedidos del día recorriendo 600.000 filas y luego resolver tres joins y una agregación sobre miles de detalles, y ese trabajo se repite completo en cada una de las muchas ejecuciones por minuto del panel, aunque entre dos ejecuciones apenas cambien unos pocos pedidos; un índice sobre `pedido(fecha)`, medido como alternativa, solo baja la mediana a 8,556 ms porque sigue uniendo y agregando 4.091 detalles por consulta. La vista materializada se descartó porque el panel exige datos en tiempo real: entre refrescos mostraría montos viejos y cada `REFRESH` recalcula los 1.500.000 detalles. La sincronización la garantizan disparadores `AFTER ... FOR EACH STATEMENT` sobre `detalle_pedido` (alta, modificación, baja física y `TRUNCATE`), `pedido` (cambio de fecha o de baja lógica) y `producto` (cambio de categoría), que aplican en la misma transacción un delta agregado con `INSERT ... ON CONFLICT DO UPDATE`: si la transacción falla, el resumen se revierte con ella; además, el script de auditoría de (e) compara el resumen contra la fuente. Es reversible sin pérdida: la fuente de verdad no se modifica, el resumen se reconstruye en cualquier momento con `fn_tp6_reconstruir_resumen()` y eliminarlo (`DROP TABLE resumen_venta_diaria_categoria CASCADE` y las funciones `fn_tp6_*`) deja el esquema como estaba sin perder ningún dato.

### c) Implementación

En `tp_desnormalizacion_top_categorias.sql`, sección 2:

- `fn_tp6_dia_negocio(timestamptz)`: día calendario en Buenos Aires, independiente de la zona horaria de la sesión que escriba.
- `resumen_venta_diaria_categoria (dia, id_categoria, total_vendido, lineas, actualizado_en)`, PK `(dia, id_categoria)`, FK a `categoria`. `lineas` cuenta los detalles vigentes: `lineas = 0` significa "sin ventas" y permite no mostrar la categoría, igual que la consulta original.
- `fn_tp6_reconstruir_resumen()`: carga inicial (4.380 filas = 365 días × 12 categorías) y recuperación, ejecutada con `LOCK TABLE ... IN SHARE ROW EXCLUSIVE MODE` para que ninguna escritura concurrente quede fuera.
- Disparadores por sentencia con tablas de transición (`REFERENCING OLD/NEW TABLE`): una carga masiva genera un solo upsert agregado por (día, categoría). Los upserts se ordenan por clave para reducir riesgo de interbloqueo y, si algún contador quedara negativo, la sentencia falla.
- Se agrupa por la categoría **actual** del producto, igual que la consulta original; por eso recategorizar un producto mueve sus ventas históricas de una categoría a otra.

### d) Consulta sobre la estructura desnormalizada y comparación

```sql
SELECT c.nombre AS categoria, r.total_vendido
FROM resumen_venta_diaria_categoria r
JOIN categoria c ON c.id_categoria = r.id_categoria
WHERE r.dia = CURRENT_DATE AND r.lineas > 0
ORDER BY r.total_vendido DESC
LIMIT 5;
```

Devuelve exactamente el mismo top 5 que la original (Almacén 4.087.354,00; Bebidas 2.391.258,00; Golosinas 2.198.330,00; Mascotas 2.188.757,00; Snacks 2.136.491,00). Además, con `EXCEPT` en ambos sentidos y sin `LIMIT`, las 12 categorías del día y las del acumulado de 7 días coinciden: los cuatro controles devuelven `0`. El script incluye una segunda consulta que reutiliza el resumen para el top 5 de los últimos 7 días (0,104 ms).

| | Antes (4 tablas) | Después (resumen) |
|---|---|---|
| Execution Time, `EXPLAIN (ANALYZE, BUFFERS)` | 33,129 ms | 0,037 ms |
| Mediana de 30 ejecuciones | 28,695 ms | 0,017 ms |
| Nodo dominante | `Parallel Seq Scan on pedido` (600.000 filas leídas, 1.643 útiles) | `Bitmap Heap Scan on resumen_venta_diaria_categoria` vía `Bitmap Index Scan on pk_resumen_venta_diaria_categoria` (12 filas) |
| Buffers | 3.702 hit + 810 read solo en `pedido`; 22.645 hit + 810 read en total | 10 hit |

Mejora: 33,129 / 0,037 ≈ 895x en la ejecución registrada; ≈ 1.688x en mediana.

**Costo de la decisión** (`evidencia/03_mediciones_repetidas.txt`, 10 repeticiones revertidas): insertar 1.000 detalles en 400 pedidos nuevos pasa de una mediana de 8,485 ms sin el disparador a 10,889 ms con él (+2,4 ms, ≈ 28 %). Se acepta porque el reporte se lee muchas veces por minuto y cada lectura ahorra ≈ 28 ms. El otro costo es de concurrencia: las ventas del mismo día y categoría actualizan la misma fila del resumen, por lo que esas transacciones se serializan sobre ella hasta su `COMMIT`; con 12 categorías es aceptable para el volumen de Food Store, y si fuera un cuello de botella podría repartirse cada (día, categoría) en varias filas parciales.

### e) Auditoría

Sección 4 del script: recalcula desde `detalle_pedido`, `pedido` y `producto` el total y la cantidad de líneas por día y categoría, y lo compara con `FULL JOIN` contra el resumen (una fila con `lineas = 0` cuenta como "sin ventas"). Devuelve cada (día, categoría) con diferencias o con valores negativos.

Ejecutada sobre la base migrada: **0 filas**.

Pruebas de sincronización (sección 5, dentro de una transacción revertida, auditando después de cada operación): alta de un pedido con 3 detalles, cambio de cantidad, baja lógica de un detalle, cambio de fecha del pedido a ayer y de vuelta a hoy, baja lógica de 100 pedidos del día, recategorización de un producto con ventas y borrado físico de detalles y pedido: **0 diferencias en todos los casos**. Como control negativo se alteró el resumen a mano y la auditoría devolvió **1** diferencia, lo que muestra que la auditoría detecta una desincronización real. Tras el `ROLLBACK`, la auditoría final vuelve a dar 0.

---

## Declaración de uso de IA

Se usó Claude (Anthropic) como asistente para redactar los scripts SQL, el generador de datos y este informe. Todas las afirmaciones se verificaron ejecutando los scripts en PostgreSQL 16.15; los números provienen de las salidas en `evidencia/`. Las decisiones de diseño (DF, claves, descomposición, patrón de desnormalización) se justificaron con esas salidas y no se aceptó ningún resultado que no estuviera respaldado por ellas.
