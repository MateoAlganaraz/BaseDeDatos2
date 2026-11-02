# TP10 - TP N.º 8 de la cátedra (Unidad 8): Food Store en la feria

La base de la tablet en SQLite, la sincronización simulada con el semáforo contra PostgreSQL y el cierre de la capa de datos. En este repositorio la carpeta se llama `tp10/` porque `tp8/` es la Unidad 6 y `tp9/` la Unidad 7. Esta carpeta es el `food-store/` de la consigna.

**Regla de oro:** el móvil propone, el servidor dispone. La tablet solo consulta y arma borradores; precio, stock y ventas los decide PostgreSQL. `SIMULADO_APROBADO` **no es una venta**.

Ejecutado con PostgreSQL 16.15 y SQLite 3.50.4. Todas las cifras salen de `evidencia/`.

## Entregables

| Consigna | Archivo |
|---|---|
| 1.a Qué datos viajan | `docs/informe.pdf` §1.a y el comentario de `servidor/01_v_snapshot_movil.sql` |
| 1.b Las tablas | [`movil/schema_sqlite.sql`](movil/schema_sqlite.sql): empieza con `PRAGMA foreign_keys = ON;`; cuatro tablas STRICT, más `snapshot_servidor` y la vista `catalogo_disponible` |
| 1.c Probarla | [`movil/pruebas_sqlite.sql`](movil/pruebas_sqlite.sql): `BEGIN … COMMIT`, `ROLLBACK`, C1 y C7 |
| 2.a La instantánea | [`servidor/01_v_snapshot_movil.sql`](servidor/01_v_snapshot_movil.sql), [`movil/servidor_snapshot.csv`](movil/servidor_snapshot.csv) y [`movil/cargar_snapshot.sql`](movil/cargar_snapshot.sql) |
| 2.b El semáforo | [`movil/semaforo.sql`](movil/semaforo.sql) |
| 2.c Los casos | `movil/casos/`, `servidor/c2_subir_precio.sql`, `servidor/c4_baja_logica.sql`, `servidor/99_control_final.sql` y el informe §2.c |
| 3.a, 3.b y 3.c | `docs/informe.pdf` (3 páginas). `DB_Mateo_Algañaraz.pdf` es la misma copia para la plataforma |
| 4.a Spec | [`docs/kiro/`](docs/kiro/): `requirements.md` (cuatro requisitos EARS ligados a casos), `design.md` y `tasks.md` |
| 4.b Bitácora y DUIA | [`docs/bitacora_ia.md`](docs/bitacora_ia.md) y [`docs/DUIA.md`](docs/DUIA.md) |
| 4.c README y defensa | Este archivo |
| Base de la tablet | `movil/foodstore_movil.db`: el estado final, después de todos los casos |

Apoyo: [`run_tp10.sh`](run_tp10.sh) ejecuta todo desde cero, [`build_informe_pdf.py`](build_informe_pdf.py) arma el informe desde la evidencia, y `evidencia/` guarda las salidas completas.

## Crear todo desde cero

Requisitos: `psql` y `sqlite3` 3.37 o posterior (por `STRICT`; en Windows, `sqlite-tools` de sqlite.org o DB Browser for SQLite). También la base `foodstore` del laboratorio:

```bash
createdb foodstore
psql -X -d foodstore -c "SET client_encoding TO 'UTF8'" -f schema.sql
psql -X -v ON_ERROR_STOP=1 -d foodstore -f tp6/00_carga_laboratorio.sql
psql -X -d foodstore -f tp8/sql/01_simular_actividad.sql
```

Las credenciales van en las variables `PG*` y en `~/.pgpass` (Windows: `%APPDATA%\postgresql\pgpass.conf`), nunca en los scripts.

### Opción A: todo junto (Linux, macOS o Git Bash)

```bash
tp10/run_tp10.sh
# Para probar C1 con el servidor apagado:
PG_STOP_CMD="sudo service postgresql stop" PG_START_CMD="sudo service postgresql start" tp10/run_tp10.sh
python tp10/build_informe_pdf.py
```

### Opción B: paso a paso (igual en PowerShell)

Los `.sql` del servidor no usan metacomandos de `psql`, así que también corren en DBeaver (Alt+X).

