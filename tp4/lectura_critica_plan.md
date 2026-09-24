# TP4 - Parte 2: lectura crítica de un plan de joins

## Plan elegido: Q3 ventas mensuales de `producto.id_producto = 100001`

Se eligió el plan posterior de Q3 porque tiene tres `Nested Loop`, usa las cuatro tablas requeridas y permite contrastar el cambio real de acceso. El plan completo está en `evidencia/20260915_producto/q_producto_despues.txt`; el anterior está en `q_producto_antes.txt`.

Extracto medido del plan posterior:

```text
Nested Loop  (actual time=0.126..0.237 rows=8 loops=1)
  -> Nested Loop  (actual time=0.111..0.149 rows=8 loops=1)
       -> Index Only Scan using idx_tp4_detalle_producto_pedido on detalle_pedido det
            (actual time=0.071..0.105 rows=8 loops=1)
            Index Cond: (id_producto = 100001)
       -> Materialize (actual time=0.005..0.005 rows=1 loops=8)
            -> Nested Loop
                 -> Index Scan using producto_pkey on producto p
                 -> Index Scan using categoria_pkey on categoria cat
  -> Index Scan using pedido_pkey on pedido ped
       (actual time=0.010..0.010 rows=1 loops=8)
       Index Cond: (id_pedido = det.id_pedido)
Execution Time: 0.460 ms
```

Antes del índice, el nodo de acceso a `detalle_pedido` fue `Parallel Seq Scan`, quitó 399.992 filas por filtro y el total fue 65,141 ms. Después, `Index Only Scan` leyó las ocho líneas del producto y el total fue 0,460 ms.

## Prompt enviado a la IA

> Explica este plan de PostgreSQL nodo por nodo sin asumir datos que no aparecen. Para cada `Nested Loop`, identifica la entrada externa y la interna. Distingue costo estimado, filas estimadas, filas reales, bucles y `Execution Time`. No propongas cambios; solo interpreta el plan.

## Respuesta de la IA

> El `GroupAggregate` agrupa las ocho filas que llegan desde los joins por mes y categoría; no es un join. Debajo, el `Sort` ordena esas ocho filas. El `Nested Loop` superior usa como entrada externa el resultado del `Nested Loop` inferior y como entrada interna el `Index Scan` de `pedido_pkey`; por eso el escaneo de pedido tiene `loops=8`, uno por cada detalle. En el `Nested Loop` inferior, el `Index Only Scan` de `detalle_pedido` es la entrada externa: encuentra ocho detalles con `id_producto = 100001`. La entrada interna es el `Materialize`, que reutiliza ocho veces la única combinación activa de producto y categoría. Dentro de ese materializado, otro `Nested Loop` consulta primero el producto por clave primaria y luego su categoría por clave primaria. Los números `cost=...` son estimaciones de costo del planificador, no milisegundos. Los tiempos medidos son los campos `actual time` y el tiempo total confiable es `Execution Time: 0.460 ms`.

## Contraste con el plan real

| Afirmación de la IA | ¿Correcta? | Corrección o evidencia del plan real |
|---|---|---|
| El índice permite buscar las líneas del producto 100001 sin recorrer toda `detalle_pedido`. | Sí | `Index Only Scan` con `Index Cond: (id_producto = 100001)` devuelve 8 filas; antes hubo `Parallel Seq Scan` y 399.992 filas removidas. |
| El costo estimado del nodo es el tiempo de ejecución. | No | `cost=121.00..121.26` es estimado. La evidencia temporal es `Execution Time: 0.460 ms`, frente a 65,141 ms antes. |
| En el `Nested Loop` superior, el resultado del loop inferior es externo y el `Index Scan` de `pedido_pkey` es interno, con 8 bucles. | Sí | El plan muestra el scan de pedido como segundo hijo y `loops=8`; su condición usa `det.id_pedido` de la entrada externa. |
| En el loop inferior, el scan indexado de detalle es externo y el `Materialize` producto-categoría es interno. | Sí | El plan lista primero `Index Only Scan` de detalle y luego `Materialize`; este último tiene `rows=1 loops=8`. |

Conclusión: la explicación se acepta porque coincide con la estructura de hijos del plan, sus `rows` y `loops`, y separa las estimaciones `cost` del tiempo de ejecución real.
