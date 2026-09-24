# Spec Codex - Índice de autocompletado de productos

Objetivo: acelerar el autocompletado de productos activos por prefijo de nombre.

Consulta afectada: productos activos cuyo nombre comienza con `TP3_SB2026TP3_PRODUCTO_049`, ordenados por nombre y limitados a 100 filas. Los guiones bajos se escapan en `LIKE` para que sean caracteres literales y el prefijo sea indexable.

Frecuencia: búsqueda de catálogo mientras un operador escribe un prefijo.

Columnas candidatas: `nombre` requiere búsqueda por prefijo; `activo` es condición parcial; precio y stock son columnas de salida que pueden cubrirse.

Criterio de aceptación: el plan deja de recorrer toda `producto` y usa un acceso por índice compatible con `LIKE 'prefijo%'`, sin exponer productos inactivos.
