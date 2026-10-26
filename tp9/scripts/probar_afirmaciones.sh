#!/usr/bin/env bash
# =====================================================================
# Mateo Algañaraz - Base de Datos II - 2026
# TP Unidad 7 - Ejecuta pruebas_afirmaciones_ia.js en un servidor standalone y en un replica
# set de un nodo levantado solo para la prueba (puerto 27018, carpeta temporal).
#   tp9/scripts/probar_afirmaciones.sh
# Requiere mongod y mongosh en el PATH y el standalone del laboratorio en 127.0.0.1:27017
# con la colección cargada por consultas_mongodb.js.
# =====================================================================
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
RS_DIR="$(mktemp -d)"
trap 'mongosh --quiet --port 27018 --eval "db.getSiblingDB(\"admin\").shutdownServer()" >/dev/null 2>&1 || true; rm -rf "$RS_DIR"' EXIT

echo "### 1. Servidor standalone (127.0.0.1:27017)"
mongosh --quiet "mongodb://127.0.0.1:27017/foodstore_nosql" "$DIR/pruebas_afirmaciones_ia.js"

echo
echo "### 2. Replica set de un nodo (127.0.0.1:27018)"
mongod --replSet rs_tp9 --dbpath "$RS_DIR" --bind_ip 127.0.0.1 --port 27018 --fork \
       --logpath "$RS_DIR/mongod.log" > /dev/null
mongosh --quiet --port 27018 --eval 'rs.initiate({ _id: "rs_tp9", members: [{ _id: 0, host: "127.0.0.1:27018" }] }).ok' > /dev/null
until mongosh --quiet --port 27018 --eval 'db.hello().isWritablePrimary' | grep -q true; do sleep 1; done
mongosh --quiet "mongodb://127.0.0.1:27018/?replicaSet=rs_tp9" "$DIR/pruebas_afirmaciones_ia.js"
