# Modelo entidad-relación

```mermaid
erDiagram
    CLIENTE ||--o{ PEDIDO : realiza
    PEDIDO ||--|{ DETALLE_PEDIDO : contiene
    PRODUCTO ||--o{ DETALLE_PEDIDO : integra
    CATEGORIA ||--o{ PRODUCTO : clasifica

    CLIENTE {
        bigint id_cliente PK
        varchar nombre
        varchar apellido
        varchar email
        timestamptz deleted_at
    }
    CATEGORIA {
        bigint id_categoria PK
        varchar nombre UK
        boolean activo
    }
    PRODUCTO {
        bigint id_producto PK
        bigint id_categoria FK
        varchar nombre
        numeric precio_lista
        integer stock
        boolean activo
        timestamptz deleted_at
    }
    PEDIDO {
        bigint id_pedido PK
        bigint id_cliente FK
        timestamptz fecha
        forma_pago_enum forma_pago
    }
    DETALLE_PEDIDO {
        bigint id_pedido PK, FK
        bigint id_producto PK, FK
        integer cantidad
        numeric precio_unitario
    }
```

## Cardinalidad y participación

| Relación | Cardinalidad | Participación | Regla aplicada |
|---|---|---|---|
| Cliente - Pedido | 1:N | `pedido` total; `cliente` parcial | `pedido.id_cliente NOT NULL` y FK. |
| Categoría - Producto | 1:N | `producto` total; `categoria` parcial | `producto.id_categoria NOT NULL` y FK. |
| Pedido - Detalle | 1:N | `detalle_pedido` total; un pedido creado puede no tener detalle hasta terminar el procedimiento | FK y PK compuesta. |
| Producto - Detalle | 1:N | `detalle_pedido` total; `producto` parcial | FK y trigger de producto vigente. |

La relación conceptual N:M entre `pedido` y `producto` se resuelve mediante la entidad asociativa `detalle_pedido`; sus atributos propios son `cantidad` y el precio histórico `precio_unitario`.

El borrado lógico se representa con `deleted_at` en `cliente` y `producto`. No se elimina el historial de `pedido` ni de `detalle_pedido`.
