# Requirements - Food Store en la feria (TP N.º 8, Unidad 8)

## Contexto

El food truck de Food Store vende en una feria sin señal. Una tablet con SQLite consulta el catálogo y arma borradores de pedido. Cuando vuelve la conexión, cada borrador se compara con una instantánea del servidor PostgreSQL. Regla de oro: **el móvil propone, el servidor dispone**. La tablet nunca cambia el stock ni el precio del servidor, ni confirma ventas.

## Requisitos (notación EARS)

| ID | Requisito | Se prueba con |
|---|---|---|
| REQ-01 | WHEN el precio actual de algún producto de la solicitud es distinto del precio visto en la tablet, y ningún producto está en rojo, THE SYSTEM SHALL marcar la solicitud como `CONFLICTO` e indicar el precio visto y el actual en el motivo. | C2 |
| REQ-02 | WHEN algún producto de la solicitud no existe en el servidor, no está disponible, fue dado de baja, o la cantidad pedida supera el stock del servidor, THE SYSTEM SHALL marcar la solicitud como `RECHAZADO` e indicar el producto y la causa en el motivo. | C3, C4 |
| REQ-03 | WHEN una solicitud se reenvía con un `solicitud_uuid` ya registrado, THE SYSTEM SHALL rechazar el alta por clave primaria y no reevaluar las solicitudes que ya dejaron de estar `PENDIENTE`. | C6 |
| REQ-04 | WHILE la tablet no tiene conexión con el servidor, THE SYSTEM SHALL permitir consultar el catálogo disponible y guardar borradores completos en una sola transacción, rechazando cantidades no positivas y productos inexistentes sin dejar filas nuevas. | C1, C7 (y la prueba de `BEGIN … COMMIT` / `ROLLBACK`) |

## Requisito transversal

- IF todos los productos de una solicitud coinciden en existencia, disponibilidad, stock y precio, THEN THE SYSTEM SHALL marcarla `SIMULADO_APROBADO`, que **no** es una venta ni modifica PostgreSQL. Se prueba con C5 y con el control final en PostgreSQL (pedidos y stock sin cambios).

## Fuera de alcance

Aplicación móvil, interfaz, sincronización real por red, alta de ventas en el servidor, datos de clientes en la tablet.
