# Evidencia de TP5

La carpeta `20260923_tpi/` contiene salidas crudas de PostgreSQL 18.4 generadas durante la revisión del TPI sobre las copias aisladas declaradas en `../README.md`.

- `01` y `02`: preflight de las copias base e indexada.
- `03` y `04`: planes `EXPLAIN (ANALYZE, BUFFERS)` antes y después.
- `05`: ocho controles de equivalencia de las cuatro vistas; todos devolvieron cero diferencias.
- `06` y `07`: medición del reporte materializado y su `REFRESH ... CONCURRENTLY`.
- `08` y `09`: inserción reversible de 600 detalles en ambas copias.

Los tiempos de esta repetición pueden diferir de los publicados inicialmente por caché, carga y estado de la instancia. La decisión técnica se apoya en el plan real guardado y no en un único número.
