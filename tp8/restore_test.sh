#!/usr/bin/env bash
# =====================================================================
# Mateo Algañaraz - Base de Datos II - 2026
# TP Unidad 6 - Simulacro de restauración contra reloj (SPEC_U6: tarea semanal).
#
# Restaura el último respaldo de backups/ en la base descartable foodstore_restore_test,
# valida conteos y restricciones lógicas, y registra el RTO y el RPO observados en
# logs/restore_AAAAMMDD_HHMMSS.log. Nunca toca foodstore.
#
# Cronómetro: empieza inmediatamente antes de createdb y termina cuando las validaciones
# pasan. Si alguna validación falla, el script termina con código 1.
#
# Sin contraseñas: ~/.pgpass o PGPASSWORD de la sesión. Variables opcionales:
#   PGHOST=localhost  PGPORT=5432  PGUSER=postgres   (necesita permiso CREATEDB)
#   DUMP=<archivo .dump>  (por defecto, el más reciente de backups/)
#   JOBS=1                (procesos paralelos de pg_restore; >1 es la mejora medida)
# =====================================================================
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
SOURCE_DB="foodstore"
RESTORE_DB="foodstore_restore_test"
JOBS="${JOBS:-1}"
LOG_DIR="$DIR/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/restore_$(date +%Y%m%d_%H%M%S).log"

log() { printf '%s %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" | tee -a "$LOG"; }
falla() { log "FALLA $*"; exit 1; }
trap 'log "ERROR comando fallido en la línea $LINENO (código $?)"' ERR

# Regla 4 de SPEC_U6: el destino nunca puede ser la base principal.
[ "$RESTORE_DB" != "$SOURCE_DB" ] || falla "el destino no puede ser $SOURCE_DB"

DUMP="${DUMP:-$(ls -1t "$DIR"/backups/*.dump 2>/dev/null | head -n 1 || true)}"
[ -n "$DUMP" ] && [ -s "$DUMP" ] || falla "no hay respaldo en $DIR/backups"
COUNTS="${DUMP%.dump}.counts.csv"
[ -s "$COUNTS" ] || falla "falta el conteo previo $(basename "$COUNTS")"

# Fecha de creación del respaldo, tal como la registró pg_dump en el archivo.
CREADO=$(pg_restore --list "$DUMP" | sed -n 's/^; Archive created at //p')
CREADO_EPOCH=$(date -d "$CREADO" +%s)

log "Respaldo a restaurar: $(basename "$DUMP") (creado $CREADO)"
log "Destino: $RESTORE_DB en $PGHOST:$PGPORT como $PGUSER; pg_restore -j $JOBS"

# Preparación fuera del cronómetro: borrar la base descartable de una corrida anterior.
dropdb -w --if-exists "$RESTORE_DB"

# ---------------- Cronómetro ----------------
INICIO_EPOCH=$(date +%s)
INICIO=$(date +%s.%N)
log "INICIO del simulacro (cronómetro en marcha)"
RPO_S=$((INICIO_EPOCH - CREADO_EPOCH))

createdb -w "$RESTORE_DB"
pg_restore -w -d "$RESTORE_DB" --no-owner --no-privileges -j "$JOBS" "$DUMP"
FIN_RESTORE=$(date +%s.%N)
log "Restauración terminada en $(awk -v a="$INICIO" -v b="$FIN_RESTORE" 'BEGIN{printf "%.2f", b-a}') s"

q() { psql -X -w -q -A -t -v ON_ERROR_STOP=1 -d "$RESTORE_DB" -c "$1"; }

# Validación 1: filas por tabla contra el conteo previo al respaldo.
RESTAURADO=$(psql -X -w -q -v ON_ERROR_STOP=1 -d "$RESTORE_DB" -A -F ',' -P footer=off -c "
    SELECT 'categoria' AS tabla, count(*) AS filas FROM categoria
    UNION ALL SELECT 'cliente', count(*) FROM cliente
    UNION ALL SELECT 'producto', count(*) FROM producto
    UNION ALL SELECT 'pedido', count(*) FROM pedido
    UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido")
if [ "$RESTAURADO" = "$(cat "$COUNTS")" ]; then
    log "Conteos OK (iguales al respaldo): $(echo "$RESTAURADO" | tail -n +2 | tr '\n' ' ')"
else
    log "Conteo previo:  $(tail -n +2 "$COUNTS" | tr '\n' ' ')"
    log "Conteo restaurado: $(echo "$RESTAURADO" | tail -n +2 | tr '\n' ' ')"
    falla "los conteos no coinciden"
fi

# Validación 2 y 3: restricciones lógicas (la columna de precio en este esquema es precio_lista).
PROD_INV=$(q "SELECT count(*) FROM producto WHERE precio_lista < 0 OR stock < 0")
DET_INV=$(q "SELECT count(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0")
log "productos_invalidos=$PROD_INV detalles_invalidos=$DET_INV"
[ "$PROD_INV" = "0" ] && [ "$DET_INV" = "0" ] || falla "hay filas inválidas"

# Validación 4: las restricciones del esquema también se restauraron.
CONS_ORIG=$(psql -X -w -q -A -t -d "$SOURCE_DB" -c "SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace WHERE n.nspname = 'public'")
CONS_REST=$(q "SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace WHERE n.nspname = 'public'")
log "restricciones: origen=$CONS_ORIG restaurada=$CONS_REST"
[ "$CONS_ORIG" = "$CONS_REST" ] || falla "faltan restricciones en la base restaurada"

FIN=$(date +%s.%N)
# ---------------- Fin del cronómetro ----------------
RTO=$(awk -v a="$INICIO" -v b="$FIN" 'BEGIN{printf "%.2f", b-a}')
log "FIN del simulacro: validaciones OK"
log "RTO observado: $RTO s (createdb + pg_restore + validaciones)"
log "RPO observado: $RPO_S s ($(awk -v s="$RPO_S" 'BEGIN{printf "%dh %02dm %02ds", s/3600, (s%3600)/60, s%60}')) = antigüedad del respaldo al iniciar el simulacro"
log "Tamaño de $RESTORE_DB: $(q "SELECT pg_size_pretty(pg_database_size(current_database()))")"
