# Consigna 6 - Respuesta completa de la IA

Texto devuelto por la IA, sin editar. El contraste de dos afirmaciones está en el informe.

---

# PostgreSQL vs. MongoDB para los pedidos de Food Store

## 1. Qué pide el escenario

Hay dos tipos de necesidades que tiran en direcciones distintas:

- **Lectura:** se lee muy seguido el pedido completo, con su cliente y todas sus líneas. Esto favorece un modelo **orientado a agregados** (documentos).
- **Escritura:** las reglas de integridad cruzan entidades:
  - El precio histórico tiene que quedar fijo.
  - El total tiene que coincidir con las líneas.
  - El stock tiene que descontarse sin vender de más cuando hay compras simultáneas.

  Esto favorece un modelo **transaccional con restricciones** (relacional).

Sobre el volumen: 600.000 pedidos y 1.500.000 detalles es poco para cualquiera de los dos motores. Con estos datos el rendimiento no decide la elección. La deciden la integridad y la complejidad operativa.

---

## 2. PostgreSQL

### Ventajas
- **ACID completo y concurrencia resuelta por el motor.** El descuento de stock se hace de forma segura con una actualización condicional:
  ```sql
  UPDATE producto
     SET stock = stock - $cant
   WHERE id_producto = $id AND stock >= $cant AND deleted_at IS NULL;
  -- si afecta 0 filas: no hay stock suficiente -> ROLLBACK
  ```
  También sirve `SELECT ... FOR UPDATE`. Las dos formas impiden que dos compras simultáneas vendan más de lo disponible, y todo el pedido (cabecera, líneas y stock) se confirma o se descarta junto.
- **Integridad declarativa** que ya tenés: FK, PK compuesta y `CHECK (cantidad > 0)` / `CHECK (precio > 0)`.
- **El precio histórico ya está bien resuelto:** `detalle_pedido.precio_unitario` guarda lo cobrado, separado de `producto.precio_lista`.
- **El total del pedido** se puede calcular en una vista, o guardar en `pedido.total` y mantenerlo con un trigger o dentro de la misma transacción. Así siempre coincide con las líneas.
- **Reportes y consultas ad hoc** (ventas por categoría, por producto, por forma de pago) son triviales con SQL y JOIN.
- **Puede devolver el pedido completo en una sola consulta**, ya armado como JSON:
  ```sql
  SELECT p.id_pedido, p.fecha, p.forma_pago,
         json_build_object('id', c.id_cliente, 'nombre', c.nombre, 'apellido', c.apellido, 'email', c.email) AS cliente,
         json_agg(json_build_object('id_producto', d.id_producto, 'producto', pr.nombre,
                  'cantidad', d.cantidad, 'precio_unitario', d.precio_unitario)) AS items,
         sum(d.cantidad * d.precio_unitario) AS total
    FROM pedido p
    JOIN cliente c        ON c.id_cliente = p.id_cliente
    JOIN detalle_pedido d ON d.id_pedido = p.id_pedido AND d.deleted_at IS NULL
    JOIN producto pr      ON pr.id_producto = d.id_producto
   WHERE p.id_pedido = $1 AND p.deleted_at IS NULL
   GROUP BY p.id_pedido, c.id_cliente;
  ```

### Desventajas
- Cada lectura de un pedido completo necesita varios JOIN. Con índices adecuados cuestan milisegundos, pero es más trabajo que leer un solo documento.
- Si el esquema varía mucho (por ejemplo, atributos distintos por tipo de producto), el esquema rígido molesta. Igual se resuelve con `JSONB`.
- Escalar horizontalmente las escrituras es más complejo, aunque este volumen está lejos de necesitarlo.

### Mejoras concretas para el escenario
```sql
-- historial de un cliente, solo pedidos activos
CREATE INDEX ix_pedido_cliente_fecha ON pedido (id_cliente, fecha DESC) WHERE deleted_at IS NULL;
-- líneas por pedido: ya cubierto por la PK (id_pedido, id_producto)
-- consultas por producto (reportes)
CREATE INDEX ix_detalle_producto ON detalle_pedido (id_producto);
```
Además conviene:
- Agregar `pedido.total NUMERIC(12,2)`, mantenido en la transacción de alta o con un trigger.
- Agregar `CHECK (stock >= 0)` en `producto`, como última barrera contra la sobreventa.
- Encapsular la compra en una función o procedimiento transaccional.

