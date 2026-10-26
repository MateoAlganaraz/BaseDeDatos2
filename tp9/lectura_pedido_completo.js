// TP Unidad 7 - Lectura del pedido completo en MongoDB: un solo documento por _id.
//   mongosh --quiet "mongodb://localhost:27017/foodstore_nosql" lectura_pedido_completo.js
db = db.getSiblingDB("foodstore_nosql");
const e = db.pedidos.find({ _id: NumberLong("2118") }).explain("executionStats");
printjson({
  etapa: e.queryPlanner.winningPlan.stage,
  documentos_examinados: e.executionStats.totalDocsExamined,
  devueltos: e.executionStats.nReturned,
  tiempo_ms: e.executionStats.executionTimeMillis
});
