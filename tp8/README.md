# TP8 - Unidad 6: mantenimiento, respaldo y recuperación

Procedimiento pequeño pero completo sobre Food Store: especificación del plan, respaldo automatizable, chequeo de salud, mantenimiento justificado y simulacro de restauración cronometrado, con RPO y RTO observados. Todas las cifras salen de las salidas guardadas en `evidencia/` (PostgreSQL 16.15, base `foodstore` creada desde `schema.sql` y poblada con `tp6/00_carga_laboratorio.sql`).

## Entregables

| Consigna | Archivo |
|---|---|
| `SPEC_U6.md` | [`SPEC_U6.md`](SPEC_U6.md): tareas, frecuencias, condiciones de éxito, RPO/RTO previstos y reglas de seguridad. [`AGENTS.md`](AGENTS.md) contiene las reglas para el asistente de IA. |
| `backup_foodstore.ps1` o `.sh` | Los dos: [`backup_foodstore.sh`](backup_foodstore.sh) y [`backup_foodstore.ps1`](backup_foodstore.ps1), probados en su camino exitoso y en sus caminos de error. |
| `health_check.sql` | [`health_check.sql`](health_check.sql): tamaño, conexiones, estado de tablas, consultas activas, alertas de más de 5 min, bloqueos y edad de transacciones. |
| `maintenance.sql` | [`maintenance.sql`](maintenance.sql): revisión de autovacuum con su propia fórmula de umbrales y `VACUUM (ANALYZE)` solo sobre las tablas que lo requieren. Nunca usa `VACUUM FULL`. |
| `restore_test.ps1` o `.sh` (opcional) | Los dos: [`restore_test.sh`](restore_test.sh) y [`restore_test.ps1`](restore_test.ps1). |
| `informe_u6.pdf` | [`informe_u6.pdf`](informe_u6.pdf): informe post-incidente de una página, más un anexo de evidencias. `DB_Mateo_Algañaraz.pdf` es la misma copia para la plataforma. |

Apoyo: `sql/00_rol_respaldo.sql` (rol `foodstore_backup` de solo lectura), `sql/01_simular_actividad.sql` (actividad previa al chequeo), `build_informe_pdf.py` y `evidencia/`. Los `.dump`, conteos y logs no se versionan porque tienen datos (`.gitignore`); su creación, tamaño y restauración quedan en `evidencia/`.

## Preparación en tu equipo (una sola vez)

1. Crear y poblar `foodstore`: `CREATE DATABASE foodstore;`, `\c foodstore`, `SET client_encoding TO 'UTF8';`, `\i .../schema.sql` y `\i .../tp6/00_carga_laboratorio.sql`.
2. Crear el rol de respaldo: `\i .../tp8/sql/00_rol_respaldo.sql` y después `\password foodstore_backup`.
3. Guardar las credenciales **fuera del repositorio**:
   - **Windows:** `%APPDATA%\postgresql\pgpass.conf`.
   - **Linux:** `~/.pgpass`, con `chmod 600`.
   
   Una línea por usuario: `localhost:5432:*:foodstore_backup:...` y `localhost:5432:*:postgres:...`.

## Ejecución

```powershell
# Windows (PowerShell), desde la carpeta tp8
powershell -ExecutionPolicy Bypass -File .\backup_foodstore.ps1
psql -X -h localhost -U foodstore_backup -d foodstore -f health_check.sql
psql -X -h localhost -U postgres -d foodstore -f maintenance.sql
powershell -ExecutionPolicy Bypass -File .\restore_test.ps1 -Jobs 2
```

```bash
# Linux
./backup_foodstore.sh
psql -X -h localhost -U foodstore_backup -d foodstore -f health_check.sql
psql -X -h localhost -U postgres -d foodstore -f maintenance.sql
JOBS=2 ./restore_test.sh
```

En Windows los respaldos quedan dentro del perfil del usuario, protegidos por los permisos de esa carpeta. La versión `.sh` además fija `umask 077` (archivos `600`).

## Resultados

| Medida | Valor | Evidencia |
|---|---|---|
| Respaldo | `foodstore_20261026_111838.dump`, 18.780.506 bytes, creado el 26/10/2026 11:18:39 -03; `pg_dump` 2,44 s | `02_backup_ok.txt` |
| Caminos de error | Base inexistente y servidor inaccesible: código de salida 2 (`.ps1`: 1), sin archivos parciales | `01`, `06` |
| Simulacro (RTO observado) | **4,04 s** desde `createdb` hasta la última validación; restauración 3,78 s | `07_simulacro_restauracion.txt` |
| RPO observado | **39 s** de antigüedad del respaldo al iniciar el simulacro (previsto: 24 h con respaldo diario) | `07` |
| Validaciones | Conteos de las 5 tablas iguales al respaldo; 0 productos y 0 detalles inválidos; 18 = 18 restricciones | `07`, `10` |
| Mejora medida | `pg_restore -j 2`: mediana del RTO de 2,36 s a 1,93 s (−18 %) | `08_comparacion_jobs.txt` |
| `foodstore` | Intacta después de los simulacros | `10_foodstore_intacta_y_validacion.txt` |

**Problema real encontrado:** dos apagados no limpios del servidor de laboratorio provocaron recuperación automática, y PostgreSQL descartó las estadísticas acumuladas. `health_check.sql` mostró `n_live_tup = 0` y ningún `ANALYZE` registrado, así que autovacuum quedaba sin datos para decidir. `maintenance.sql` lo detectó y aplicó `VACUUM (ANALYZE)` solo donde correspondía (`05`, `05b`).

**Correcciones antes de dar el respaldo por apto:**
- Los `.dump` se creaban con permisos `644`; ahora con `umask 077`.
- Si fallaba, quedaba un `.counts.csv` vacío; ahora se borra.
- Faltaba `-w`: en una tarea programada, psql podía quedar esperando una contraseña.
- La consulta de validación de la consigna usa la columna `precio`, que en este esquema se llama `precio_lista` (`10`).

**Uso de IA:** OpenCode no estaba disponible en el entorno de resolución. La primera versión de los scripts la generó Claude (Anthropic) a partir de `SPEC_U6.md` y `AGENTS.md`. Cada script se revisó y se ejecutó, incluidos sus caminos de error, antes de aceptarlo; las correcciones de arriba salieron de esa revisión.
