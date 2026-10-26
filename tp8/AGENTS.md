# Instrucciones para asistentes de IA - TP Unidad 6

Estas reglas complementan el `AGENTS.md` de la raíz y aplican a OpenCode o a cualquier asistente que genere o modifique archivos en `tp8/`.

- Leer `SPEC_U6.md` antes de escribir código: es la fuente de verdad de tareas, frecuencias y condiciones de éxito.
- Motor PostgreSQL 16. Base principal `foodstore`; la única base que se puede crear o borrar es `foodstore_restore_test`.
- Nunca escribir contraseñas en scripts, logs, ejemplos ni mensajes de commit. Autenticación por `.pgpass` o variables de entorno de la sesión.
- Los scripts de shell usan `set -euo pipefail`; el de PowerShell, `$ErrorActionPreference = 'Stop'` y revisión de `$LASTEXITCODE`. Un fallo de `pg_dump`, `pg_restore` o `psql` debe terminar el script con error.
- No proponer `VACUUM FULL`, `pg_resetwal`, `DROP DATABASE foodstore` ni `TRUNCATE` sobre `foodstore`.
- Las consultas de monitoreo usan solo vistas y funciones disponibles en PostgreSQL 16 (`pg_stat_activity`, `pg_stat_database`, `pg_stat_user_tables`, `pg_locks`).
- Toda cifra del informe (tamaños, tiempos, RPO, RTO, conteos) sale de una salida guardada en `evidencia/`; no se completan valores a mano.
