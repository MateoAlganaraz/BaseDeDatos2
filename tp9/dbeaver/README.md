# TP9 - Variante para DBeaver

`consultas_postgresql.sql` es el mismo script de `../consultas_postgresql.sql` sin metacomandos de `psql` (`\set`, `\pset`, `\echo`). Los títulos de sección quedan como comentarios. Ejecutarlo con **Execute SQL Script (Alt+X)**, en modo auto-commit y con "Stop on error" activado, conectado a la base `foodstore` del laboratorio. DBeaver abre una pestaña de resultados por cada `SELECT`.

El lado MongoDB (`consultas_mongodb.js`, `pruebas_afirmaciones_ia.js`, `lectura_pedido_completo.js`) se ejecuta con `mongosh`, y `scripts/exportar_migracion.py` usa `psql`: no tienen variante DBeaver.
