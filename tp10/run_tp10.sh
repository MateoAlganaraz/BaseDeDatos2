#!/usr/bin/env bash
# =====================================================================
# Mateo Algañaraz - Base de Datos II - 2026
# TP N.º 8 (Unidad 8) - Ejecuta todo desde cero y guarda la evidencia en tp10/evidencia/.
#
#   tp10/run_tp10.sh
#
# Requisitos: psql y sqlite3 (3.37+) en el PATH; la base foodstore del laboratorio
# (schema.sql + tp6/00_carga_laboratorio.sql + tp8/sql/01_simular_actividad.sql) y la conexión
# configurada con las variables PG* y ~/.pgpass (nunca contraseñas en este archivo).
#
# Variables opcionales:
#   ORIGEN=foodstore              base de laboratorio que se copia
#   LAB=foodstore_tp10_lab        copia de PRUEBAS donde se preparan los casos (se recrea)
#   PG_STOP_CMD / PG_START_CMD    comandos para detener y arrancar PostgreSQL durante C1
#                                 (por ejemplo "sudo service postgresql stop"). Si no se definen,
#                                 C1 se ejecuta igual, solo con la base local de la tablet.
#
# La tablet NUNCA escribe en PostgreSQL. Los únicos cambios en la copia del servidor son los
# que prepara este script para C2 (precio) y C4 (baja lógica), en lugar de la tienda real.
# =====================================================================
set -euo pipefail

TP="$(cd "$(dirname "$0")" && pwd)"
MOVIL="$TP/movil"
SERV="$TP/servidor"
EVID="$TP/evidencia"
ORIGEN="${ORIGEN:-foodstore}"
LAB="${LAB:-foodstore_tp10_lab}"
DB="$MOVIL/foodstore_movil.db"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$EVID"

psql_lab() { psql -X -v ON_ERROR_STOP=1 -d "$LAB" "$@"; }

# sqlite3 lee el script por la entrada estándar; los errores esperados (C4, C6 y C7) se
# muestran en la evidencia y la ejecución sigue (sin -bail), por eso no se corta el script.
# La carpeta de trabajo define qué CSV toma .import.
sqlite_en() { local dir="$1" script="$2"; (cd "$dir" && sqlite3 "$DB" < "$script" 2>&1) || true; }

titulo() { printf '\n==================== %s ====================\n' "$1"; }
comando() { printf '$ %s\n' "$*"; }

exportar_snapshot() {   # $1 = carpeta destino del CSV
    comando "psql -d $LAB -c \"\\copy (SELECT * FROM movil.v_snapshot_movil ORDER BY id) TO 'servidor_snapshot.csv' CSV HEADER\""
    psql_lab -q -c "\\copy (SELECT * FROM movil.v_snapshot_movil ORDER BY id) TO '$1/servidor_snapshot.csv' CSV HEADER"
    echo "filas exportadas: $(( $(wc -l < "$1/servidor_snapshot.csv") - 1 ))"
}

cargar_y_semaforo() {   # $1 = carpeta con el CSV nuevo
    comando "sqlite3 foodstore_movil.db < cargar_snapshot.sql"
    sqlite_en "$1" "$MOVIL/cargar_snapshot.sql"
    comando "sqlite3 foodstore_movil.db < semaforo.sql"
    sqlite_en "$MOVIL" "$MOVIL/semaforo.sql"
}

# ---------------------------------------------------------------------
# 0. Copia de PRUEBAS del servidor y vista de la instantánea (2.a)
# ---------------------------------------------------------------------
{
    titulo "0. Copia del servidor: $ORIGEN -> $LAB"
    comando "dropdb --if-exists $LAB && createdb -T $ORIGEN $LAB"
    dropdb --if-exists "$LAB"
    createdb -T "$ORIGEN" "$LAB"
    psql_lab -At -c "SELECT version()"
    titulo "2.a Vista v_snapshot_movil y línea base"
    comando "psql -d $LAB -f servidor/01_v_snapshot_movil.sql"
    psql_lab -f "$SERV/01_v_snapshot_movil.sql"
    titulo "2.a Exportación de la instantánea a movil/servidor_snapshot.csv"
    exportar_snapshot "$MOVIL"
    head -3 "$MOVIL/servidor_snapshot.csv"
} > "$EVID/01_servidor_snapshot.txt" 2>&1

# ---------------------------------------------------------------------
# 1. Base de la tablet (1.b), carga del catálogo (2.a) y pruebas (1.c)
# ---------------------------------------------------------------------
rm -f "$DB"
{
    titulo "1.b Esquema de la tablet"
    sqlite3 --version
    comando "sqlite3 foodstore_movil.db < schema_sqlite.sql"
    sqlite_en "$MOVIL" "$MOVIL/schema_sqlite.sql"
    (cd "$MOVIL" && sqlite3 "$DB" ".schema producto_cache")
    titulo "2.a Importación de la instantánea en snapshot_servidor y carga de producto_cache"
    comando "sqlite3 foodstore_movil.db < cargar_snapshot.sql   (ejecuta .import --csv --skip 1 servidor_snapshot.csv snapshot_servidor)"
    sqlite_en "$MOVIL" "$MOVIL/cargar_snapshot.sql"
} > "$EVID/02_tablet_esquema_y_carga.txt" 2>&1

