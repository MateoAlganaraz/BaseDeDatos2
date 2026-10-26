# TP6 - Variantes para DBeaver

Mismos scripts que la carpeta `tp6/`, sin metacomandos de `psql` (`\set`, `\pset`, `\timing`, `\echo`). Los títulos de sección que `psql` imprimía con `\echo` quedan como comentarios.

Ejecutar cada archivo completo con **Execute SQL Script (Alt+X)**, en este orden y sobre la copia de laboratorio:

1. `tp_fnbc_control_lote.sql`
2. `00_carga_laboratorio.sql`
3. `tp_desnormalizacion_top_categorias.sql`
4. `01_mediciones_repetidas.sql`

DBeaver debe estar en modo auto-commit: los scripts manejan sus propias transacciones con `BEGIN`, `COMMIT` y `ROLLBACK`. En `psql` el script se detiene ante el primer error por `ON_ERROR_STOP`; en DBeaver conviene activar "Stop on error" en la configuración de ejecución de scripts.
