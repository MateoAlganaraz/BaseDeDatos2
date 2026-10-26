# TP7 - Variantes para DBeaver

Los mismos scripts de `../sql/` sin metacomandos de `psql` (`\set`, `\pset`, `\echo`, `\if`). Los títulos de sección quedan como comentarios. Ejecutar cada archivo con **Execute SQL Script (Alt+X)**, en modo auto-commit y con "Stop on error" activado, conectado como superusuario a la copia de laboratorio:

1. `00_base_usuarios.sql`
2. `roles.sql`
3. `configuracion_auditoria.sql`
4. `usuario_anon.sql` (con la sal de laboratorio escrita en la consulta)
5. `verificacion_equivalencia.sql`
6. `simulacro_verificacion.sql` (después de correr el simulacro)

No tienen variante DBeaver los scripts que dependen de `psql`:

- `verificacion_permisos.sql`: usa `\du`, que pide la consigna.
- `auditoria_test.sql` y `simulacro_incidente.sql`: necesitan abrir varias conexiones con distintos roles, o una conexión real de `app_web`, para que el log registre el origen. Se ejecutan con `scripts/run_tp7.sh`.