```bash
# 0. Copia de PRUEBAS del servidor: nunca sobre foodstore
createdb -T foodstore foodstore_tp10_lab
psql -X -d foodstore_tp10_lab -f tp10/servidor/01_v_snapshot_movil.sql
cd tp10/movil
psql -X -d foodstore_tp10_lab -c "\copy (SELECT * FROM movil.v_snapshot_movil ORDER BY id) TO 'servidor_snapshot.csv' CSV HEADER"

# 1. Base de la tablet, catálogo y pruebas
sqlite3 foodstore_movil.db < schema_sqlite.sql
sqlite3 foodstore_movil.db < cargar_snapshot.sql      # .import --csv --skip 1 servidor_snapshot.csv snapshot_servidor
sqlite3 foodstore_movil.db < pruebas_sqlite.sql       # los errores de C7 son esperados
sqlite3 foodstore_movil.db < semaforo.sql

# 2. Cada caso: borrador -> (cambio en el servidor) -> nueva instantánea -> carga -> semáforo
sqlite3 foodstore_movil.db < casos/c2_borrador.sql
psql -X -d foodstore_tp10_lab -f ../servidor/c2_subir_precio.sql
#    repetir el \copy, cargar_snapshot.sql y semaforo.sql   -> CONFLICTO
sqlite3 foodstore_movil.db < casos/c2_aceptar.sql
sqlite3 foodstore_movil.db < semaforo.sql                    # -> SIMULADO_APROBADO
#    C3: casos/c3_borrador.sql; \copy; carga; semáforo        -> RECHAZADO
#    C4: casos/c4_borrador.sql; ../servidor/c4_baja_logica.sql; \copy; carga; semáforo; casos/c4_catalogo.sql
#    C5: casos/c5_borrador.sql; \copy; carga; semáforo        -> SIMULADO_APROBADO
#    C6: casos/c6_reenviar.sql (error de clave esperado); semáforo -> 0 evaluadas

# 3. Control final en PostgreSQL
psql -X -d foodstore_tp10_lab -f ../servidor/99_control_final.sql
```

Para repetir desde cero, borrar `foodstore_movil.db` y recrear `foodstore_tp10_lab`.

## Resultados

| Caso | Resultado |
|---|---|
| C1 | Con PostgreSQL detenido (`pg_isready`: no response), el catálogo devuelve 9.600 productos disponibles |
| C2 | `CONFLICTO` (precio visto 383700, actual 402885 centavos); después de aceptar el precio, una solicitud nueva da `SIMULADO_APROBADO` |
| C3 | `RECHAZADO`: pide 170 y hay 164 |
| C4 | `RECHAZADO`: dado de baja. La fila queda con `eliminado = 1` y sale del catálogo |
| C5 | `SIMULADO_APROBADO` |
| C6 | `UNIQUE constraint failed: cola_sync.solicitud_uuid`; la segunda corrida evalúa 0 solicitudes |
| C7 | Cantidad 0 y producto inexistente fallan; los borradores siguen siendo 1 y los ítems 2 |
| Servidor | 600.000 pedidos, 1.500.000 detalles y el mismo stock producto por producto que la línea base |

## Ensayo de la defensa (10 minutos, semana 13)

1. **El mapa (3 min).** Informe §3.a: PostgreSQL manda sobre todo; MongoDB es una proyección de lectura; la tablet manda solo sobre sus borradores y su cola. Remarcar que `SIMULADO_APROBADO` no es una venta.
2. **Un caso en vivo (4 min): C2.** `c2_borrador.sql` → `c2_subir_precio.sql` → `\copy` → `cargar_snapshot.sql` → `semaforo.sql` (`CONFLICTO` con los dos precios) → `c2_aceptar.sql` → `semaforo.sql` (`SIMULADO_APROBADO`). Cerrar con `99_control_final.sql`: pedidos y stock iguales.
3. **Un hallazgo de la IA (3 min).** H4: la propuesta de recargar el caché con `DELETE` + `INSERT` parece más simple, pero falla por la FK de los borradores y borraría las lápidas que C4 necesita. Se muestra con un solo comando sobre una copia de la tablet.

Preguntas para preparar: por qué el precio va en centavos, por qué una baja viaja como lápida, por qué el semáforo solo toca `PENDIENTE`, y dónde iría la idempotencia real (en el servidor, con `solicitud_uuid` UNIQUE en la misma transacción que crea el pedido).

## Uso de IA

La consigna pide Kiro y OpenCode. No estaban disponibles, así que se usó Claude (Anthropic, en Claude Code), con el mismo criterio que en `tp7/`. Cada script se ejecutó antes de aceptarlo. Ver [`docs/bitacora_ia.md`](docs/bitacora_ia.md) y [`docs/DUIA.md`](docs/DUIA.md).
