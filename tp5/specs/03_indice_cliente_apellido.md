# Spec Codex - Índice de búsqueda de clientes

Objetivo: acelerar la búsqueda de clientes por prefijo de apellido.

Consulta afectada: clientes cuyo apellido comienza con `TP3019`, ordenados por apellido y limitados a 100 filas.

Frecuencia: localización de un cliente al cargar un pedido o atender una consulta.

Columnas candidatas: `apellido` participa del filtro y orden; `nombre` y `email` se muestran en el resultado.

Criterio de aceptación: el plan cambia de `Seq Scan` a un acceso por índice para el prefijo, conservando las 100 filas y el orden solicitado.
