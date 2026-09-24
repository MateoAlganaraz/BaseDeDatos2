# TP3 - Optimizacion de consultas sobre Food Store

Esta entrega implementa el TP3 sobre el esquema real de este repositorio: `cliente`, `categoria`, `producto`, `pedido` y `detalle_pedido`. No contiene planes, tiempos ni capturas inventadas. Los archivos en `evidencia/` se crean solo cuando se ejecuta el runner contra PostgreSQL.

## Seguridad y preparacion

No ejecutar en una base de produccion ni en la base original. Crear una copia, respaldarla y conectarse a ella. Ejemplo orientativo (ajustar nombres y credenciales):

```powershell
pg_dump --format=custom --file backups/food_store_base_antes_tp3.dump food_store_base
createdb --template=food_store_base food_store_tp3_lab
psql --dbname=food_store_tp3_lab -c "SELECT current_database(), current_user;"
```

Verificar que `food_store_tp3_lab` sea la copia correcta antes de continuar. El script de carga solo inserta, nunca elimina, pero una carga de 670.000 filas y sus indices no debe hacerse por accidente en otra base. El marcador `Lote` debe ser unico y contener solamente letras, numeros o `_`.

## Ejecucion reproducible

Con `psql` disponible en `PATH`, desde esta carpeta:

```powershell
.\run_mediciones.ps1 -Database food_store_tp3_lab -Lote SB2026TP3 -PrepararDatos
```

`-PrepararDatos` corre la carga una sola vez. Si esta ya finalizo correctamente, omitirlo para volver a medir o volver a generar los archivos de la Parte 4 y la validacion. El runner se detiene al primer error y conserva la salida real en `tp3/evidencia/<fecha_hora>/`:

- `00_preflight.txt`: base, rol, version, tablas y restricciones verificadas.
- `01_carga_masiva.txt`: carga transaccional, `ANALYZE` y conteos reales.
- `02_planes_antes.txt` y `04_planes_despues.txt`: los tres `EXPLAIN (ANALYZE, BUFFERS)` reales.
- `03_indices_aceptados.txt`: definicion real de los tres indices.
- `05_parte4_consultas_y_except.txt` y `06_validacion.txt`: resultados de Parte 4 y validacion.

Si se prefiere ejecutar manualmente, respetar este orden: `00_preflight.sql`, `01_carga_masiva.sql`, `02_consultas_candidatas.sql` con `tp3_fase=antes`, `03_indices_aceptados.sql`, la misma Parte 2 con `tp3_fase=despues`, `04_parte4_consultas.sql` y `05_validacion.sql`. Pasar siempre `-v tp3_lote=SB2026TP3` a los SQL que lo solicitan.

## Parte 1 - revision de la carga

`01_carga_masiva.sql` inserta, dentro de una unica transaccion, exactamente 50.000 productos, 20.000 clientes, 200.000 pedidos y 400.000 detalles. Usa `generate_series`, mantiene PK, FK, unicidad de email para clientes vigentes y todos los `CHECK` del esquema. Los productos se distribuyen de forma ciclica entre las categorias existentes; sus precios estan entre 500 y 5000 y el stock entre 0 y 200. Si falla un conteo, la transaccion se revierte. Luego del `COMMIT`, ejecuta `ANALYZE` sobre las cuatro tablas afectadas.

Leer `01_carga_masiva.sql` antes de ejecutarlo: el marcador de lote se incorpora a nombres y correos para auditar los datos generados. La comprobacion de lote evita reutilizarlo.

## Parte 2 - tres consultas y decisiones aceptadas

`02_consultas_candidatas.sql` contiene exactamente estas tres consultas: Q1 productos activos por categoria/rango/orden, Q2 pedidos recientes por forma de pago y Q3 productos mas vendidos de los ultimos siete dias. La misma consulta y los mismos parametros se usan antes y despues. Como `current_timestamp` cambia entre archivos, registrar en la tabla el instante que encabeza cada captura y, si se requiere comparacion estricta temporal, ejecutar ambos planes consecutivamente.

`03_indices_aceptados.sql` aplica y verifica:

- `idx_tp3_producto_categoria_precio_activo`: indice parcial para Q1; coincide con categoria, orden de precio e id solo para filas activas, por lo que busca evitar filtrado y sort sobre productos inactivos.
- `idx_tp3_pedido_forma_pago_fecha`: para Q2 restringe primero la forma de pago y recorre fecha descendente, compatible con el filtro y `LIMIT`.
- `idx_tp3_pedido_fecha`: para Q3 permite ubicar primero el rango temporal corto de `pedido` antes de unir detalles.

Estos son motivos para medir, no afirmaciones de que PostgreSQL elegira esos nodos. Completar la tabla con los archivos reales; no usar costo como si fuera milisegundos.

| Consulta | Plan antes: nodo/costo/tiempo real | Cambio aplicado | Plan despues: nodo/costo/tiempo real | Mejora |
|---|---|---|---|---|
| Q1 | Bitmap Heap Scan y Sort; 44.727 ms | indice parcial de producto | Bitmap Index Scan; 45.011 ms | 0.994x; no mejoro |
| Q2 | Parallel Seq Scan y Sort; 26.940 ms | indice forma_pago, fecha | Index Scan; 0.553 ms | 48.72x |
| Q3 | Parallel Seq Scan de pedido; 68.061 ms | indice fecha de pedido | Bitmap Index Scan; 52.491 ms | 1.30x |

## Partes 3, 4 y 5

- Parte 3: `lectura_critica_plan.md` documenta el plan posterior real de Q2 y contrasta una imprecision sobre costo estimado versus tiempo real.
- Parte 4: `04_parte4_consultas.sql` incluye dos specs precisas, SQL IA, alternativa propia y ambos sentidos de `EXCEPT`; los cuatro controles reales devolvieron 0.
- Parte 5: `07_indice_competencia.sql` contiene la estrategia decidida despues del plan comun. El tiempo bajo de 22.246 ms a 0.549 ms en `food_store_tp3_competencia`.

El archivo `plantillas_evidencia.md` indica que se debe incorporar y que no debe afirmarse hasta haberlo ejecutado.
