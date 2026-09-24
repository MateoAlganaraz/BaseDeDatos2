# Spec Codex - Vista materializada de facturación

Objetivo: precalcular facturación y cantidad de pedidos por categoría y mes para un reporte analítico costoso.

Tablas: `categoria`, `producto`, `detalle_pedido` y `pedido`. Filtros: categoría y producto activos. Salida: mes, categoría, cantidad de pedidos distintos y facturación.

Criterio de aceptación: crear la vista con `WITH DATA`, un índice único sobre mes y categoría para habilitar `REFRESH MATERIALIZED VIEW CONCURRENTLY`, y demostrar que consultar el resumen materializado reduce el tiempo frente a recalcular los joins y agregaciones.
