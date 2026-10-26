#!/usr/bin/env bash
# =====================================================================
# Mateo Algañaraz - Base de Datos II - 2026
# TP Unidad 5 - Orquestador del laboratorio (solo contra el servidor local propio).
#
# Uso:
#   tp7/scripts/run_tp7.sh base   # 00_base_usuarios.sql + roles.sql + verificación (Parte A)
#   tp7/scripts/run_tp7.sh B      # configuración de auditoría + auditoria_test.sql (Parte B)
#   tp7/scripts/run_tp7.sh C      # simulacro + verificación + anonimización del log (Parte C)
#
# Variables: DB (food_store_tp7_lab), PGLOG (log del servidor; por defecto el de Ubuntu/Debian).
# El usuario que ejecuta debe poder conectarse como superusuario por socket local y leer el log.
#
# Credenciales: en cada corrida se generan contraseñas aleatorias para app_web y admin_datos,
# se fijan con log_statement desactivado en esa sesión (para que no queden en el log) y se
# guardan solo en un PGPASSFILE temporal que se borra al terminar. Nada de eso se versiona.
# =====================================================================
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB="${DB:-food_store_tp7_lab}"
PGLOG="${PGLOG:-/var/log/postgresql/postgresql-16-main.log}"
PARTE="${1:-}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

su_psql() { psql -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

preparar_credenciales() {
    local app admin
    app="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
    admin="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
    # Cada -c es una consulta separada: el SET llega antes que el ALTER ROLE.
    su_psql -q -c "SET log_statement = 'none'" \
               -c "ALTER ROLE app_web PASSWORD '${app}'" \
               -c "ALTER ROLE admin_datos PASSWORD '${admin}'"
    printf '127.0.0.1:5432:%s:app_web:%s\n127.0.0.1:5432:%s:admin_datos:%s\n' \
        "$DB" "$app" "$DB" "$admin" > "$WORK/pgpass"
    chmod 600 "$WORK/pgpass"
    export PGPASSFILE="$WORK/pgpass"
}

# Copia el tramo del log escrito entre dos marcas de tamaño, sin líneas de otras bases.
recortar_log() {
    local desde="$1" destino="$2"
    sleep 1
    tail -c +"$((desde + 1))" "$PGLOG" > "$destino"
}

case "$PARTE" in
  base)
    su_psql -f "$DIR/sql/00_base_usuarios.sql"
    su_psql -f "$DIR/sql/roles.sql"
    psql -X -d "$DB" -f "$DIR/sql/verificacion_permisos.sql" > "$DIR/docs/verificacion_permisos.txt" 2>&1
    echo "Verificación en docs/verificacion_permisos.txt"
    ;;
  B)
    su_psql -f "$DIR/sql/configuracion_auditoria.sql" > "$DIR/evidencia/B_configuracion_auditoria.txt" 2>&1
    preparar_credenciales
    inicio=$(stat -c %s "$PGLOG")
    psql -X -d "$DB" -v db="$DB" -f "$DIR/sql/auditoria_test.sql" > "$DIR/evidencia/B_salida_auditoria_test.txt" 2>&1 || true
    recortar_log "$inicio" "$DIR/docs/log_auditoria_prueba.txt"
    echo "Log en docs/log_auditoria_prueba.txt"
    ;;
  C)
    preparar_credenciales
    inicio=$(stat -c %s "$PGLOG")
    psql -X "host=127.0.0.1 dbname=$DB user=app_web application_name=sqlcli sslmode=require" \
        -f "$DIR/sql/simulacro_incidente.sql" > "$DIR/evidencia/C_salida_simulacro.txt" 2>&1 || true
    recortar_log "$inicio" "$DIR/evidencia/C_log_simulacro_original.txt"
    psql -X -d "$DB" -f "$DIR/sql/simulacro_verificacion.sql" > "$DIR/evidencia/C_verificacion_escalamiento.txt" 2>&1
    python3 "$DIR/scripts/anonimizar_log.py" "$DIR/evidencia/C_log_simulacro_original.txt" \
        > "$DIR/docs/log_simulacro_anonimizado.txt"
    echo "Log anonimizado en docs/log_simulacro_anonimizado.txt"
    ;;
  *)
    echo "Uso: $0 base|B|C" >&2
    exit 2
    ;;
esac