---

## 3. MongoDB

### Cómo modelaría los pedidos
El modelo sería **un documento por pedido, con las líneas embebidas** y una **copia (snapshot) de los datos del cliente y del producto al momento de la compra**:

```js
// colección pedidos
{
  _id: 100234,
  fecha: ISODate("2026-10-20T14:32:00Z"),
  forma_pago: "tarjeta",
  cliente: {                       // referencia + snapshot
    id_cliente: 5521,
    nombre: "Ana", apellido: "Pérez", email: "ana@mail.com"
  },
  items: [
    { id_producto: 17, nombre: "Pizza muzzarella", categoria: "Pizzas",
      cantidad: 2, precio_unitario: NumberDecimal("8500.00"),
      subtotal: NumberDecimal("17000.00") },
    { id_producto: 42, nombre: "Gaseosa 1.5L", categoria: "Bebidas",
      cantidad: 1, precio_unitario: NumberDecimal("2500.00"),
      subtotal: NumberDecimal("2500.00") }
  ],
  total: NumberDecimal("19500.00"),
  deleted_at: null
}

// colección productos (stock y precio de lista viven acá, NO embebidos)
{ _id: 17, nombre: "Pizza muzzarella", precio_lista: NumberDecimal("9000.00"),
  stock: 120, categoria: { id: 3, nombre: "Pizzas" }, deleted_at: null }

// colección clientes
{ _id: 5521, nombre: "Ana", apellido: "Pérez", email: "...", telefono: "...", deleted_at: null }
```

Criterios del diseño:
- **Embeber las líneas:** pertenecen solo a ese pedido, son pocas (en promedio unas 2,5) y siempre se leen juntas. El documento queda chico, muy lejos del límite de 16 MB.
- **Precio histórico:** `precio_unitario` se copia en la línea al vender y nunca se actualiza. Cambiar `precio_lista` en `productos` no lo afecta.
- **Snapshot del cliente:** sirve para mostrar el historial sin hacer `$lookup`. La contra es que si el cliente cambia su email, los pedidos viejos conservan el anterior. Para un historial de compras eso suele ser deseable, pero hay que decidirlo de forma explícita.
- **Stock fuera del pedido:** el stock es estado compartido entre muchos pedidos, así que va en `productos`.
- **Dinero con `Decimal128`**, nunca `double`.
- **Índices:**
  ```js
  db.pedidos.createIndex({ "cliente.id_cliente": 1, fecha: -1 },
                         { partialFilterExpression: { deleted_at: null } })
  db.pedidos.createIndex({ "items.id_producto": 1 })   // multikey, para reportes
  ```
- **Validación con `$jsonSchema`:** tipos, campos obligatorios, `cantidad` ≥ 1 y `precio_unitario` > 0.

### Alta de un pedido con control de stock
```js
const session = client.startSession();
session.withTransaction(async () => {
  for (const it of items) {
    const r = await productos.updateOne(
      { _id: it.id_producto, stock: { $gte: it.cantidad }, deleted_at: null },
      { $inc: { stock: -it.cantidad } }, { session });
    if (r.modifiedCount === 0) throw new Error("Sin stock: " + it.id_producto);
  }
  await pedidos.insertOne(pedidoConTotalCalculado, { session });
});
```
El `updateOne` con el filtro `stock: { $gte }` es atómico por documento, así que evita la sobreventa. La transacción multi-documento (que requiere un replica set) asegura que el pedido y los descuentos de stock se confirmen juntos.

### Ventajas
- **Lectura del pedido completo en un solo acceso**, sin JOIN. El documento coincide con lo que muestra la pantalla.
- **Escritura atómica del pedido entero** (cabecera más líneas) sin necesidad de transacción, porque es un único documento.
- **Esquema flexible:** se pueden agregar atributos por pedido o por línea (promociones, notas, extras) sin migraciones.
- **Escalado horizontal (sharding)** más natural, por ejemplo por `cliente.id_cliente`.