{
    titulo "1.c Pruebas de la base de la tablet"
    comando "sqlite3 foodstore_movil.db < pruebas_sqlite.sql"
    sqlite_en "$MOVIL" "$MOVIL/pruebas_sqlite.sql"

    titulo "C1 con el servidor detenido"
    if [[ -n "${PG_STOP_CMD:-}" && -n "${PG_START_CMD:-}" ]]; then
        comando "$PG_STOP_CMD"
        eval "$PG_STOP_CMD" > /dev/null
        comando "pg_isready"
        pg_isready || true
        comando "sqlite3 foodstore_movil.db \"SELECT count(*) ... FROM catalogo_disponible\""
        (cd "$MOVIL" && sqlite3 -header -column "$DB" \
            "SELECT count(*) AS productos_disponibles, max(copiado_en) AS copia_del FROM catalogo_disponible;
             SELECT id, nombre, printf('%.2f', precio_centavos / 100.0) AS precio FROM catalogo_disponible WHERE id IN (101, 106, 109);")
        comando "$PG_START_CMD"
        eval "$PG_START_CMD" > /dev/null
        until pg_isready -q; do sleep 1; done
        pg_isready
    else
        echo "PG_STOP_CMD / PG_START_CMD no definidos: C1 se probó en pruebas_sqlite.sql sin detener el servidor."
    fi

    titulo "2.b Primera corrida del semáforo (evalúa la solicitud de la prueba 1.c)"
    comando "sqlite3 foodstore_movil.db < semaforo.sql"
    sqlite_en "$MOVIL" "$MOVIL/semaforo.sql"
} > "$EVID/03_pruebas_sqlite.txt" 2>&1

# ---------------------------------------------------------------------
# 2. Casos C2 a C6 (2.c)
# ---------------------------------------------------------------------
{
    titulo "C2 - Sube el precio después del borrador: CONFLICTO y luego SIMULADO_APROBADO"
    comando "sqlite3 foodstore_movil.db < casos/c2_borrador.sql"
    sqlite_en "$MOVIL" "$MOVIL/casos/c2_borrador.sql"
    comando "psql -d $LAB -f servidor/c2_subir_precio.sql"
    psql_lab -f "$SERV/c2_subir_precio.sql"
    mkdir -p "$TMP/c2"; exportar_snapshot "$TMP/c2"; cargar_y_semaforo "$TMP/c2"
    comando "sqlite3 foodstore_movil.db < casos/c2_aceptar.sql"
    sqlite_en "$MOVIL" "$MOVIL/casos/c2_aceptar.sql"
    comando "sqlite3 foodstore_movil.db < semaforo.sql"
    sqlite_en "$MOVIL" "$MOVIL/semaforo.sql"

    titulo "C3 - Más unidades de las que quedan: RECHAZADO"
    comando "sqlite3 foodstore_movil.db < casos/c3_borrador.sql"
    sqlite_en "$MOVIL" "$MOVIL/casos/c3_borrador.sql"
    mkdir -p "$TMP/c3"; exportar_snapshot "$TMP/c3"; cargar_y_semaforo "$TMP/c3"

    titulo "C4 - Producto dado de baja: RECHAZADO y lápida en el catálogo"
    comando "sqlite3 foodstore_movil.db < casos/c4_borrador.sql"
    sqlite_en "$MOVIL" "$MOVIL/casos/c4_borrador.sql"
    comando "psql -d $LAB -f servidor/c4_baja_logica.sql"
    psql_lab -f "$SERV/c4_baja_logica.sql"
    mkdir -p "$TMP/c4"; exportar_snapshot "$TMP/c4"; cargar_y_semaforo "$TMP/c4"
    comando "sqlite3 foodstore_movil.db < casos/c4_catalogo.sql"
    sqlite_en "$MOVIL" "$MOVIL/casos/c4_catalogo.sql"

    titulo "C5 - Borrador sin cambios: SIMULADO_APROBADO"
    comando "sqlite3 foodstore_movil.db < casos/c5_borrador.sql"
    sqlite_en "$MOVIL" "$MOVIL/casos/c5_borrador.sql"
    mkdir -p "$TMP/c5"; exportar_snapshot "$TMP/c5"; cargar_y_semaforo "$TMP/c5"

    titulo "C6 - Reenvío de la misma solicitud: error de clave primaria y sin reevaluar"
    comando "sqlite3 foodstore_movil.db < casos/c6_reenviar.sql"
    sqlite_en "$MOVIL" "$MOVIL/casos/c6_reenviar.sql"
    comando "sqlite3 foodstore_movil.db < semaforo.sql   (segunda corrida sin solicitudes PENDIENTE)"
    sqlite_en "$MOVIL" "$MOVIL/semaforo.sql"
} > "$EVID/04_casos_c2_c6.txt" 2>&1

# ---------------------------------------------------------------------
# 3. Control final en PostgreSQL
# ---------------------------------------------------------------------
{
    titulo "Control final: pedidos y stock del servidor contra la línea base"
    comando "psql -d $LAB -f servidor/99_control_final.sql"
    psql_lab -f "$SERV/99_control_final.sql"
    titulo "Resumen de la cola de la tablet"
    (cd "$MOVIL" && sqlite3 -header -column "$DB" \
        "SELECT estado, count(*) AS solicitudes FROM cola_sync GROUP BY estado ORDER BY estado;")
} > "$EVID/05_control_final.txt" 2>&1

echo "Listo. Evidencia en $EVID:"
ls -1 "$EVID"
