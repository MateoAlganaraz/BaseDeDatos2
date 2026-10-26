// =====================================================================
// Mateo Algañaraz - Base de Datos II - 2026
// TP Unidad 7 - NoSQL: lado MongoDB (mongosh).
//
//   cd tp9
//   mongosh --quiet "mongodb://localhost:27017/foodstore_nosql" consultas_mongodb.js
//
// 1. Crea la colección pedidos con un validador que aplica las dos reglas de integridad.
// 2. Migra los 12 pedidos con insertMany() (migracion_mongodb.js, generado desde PostgreSQL).
// 3. Verifica la migración y prueba que el validador rechaza documentos inválidos.
// 4. Ejecuta las consultas a) a d) de la Consigna 4.
// Es idempotente: borra y vuelve a crear la colección en cada ejecución.
// =====================================================================

const SEP = (titulo) => print(`\n== ${titulo} ==`);

db = db.getSiblingDB("foodstore_nosql");
db.pedidos.drop();

// ---------------------------------------------------------------------
// 1. Colección con validador
// Regla 1: total = suma de cantidad × precio_unitario de las líneas no anuladas
//          (y cada subtotal = cantidad × precio_unitario, con el precio histórico cobrado).
// Regla 2: un producto aparece una sola vez por pedido (PK compuesta de detalle_pedido),
//          cantidad > 0 y precio_unitario > 0; el _id es el id_pedido de PostgreSQL.
// ---------------------------------------------------------------------
db.createCollection("pedidos", {
  validator: {
    $and: [
      {
        $jsonSchema: {
          bsonType: "object",
          required: ["_id", "fecha", "estado", "forma_pago", "cliente", "lineas", "total"],
          properties: {
            _id: { bsonType: "long", description: "id_pedido de PostgreSQL" },
            fecha: { bsonType: "date" },
            estado: { enum: ["VIGENTE", "ANULADO"] },
            anulado_en: { bsonType: ["date", "null"] },
            forma_pago: { enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"] },
            cliente: {
              bsonType: "object",
              required: ["id_cliente", "nombre", "apellido", "email"],
              properties: { id_cliente: { bsonType: "long" } }
            },
            lineas: {
              bsonType: "array",
              minItems: 1,
              items: {
                bsonType: "object",
                required: ["id_producto", "producto", "cantidad", "precio_unitario", "subtotal", "anulada"],
                properties: {
                  id_producto: { bsonType: "int" },
                  cantidad: { bsonType: "int", minimum: 1 },
                  precio_unitario: { bsonType: "decimal", minimum: 0, exclusiveMinimum: true },
                  subtotal: { bsonType: "decimal" },
                  anulada: { bsonType: "bool" }
                }
              }
            },
            total: { bsonType: "decimal", minimum: 0 }
          }
        }
      },
      {
        $expr: {
          $and: [
            // Regla 2: id_producto sin repetir dentro del pedido.
            { $eq: [{ $size: "$lineas.id_producto" }, { $size: { $setUnion: ["$lineas.id_producto", []] } }] },
            // Regla 1a: cada subtotal = cantidad × precio_unitario.
            { $allElementsTrue: [{ $map: { input: "$lineas", as: "l",
                in: { $eq: ["$$l.subtotal", { $multiply: ["$$l.cantidad", "$$l.precio_unitario"] }] } } }] },
            // Regla 1b: total = suma de subtotales de líneas no anuladas.
            { $eq: ["$total", { $sum: { $map: {
                input: { $filter: { input: "$lineas", as: "l", cond: { $eq: ["$$l.anulada", false] } } },
                as: "l", in: "$$l.subtotal" } } }] }
          ]
        }
      }
    ]
  },
  validationLevel: "strict",
  validationAction: "error"
});

// ---------------------------------------------------------------------
// 2. Migración
// ---------------------------------------------------------------------
SEP("2. Migración con insertMany()");
load("migracion_mongodb.js");

// Índices para las consultas b), c) y d).
db.pedidos.createIndex({ estado: 1 });
db.pedidos.createIndex({ "lineas.id_producto": 1 });
db.pedidos.createIndex({ total: -1 });

// ---------------------------------------------------------------------
// 3. Verificación
// ---------------------------------------------------------------------
SEP("3. Verificación de la migración");
printjson({
  documentos: db.pedidos.countDocuments(),
  lineas: db.pedidos.aggregate([{ $unwind: "$lineas" }, { $count: "n" }]).toArray()[0].n,
  importe_total_vigente: db.pedidos.aggregate([
    { $match: { estado: "VIGENTE" } }, { $group: { _id: null, t: { $sum: "$total" } } }]).toArray()[0].t.toString()
});

SEP("3. Documento completo de ejemplo (pedido 2118)");
printjson(db.pedidos.findOne({ _id: NumberLong("2118") }));

SEP("3. El validador rechaza documentos que violan las reglas (se esperan 3 rechazos)");
const invalidos = [
  { caso: "total que no coincide con las líneas (regla 1)",
    doc: { _id: NumberLong("900001"), fecha: new Date(), estado: "VIGENTE", anulado_en: null, forma_pago: "EFECTIVO",
           cliente: { id_cliente: NumberLong("1"), nombre: "Prueba", apellido: "Prueba", email: "prueba@example.invalid" },
           lineas: [{ id_producto: NumberInt(1), producto: "X", cantidad: NumberInt(2), precio_unitario: NumberDecimal("100.00"),
                      subtotal: NumberDecimal("200.00"), anulada: false }],
           total: NumberDecimal("999.00") } },
  { caso: "producto repetido en el mismo pedido (regla 2)",
    doc: { _id: NumberLong("900002"), fecha: new Date(), estado: "VIGENTE", anulado_en: null, forma_pago: "EFECTIVO",
           cliente: { id_cliente: NumberLong("1"), nombre: "Prueba", apellido: "Prueba", email: "prueba@example.invalid" },
           lineas: [{ id_producto: NumberInt(1), producto: "X", cantidad: NumberInt(1), precio_unitario: NumberDecimal("100.00"),
                      subtotal: NumberDecimal("100.00"), anulada: false },
                    { id_producto: NumberInt(1), producto: "X", cantidad: NumberInt(1), precio_unitario: NumberDecimal("100.00"),
                      subtotal: NumberDecimal("100.00"), anulada: false }],
           total: NumberDecimal("200.00") } },
  { caso: "cantidad 0 (regla 2)",
    doc: { _id: NumberLong("900003"), fecha: new Date(), estado: "VIGENTE", anulado_en: null, forma_pago: "EFECTIVO",
           cliente: { id_cliente: NumberLong("1"), nombre: "Prueba", apellido: "Prueba", email: "prueba@example.invalid" },
           lineas: [{ id_producto: NumberInt(1), producto: "X", cantidad: NumberInt(0), precio_unitario: NumberDecimal("100.00"),
                      subtotal: NumberDecimal("0.00"), anulada: false }],
           total: NumberDecimal("0.00") } }
];
// Resume errInfo: qué cláusula del validador falló ($jsonSchema o $expr) y sobre qué campo.
function resumirValidacion(d, ruta = []) {
  if (!d || typeof d !== "object") return "";
  if (Array.isArray(d)) return d.map((x) => resumirValidacion(x, ruta)).filter(Boolean).join("; ");
  if (d.operatorName === "$expr") return "$expr (reglas de total o productos repetidos)";
  const r = d.propertyName ? [...ruta, d.propertyName] : ruta;
  if (d.reason && d.operatorName !== "items") return `$jsonSchema ${r.join(".")}: ${d.operatorName} (${d.reason})`;
  return Object.values(d).map((v) => resumirValidacion(v, r)).filter(Boolean).join("; ");
}
for (const { caso, doc } of invalidos) {
  try {
    db.pedidos.insertOne(doc);
    print(`ACEPTADO (no debería): ${caso}`);
  } catch (e) {
    print(`RECHAZADO: ${caso} -> código ${e.code}: ${e.message} [${resumirValidacion(e.errInfo?.details)}]`);
  }
}
print(`Documentos después de las pruebas: ${db.pedidos.countDocuments()}`);

// ---------------------------------------------------------------------
// 4. Consultas de la Consigna 4
// ---------------------------------------------------------------------
SEP("4.a Todos los pedidos con su identificador y estado");
db.pedidos.find({}, { _id: 1, estado: 1 }).sort({ _id: 1 }).forEach((d) => print(`${d._id}\t${d.estado}`));

SEP("4.b Pedidos con estado ANULADO");
const b = db.pedidos.find({ estado: "ANULADO" }, { _id: 1 }).sort({ _id: 1 }).toArray().map((d) => Number(d._id));
printjson({ cantidad: b.length, ids: b });

SEP("4.c (primera versión) Pedidos con el producto 3373 en el arreglo de líneas");
const c1 = db.pedidos.find({ "lineas.id_producto": 3373 }, { _id: 1 }).sort({ _id: 1 }).toArray().map((d) => Number(d._id));
printjson({ cantidad: c1.length, ids: c1 });

SEP("4.c (corregida) El producto 3373 en una línea NO anulada: $elemMatch sobre el mismo elemento");
const c2 = db.pedidos.find({ lineas: { $elemMatch: { id_producto: 3373, anulada: false } } }, { _id: 1 })
  .sort({ _id: 1 }).toArray().map((d) => Number(d._id));
printjson({ cantidad: c2.length, ids: c2 });

SEP("4.c Plan de la consulta corregida (usa el índice multiclave lineas.id_producto)");
const plan = db.pedidos.find({ lineas: { $elemMatch: { id_producto: 3373, anulada: false } } }).explain("executionStats");
const etapas = [];
let st = plan.queryPlanner.winningPlan;
while (st) { etapas.push(st.stage + (st.indexName ? `(${st.indexName})` : "")); st = st.inputStage; }
printjson({ etapas, documentos_examinados: plan.executionStats.totalDocsExamined,
            devueltos: plan.executionStats.nReturned });

SEP("4.d Pedidos con total > 20000 (umbral entre la mediana 14.487 y el P75 33.515 del subconjunto)");
db.pedidos.find({ total: { $gt: NumberDecimal("20000") } }, { _id: 1, estado: 1, total: 1 })
  .sort({ total: -1 }).forEach((d) => print(`${d._id}\t${d.estado}\t${d.total}`));

SEP("4.d Solo pedidos VIGENTES con total > 20000");
db.pedidos.find({ estado: "VIGENTE", total: { $gt: NumberDecimal("20000") } }, { _id: 1, total: 1 })
  .sort({ total: -1 }).forEach((d) => print(`${d._id}\t${d.total}`));
