"""Genera migracion_mongodb.js (insertMany) a partir de PostgreSQL.

Lee los documentos armados por la vista nosql_lab.documento_pedido (consultas_postgresql.sql)
y los escribe como un insertMany() de mongosh con los tipos BSON correctos:
  _id e id numéricos -> NumberLong / NumberInt; importes -> NumberDecimal (Decimal128, sin
  error de redondeo binario); fechas -> ISODate en UTC.
Uso: python3 tp9/scripts/exportar_migracion.py [base]   (por defecto: foodstore)
"""
import json
import subprocess
import sys
from pathlib import Path

DB = sys.argv[1] if len(sys.argv) > 1 else "foodstore"
OUT = Path(__file__).resolve().parent.parent / "migracion_mongodb.js"

crudo = subprocess.run(
    ["psql", "-X", "-At", "-v", "ON_ERROR_STOP=1", "-d", DB, "-c",
     "SELECT json_agg(documento ORDER BY id_pedido) FROM nosql_lab.documento_pedido"],
    check=True, capture_output=True, text=True).stdout
docs = json.loads(crudo)


def dec(v):
    return f'NumberDecimal("{v}")'


def fecha(v):
    return "null" if v is None else f'ISODate("{v}")'


def s(v):
    return json.dumps(v, ensure_ascii=False)


def linea(l):
    return ("      { id_producto: NumberInt(%d), producto: %s, categoria: %s, cantidad: NumberInt(%d), "
            "precio_unitario: %s, subtotal: %s, anulada: %s }"
            % (l["id_producto"], s(l["producto"]), s(l["categoria"]), l["cantidad"],
               dec(l["precio_unitario"]), dec(l["subtotal"]), "true" if l["anulada"] else "false"))


bloques = []
for d in docs:
    c = d["cliente"]
    bloques.append("\n".join([
        "  {",
        f"    _id: NumberLong(\"{d['_id']}\"),",
        f"    fecha: {fecha(d['fecha'])},",
        f"    estado: {s(d['estado'])},",
        f"    anulado_en: {fecha(d['anulado_en'])},",
        f"    forma_pago: {s(d['forma_pago'])},",
        f"    cliente: {{ id_cliente: NumberLong(\"{c['id_cliente']}\"), nombre: {s(c['nombre'])}, "
        f"apellido: {s(c['apellido'])}, email: {s(c['email'])} }},",
        "    lineas: [",
        ",\n".join(linea(l) for l in d["lineas"]),
        "    ],",
        f"    total: {dec(d['total'])},",
        f"    cantidad_lineas_vigentes: NumberInt({d['cantidad_lineas_vigentes']})",
        "  }"]))

OUT.write_text(
    "// Generado por scripts/exportar_migracion.py desde PostgreSQL (vista nosql_lab.documento_pedido).\n"
    "// Mateo Algañaraz - Base de Datos II - 2026 - TP Unidad 7. Datos de laboratorio, sin datos personales reales.\n"
    f"// {len(docs)} pedidos de Food Store con sus líneas, cliente, precios históricos y estado.\n"
    "// Se ejecuta desde consultas_mongodb.js con load(), sobre la base foodstore_nosql.\n"
    "const resultadoMigracion = db.pedidos.insertMany([\n" + ",\n".join(bloques) + "\n], { ordered: true });\n"
    "print(`Documentos insertados: ${Object.keys(resultadoMigracion.insertedIds).length}`);\n",
    encoding="utf-8")
print(f"{OUT} ({len(docs)} documentos)")
