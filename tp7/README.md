# TP7 - Unidad 5: administración y seguridad de Food Store

Roles con mínimo privilegio, auditoría, simulacro de incidente de acceso indebido reconstruido con IA, anonimización de datos personales y bitácora de uso de IA. Todo se ejecutó solo contra la base de laboratorio propia `food_store_tp7_lab` (PostgreSQL 16.15 en `localhost`), creada desde `schema.sql` y poblada con la carga de las Unidades 1 a 4 (`tp6/00_carga_laboratorio.sql`).

Esta carpeta es la raíz del entregable `food-store-tp-u5/` que pide la consigna. La estructura exigida está completa, y además hay archivos de apoyo:

| Consigna | Archivo |
|---|---|
| `sql/roles.sql` | [`sql/roles.sql`](sql/roles.sql) (v2, con los cambios aceptados de la auditoría con IA) |
| `sql/auditoria_test.sql` | [`sql/auditoria_test.sql`](sql/auditoria_test.sql) |
| `sql/simulacro_incidente.sql` | [`sql/simulacro_incidente.sql`](sql/simulacro_incidente.sql) |
| `sql/usuario_anon.sql` | [`sql/usuario_anon.sql`](sql/usuario_anon.sql) |
| `docs/kiro_roles_spec/` | [`requirements.md`](docs/kiro_roles_spec/requirements.md), [`design.md`](docs/kiro_roles_spec/design.md), [`tasks.md`](docs/kiro_roles_spec/tasks.md) |
| `docs/informe_auditoria.md` | [`docs/informe_auditoria.md`](docs/informe_auditoria.md) |
| `docs/log_auditoria_prueba.txt` | [`docs/log_auditoria_prueba.txt`](docs/log_auditoria_prueba.txt) |
| `docs/log_simulacro_anonimizado.txt` | [`docs/log_simulacro_anonimizado.txt`](docs/log_simulacro_anonimizado.txt) |
| `docs/informe_incidente.md` | [`docs/informe_incidente.md`](docs/informe_incidente.md) |
| `docs/verificacion_equivalencia.md` | [`docs/verificacion_equivalencia.md`](docs/verificacion_equivalencia.md) |
| `BITACORA.md` | [`BITACORA.md`](BITACORA.md) |

Apoyo: `sql/00_base_usuarios.sql` (reconstrucción de `usuario`, `fn_autenticar` y `fn_resetear_password`), `sql/verificacion_permisos.sql` → `docs/verificacion_permisos.txt` (Parte A.3), `sql/configuracion_auditoria.sql`, `sql/simulacro_verificacion.sql`, `sql/verificacion_equivalencia.sql`, `scripts/run_tp7.sh` (orquestador), `scripts/anonimizar_log.py`, `docs/ia/` (prompts y respuestas completas de la IA), `evidencia/` (salidas reales), `dbeaver/` (variantes sin metacomandos) y `DB_Mateo_Algañaraz.pdf` (resumen para la plataforma).

## Ejecución

Solo sobre el servidor propio de desarrollo, como superusuario local y con permiso de lectura sobre el log del servidor:

```bash
createdb food_store_tp7_lab
psql -X -d food_store_tp7_lab -f schema.sql
psql -X -v ON_ERROR_STOP=1 -d food_store_tp7_lab -f tp6/00_carga_laboratorio.sql
tp7/scripts/run_tp7.sh base   # Parte A: usuario + funciones, roles.sql, verificación
tp7/scripts/run_tp7.sh B      # Parte B: activa la auditoría y ejecuta la prueba
tp7/scripts/run_tp7.sh C      # Parte C: simulacro, verificación y log anonimizado
psql -X -d food_store_tp7_lab -f tp7/sql/usuario_anon.sql             # Parte D
psql -X -d food_store_tp7_lab -f tp7/sql/verificacion_equivalencia.sql
python tp7/scripts/build_informe_pdf.py
```

`run_tp7.sh` genera contraseñas aleatorias para `app_web` y `admin_datos` en cada corrida. Las fija con `log_statement` desactivado en esa sesión y las guarda solo en un `PGPASSFILE` temporal que se borra al terminar: no hay credenciales en el repositorio. Para revertir la configuración de auditoría, ver `docs/informe_auditoria.md`.

## Resultados

**Parte A.** Hay 8 roles: el dueño `food_store_owner` sin login, 5 roles de grupo y 2 logins. `admin_datos` necesita un `SET ROLE` explícito para actuar como dueño (PG16, `INHERIT FALSE`). Hay permisos de columna sobre `usuario`, `producto`, `cliente`, `pedido` y `detalle_pedido`, y las tablas futuras nacen sin privilegios. La verificación da 42 privilegios esperados contra 42 reales, 0 diferencias en ambos sentidos y 31/31 pruebas funcionales coinciden. La auditoría con IA llevó a la v2: se aceptaron 6 cambios y se rechazaron 2 propuestas por ser más amplias de lo necesario.

**Parte B.** Se activaron `log_connections`, `log_disconnections`, `log_statement = mod` y un prefijo con quién, desde dónde y con qué aplicación; `app_web` registra todas sus sentencias. El log muestra lectura, inserción, actualización, `SET ROLE` y un login fallido. Hallazgo: el log guarda en claro las contraseñas pasadas a `fn_autenticar`, por eso el archivo es un activo sensible.

**Parte C.** Con 4 fallos y 1 acierto contra `fn_autenticar` se leyeron 2.000 emails por un permiso de columna legítimo. Los **5 intentos de escalamiento fallaron**, y se verificó desde el administrador: sin membresías nuevas, sin reseteo de contraseña y con la auditoría intacta. La IA reconstruyó bien la secuencia, pero hizo 3 afirmaciones sin sustento en el log y omitió que el origen era el propio servidor. La decisión de contención la tomó el equipo sobre la evidencia completa.

**Parte D.** `usuario_anon` no contiene ningún email ni nombre real. Las consultas generadas por la IA, ejecutadas sin cambios, dan `EXCEPT` 0 y 0, con 74 = 74 grupos y los mismos totales y tipos. El control negativo por zona horaria muestra 28 grupos distintos.

**Parte E.** [`BITACORA.md`](BITACORA.md) tiene 8 registros, el análisis del caso más significativo y la revisión del historial de Git (un commit por parte).

## Sobre las herramientas OpenCode y Kiro

En el entorno donde se resolvió el TP no estaban disponibles OpenCode ni Kiro. Las consultas a "la IA" se hicieron con instancias separadas de Claude, sin acceso al repositorio. La especificación se escribió en el formato de Kiro. Está explicado al comienzo de `BITACORA.md`, y los prompts están guardados literalmente en `docs/ia/` para poder repetirlos en OpenCode.
