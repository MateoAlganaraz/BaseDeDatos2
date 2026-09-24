# TP4 para DBeaver

Conectarse a la copia masiva de laboratorio y ejecutar, en este orden:

1. `00_preflight.sql`
2. `01_consultas_analiticas.sql` - guardar resultados como planes antes.
3. `02_indices.sql` - leer y ejecutar solamente si se entiende cada indice.
4. `01_consultas_analiticas.sql` de nuevo - guardar como planes despues.
5. `03_specs_equivalencia.sql` - los cuatro controles deben devolver 0.
6. `04_consulta_comun_competencia.sql` antes y despues de la estrategia decidida.
7. `05_validacion.sql` - integridad y equivalencias deben quedar en 0.

Los archivos de esta carpeta no usan los metacomandos `psql` (`\\set`, `\\timing`, etc.). En DBeaver seleccionar una sentencia o todo el archivo y ejecutarlo con `Ctrl+Enter`. Guardar el panel de resultados de cada `EXPLAIN (ANALYZE, BUFFERS)` y consignar los tiempos reales en `../plantillas_evidencia.md`.
