# TP3 Parte 3 Lectura critica de un plan

Plan elegido: Q2 posterior, guardado en `evidencia/20260907_134508/04_planes_despues.txt`.

## Plan real resumido

PostgreSQL uso `Index Scan using idx_tp3_pedido_forma_pago_fecha on pedido`. El `Index Cond` contiene `forma_pago = 'TARJETA'` y el rango de `fecha`. No aparece un nodo `Sort`, porque el indice ya entrega `fecha DESC`. Devolvio 200 filas con `Execution Time: 0.553 ms`, `Buffers: shared hit=200 read=4` y costo estimado `0.42..143.13`.

## Explicacion de IA contrastada

La IA explico que el indice compuesto restringe la forma de pago y el rango temporal, y que el orden descendente de fecha permite satisfacer el `ORDER BY ... LIMIT 200` sin ordenar un conjunto grande. Tambien indico que el costo es una estimacion y que el tiempo real debe tomarse de `Execution Time`.

| Afirmacion de la IA | Correcta? | Correccion o evidencia exacta del plan real |
|---|---|---|
| El indice por forma de pago y fecha evita leer todos los pedidos y evita un `Sort` final. | Si | Nodo `Index Scan using idx_tp3_pedido_forma_pago_fecha`; no hay nodo `Sort`. El `Index Cond` incluye ambos filtros. |
| El costo final `143.13` significa que la consulta tardo `143.13 ms`. | No | `cost=0.42..143.13` es estimado. El valor real es `Execution Time: 0.553 ms`. |
| Los 200 resultados se obtuvieron con pocos accesos a buffers. | Si | El plan informa `Buffers: shared hit=200 read=4` y el `Index Scan` devuelve 200 filas. |

## Conclusion

La mejora de Q2 se atribuye al indice compuesto porque el plan posterior reemplaza el `Parallel Seq Scan` y el `Gather Merge` con ordenamiento del plan previo por un `Index Scan` que filtra y conserva el orden requerido. La conclusion se basa en el plan y el tiempo real, no en el costo estimado.
