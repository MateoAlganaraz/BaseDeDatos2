#!/usr/bin/env bash
# =====================================================================
# Mateo Algañaraz - Base de Datos II - 2026
# TP Unidad 6 - Respaldo lógico de foodstore (SPEC_U6: tarea diaria).
#
# Genera backups/foodstore_AAAAMMDD_HHMMSS.dump (formato custom, para pg_restore),
# un .counts.csv con las filas por tabla tomadas antes del respaldo, y
# logs/backup_AAAAMMDD_HHMMSS.log. Termina con código distinto de 0 si algo falla y en ese
# caso borra el archivo parcial.
#
# Sin contraseñas: la autenticación sale de ~/.pgpass o de PGPASSWORD en la sesión.
# Variables opcionales (con su valor por defecto):
#   PGHOST=localhost  PGPORT=5432  PGUSER=foodstore_backup  DB_NAME=foodstore
#   BACKUP_DIR=<carpeta del script>/backups   LOG_DIR=<carpeta del script>/logs
# Programación sugerida (cron, diaria a las 03:00):
#   0 3 * * * /ruta/tp8/backup_foodstore.sh >> /ruta/tp8/logs/cron.log 2>&1
# =====================================================================
set -euo pipefail
# El respaldo contiene datos personales (clientes, usuarios): archivos solo legibles por el dueño.
umask 077

DIR="$(cd "$(dirname "$0")" && pwd)"
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-foodstore_backup}"
DB_NAME="${DB_NAME:-foodstore}"
BACKUP_DIR="${BACKUP_DIR:-$DIR/backups}"
LOG_DIR="${LOG_DIR:-$DIR/logs}"

STAMP="$(date +%Y%m%d_%H%M%S)"
DUMP="$BACKUP_DIR/${DB_NAME}_${STAMP}.dump"
PARTIAL="$DUMP.partial"
COUNTS="$BACKUP_DIR/${DB_NAME}_${STAMP}.counts.csv"
LOG="$LOG_DIR/backup_${STAMP}.log"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

log() { printf '%s %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" | tee -a "$LOG"; }

on_error() {
    local code=$?
    rm -f "$PARTIAL"
    log "ERROR respaldo de $DB_NAME fallido (código $code). Archivo parcial eliminado."
    exit "$code"
}
trap on_error ERR

log "INICIO respaldo de $DB_NAME en $PGHOST:$PGPORT como $PGUSER"
log "pg_dump: $(pg_dump --version)"

# Filas por tabla antes del respaldo: referencia para validar la restauración.
psql -X -q -v ON_ERROR_STOP=1 -d "$DB_NAME" -A -F ',' -P footer=off -c "
    SELECT 'categoria' AS tabla, count(*) AS filas FROM categoria
    UNION ALL SELECT 'cliente', count(*) FROM cliente
    UNION ALL SELECT 'producto', count(*) FROM producto
    UNION ALL SELECT 'pedido', count(*) FROM pedido
    UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido" > "$COUNTS"
log "Conteo previo guardado en $(basename "$COUNTS"): $(tail -n +2 "$COUNTS" | tr '\n' ' ')"

INICIO=$(date +%s.%N)
pg_dump -d "$DB_NAME" -Fc -f "$PARTIAL"
FIN=$(date +%s.%N)

# Verificación mínima: el archivo existe, no está vacío y pg_restore puede leer su índice.
[ -s "$PARTIAL" ]
OBJETOS=$(pg_restore --list "$PARTIAL" | grep -vc '^;')
mv "$PARTIAL" "$DUMP"

TAMANO=$(stat -c %s "$DUMP")
SHA=$(sha256sum "$DUMP" | cut -d' ' -f1)
log "Archivo: $(basename "$DUMP")"
log "Tamaño: $TAMANO bytes ($(numfmt --to=iec "$TAMANO"))"
log "SHA-256: $SHA"
log "Entradas en el índice (pg_restore --list): $OBJETOS"
log "Duración de pg_dump: $(awk -v a="$INICIO" -v b="$FIN" 'BEGIN { printf "%.2f", b - a }') s"
log "OK respaldo de $DB_NAME terminado"