### Desventajas
- **No hay claves foráneas.** Nada impide un `id_producto` o un `id_cliente` inexistente; eso queda a cargo de la aplicación.
- **La coherencia del total queda en la aplicación.** `$jsonSchema` no puede verificar que `total` sea la suma de los subtotales. Un validador con `$expr` ayuda solo de forma limitada, y en la práctica se confía en el código.
- **La regla más crítica, el stock, cruza documentos y colecciones.** Necesita transacciones multi-documento, que tienen más costo y más restricciones (replica set, límites de tiempo, reintentos ante conflictos de escritura) y no son el camino idiomático de MongoDB. Justo la parte difícil del problema es la que menos aprovecha MongoDB.
- **Duplicación de datos** (nombre de cliente, nombre de producto): hay que definir qué se actualiza y qué queda como snapshot.
- **Reportes analíticos** (ventas por categoría, ranking de productos) requieren pipelines de agregación con `$unwind` y `$group`. Son posibles, pero más verbosos que SQL.
- **Costo de migración:** datos, código, un segundo motor que operar, backups y monitoreo.

---

## 4. Comparación resumida

| Criterio | PostgreSQL | MongoDB |
|---|---|---|
| Leer el pedido completo | JOIN con índices (rápido a este volumen); `json_agg` lo devuelve armado | Un solo documento, sin JOIN |
| Precio histórico | `precio_unitario` en `detalle_pedido` (ya resuelto) | Copiado en `items[]` (igual de simple) |
| Total = suma de líneas | Vista, trigger o transacción; garantizado por el motor | Calculado en la aplicación; sin garantía del motor |
| Stock sin sobreventa | `UPDATE ... WHERE stock >= x` + `CHECK (stock >= 0)` + ACID | `$inc` condicional + transacción multi-documento |
| Integridad referencial | FK nativas | No existe; queda en la aplicación |
| Restricciones de dominio | `CHECK` | `$jsonSchema` (más limitado) |
| Reportes ad hoc | SQL, muy fuerte | Aggregation pipeline, más trabajoso |
| Flexibilidad de esquema | Media (`JSONB` ayuda) | Alta |
| Escalado horizontal | Más complejo | Más natural (sharding) |
| Costo de cambio | Ninguno | Migración y un motor nuevo |

---

## 5. Recomendación

**Mantener PostgreSQL como sistema de registro de los pedidos.** Razones:

1. Los requisitos duros (stock sin sobreventa, total coherente, integridad entre pedido, cliente y producto) son exactamente lo que PostgreSQL garantiza de forma nativa. En MongoDB habría que reimplementarlos con transacciones multi-documento y lógica de aplicación, perdiendo la principal ventaja del modelo documental.
2. La ventaja de MongoDB en la lectura del pedido completo es real, pero a este volumen se consigue casi lo mismo en PostgreSQL con:
   - los índices adecuados;
   - una consulta o vista que devuelva el pedido armado con `json_agg`;
   - de ser necesario, una columna `total` desnormalizada.
3. El precio histórico ya está bien modelado en el esquema actual.

**Combinar ambos** solo lo consideraría si más adelante la lectura de historiales se vuelve un cuello de botella real, o si aparece una necesidad de esquema flexible o de escalado que PostgreSQL no cubra con réplicas de lectura. En ese caso el esquema sería:

- **PostgreSQL** sigue siendo la fuente de verdad: altas de pedidos, stock, precios y reportes.
- **MongoDB** funciona como **modelo de lectura (patrón CQRS)**: los documentos `pedidos` tal como los diseñé arriba, solo para mostrar historial y detalle.
- La sincronización se hace con un **outbox transaccional o CDC** (por ejemplo, replicación lógica o Debezium), aceptando consistencia eventual en la vista.

Antes de sumar un segundo motor, una alternativa intermedia es guardar dentro de PostgreSQL un snapshot `JSONB` del pedido, o una vista materializada, para las pantallas de historial. Así se obtiene la lectura "en un solo documento" sin perder ACID ni sumar infraestructura.

**Pasar los pedidos completamente a MongoDB no lo recomiendo en este escenario:** se gana poco en lectura y se pierde mucho en integridad, justo en las reglas que señalaste como críticas.

result: Recomiendo mantener PostgreSQL para los pedidos de Food Store y sumar MongoDB solo como modelo de lectura (CQRS) si alguna vez hiciera falta; incluyo un diseño de documento MongoDB con líneas embebidas para ese caso.