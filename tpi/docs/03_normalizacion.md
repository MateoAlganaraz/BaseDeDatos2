# Normalización y dependencias funcionales

## Dependencias funcionales

| Relación | Dependencia funcional determinante |
|---|---|
| `cliente` | `id_cliente -> nombre, apellido, email, telefono, deleted_at` |
| `categoria` | `id_categoria -> nombre, descripcion, activo`; además `nombre -> id_categoria` por `UNIQUE`. |
| `producto` | `id_producto -> nombre, descripcion, precio_lista, stock, activo, deleted_at, id_categoria` |
| `pedido` | `id_pedido -> fecha, id_cliente, forma_pago` |
| `detalle_pedido` | `(id_pedido, id_producto) -> cantidad, precio_unitario` |

## Justificación hasta 3FN/BCNF

Todas las relaciones tienen atributos atómicos (1FN). No hay dependencias parciales en la PK compuesta de `detalle_pedido`: `cantidad` y `precio_unitario` dependen del par pedido-producto, no de una sola parte (2FN).

No se duplican atributos transitivos: el nombre de categoría no está en `producto`, y los datos del cliente no se guardan en `pedido`; se obtienen con JOIN. Por ello no existen dependencias transitivas entre atributos no clave (3FN).

Los determinantes declarados son claves candidatas o superclaves dentro de cada relación, por lo que el diseño también satisface BCNF. El índice parcial de email vigente es una regla de ciclo de vida: permite reutilizar un email tras una baja lógica y no agrega una dependencia redundante a los datos históricos.
