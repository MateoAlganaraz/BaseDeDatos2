# TP5 en DBeaver

Conectarse a `food_store_tp5_base` para los planes y la escritura antes, y a `food_store_tp5_indices_vistas` para los objetos y las mediciones después.

1. Ejecutar `01_consultas_frecuentes.sql` y `03_medicion_escritura.sql` en la base base.
2. Ejecutar `02_indices.sql`, después `01_consultas_frecuentes.sql` y `03_medicion_escritura.sql` en la base indexada.
3. Ejecutar `04_views.sql`; para las equivalencias, abrir `../05_equivalencia_views.sql` y ejecutar desde el primer `WITH` (las dos primeras líneas son comandos exclusivos de `psql`).
4. Ejecutar `06_materializadas.sql`, `07_medicion_materializada.sql` y, cuando corresponda, `08_refrescar_materializada.sql`.

Los resultados oficiales ya están documentados en `../informe_mediciones.md`.
