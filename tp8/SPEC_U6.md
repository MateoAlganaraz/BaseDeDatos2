# SPEC_U6 - Plan de mantenimiento, respaldo y recuperación de Food Store

**Alcance:** servidor PostgreSQL 16 de laboratorio (`localhost:5432`), base principal `foodstore` y base descartable `foodstore_restore_test`. Esta especificación se escribió antes que los scripts y es la referencia para revisarlos.

## Tareas automatizadas

| Tarea | Script | Frecuencia | Condición de éxito (evidencia) |
|---|---|---|---|
| Respaldo de `foodstore` | `backup_foodstore.sh` (Linux) / `backup_foodstore.ps1` (Windows) | Diaria, 03:00 | Exit code 0; `backups/foodstore_AAAAMMDD_HHMMSS.dump` no vacío y legible con `pg_restore --list`; conteo de filas guardado en `.counts.csv`; línea `OK` en `logs/backup_*.log`. |
| Chequeo de salud | `health_check.sql` | Diaria, después del respaldo | Ejecución sin error; salida guardada; ninguna consulta `active` o `idle in transaction` de más de 5 min. |
| Revisión de mantenimiento | `maintenance.sql` | Semanal | Tablas con tuplas muertas sobre el umbral de autovacuum o sin `ANALYZE` reciente quedan listadas; si hay alguna, se ejecuta `VACUUM (ANALYZE)` solo sobre esas, y la revisión posterior las muestra resueltas. |
| Restauración de prueba | `restore_test.sh` | Semanal, con el último respaldo | `foodstore_restore_test` restaurada sin errores; conteos iguales al `.counts.csv` del respaldo; 0 productos y 0 detalles inválidos; RTO y RPO observados registrados en `logs/restore_*.log`. |

## Objetivos

- **RPO previsto:** 24 h. Con un respaldo lógico diario, se pierde como máximo lo escrito desde el último respaldo.
- **RTO previsto (laboratorio):** 5 min. Es el tiempo desde la creación de la base de prueba hasta que pasan las validaciones.

## Reglas de seguridad (obligatorias para personas y para el asistente de IA)

1. Ningún script contiene ni imprime contraseñas. Se autentica con `~/.pgpass` (`%APPDATA%\postgresql\pgpass.conf` en Windows) o con la variable `PGPASSWORD` de la sesión, nunca con valores escritos en el repositorio.
2. El respaldo usa un rol de solo lectura (`foodstore_backup`, miembro de `pg_read_all_data`), no el superusuario.
3. El respaldo es `pg_dump -Fc`. Si `pg_dump` falla, el script termina con código distinto de 0, borra el archivo parcial y lo registra en el log.
4. La restauración solo apunta a `foodstore_restore_test`: el script se niega a usar `foodstore` como destino. `foodstore` nunca se elimina ni se reemplaza.
5. No se usa `VACUUM FULL` como mantenimiento periódico. Todo `VACUUM`/`ANALYZE` manual se justifica con la observación previa de `pg_stat_user_tables`.
6. Los `.dump`, `.counts.csv` y `logs/` no se versionan: tienen datos y se excluyen con `.gitignore`. En el repositorio queda la evidencia de su creación, tamaño y restauración.
7. Cada script generado o ajustado con IA se revisa línea por línea y se ejecuta primero en el laboratorio, incluido su camino de error, antes de considerarlo apto para programarse.
