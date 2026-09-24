# Paso de ER a modelo relacional

| Relación | Clave primaria | Claves foráneas y restricciones relevantes |
|---|---|---|
| `cliente` | `id_cliente` | Email único entre filas vigentes mediante índice parcial; `deleted_at` registra la baja lógica. |
| `categoria` | `id_categoria` | `nombre` único; nombre no vacío; `activo`. |
| `producto` | `id_producto` | `id_categoria -> categoria`; precio positivo, stock no negativo, nombre no vacío; estado y baja lógica. |
| `pedido` | `id_pedido` | `id_cliente -> cliente`; fecha y forma de pago. |
| `detalle_pedido` | `(id_pedido, id_producto)` | Ambas columnas son FK; cantidad y precio unitario positivos. |

Las relaciones 1:N se implementan llevando la FK al lado N: `pedido.id_cliente` y `producto.id_categoria`. La N:M Pedido-Producto se transforma en `detalle_pedido`: su PK compuesta evita cargar el mismo producto dos veces en un pedido y preserva el precio con el que se vendió.

Las FK usan `ON DELETE RESTRICT`, por lo que una eliminación física no puede romper el historial. La baja lógica es el mecanismo de retiro operativo: las vistas TPI filtran `deleted_at IS NULL` y los índices parciales aceleran ese acceso.
