// =====================================================================
// Mateo Algañaraz - Base de Datos II - 2026
// TP Unidad 7 - Consigna 7: prueba de laboratorio de dos afirmaciones de la IA.
//
// Afirmación 1 (IA): "$jsonSchema no puede verificar que total sea la suma de los subtotales.
//   Un validador con $expr ayuda solo de forma limitada, y en la práctica se confía en el código."
// Afirmación 2 (IA): "La transacción multi-documento (que requiere un replica set) asegura que
//   el pedido y los descuentos de stock se confirmen juntos."
//
// Se ejecuta dos veces (scripts/probar_afirmaciones.sh):
//   1. contra el servidor standalone del laboratorio (puerto 27017), con la colección ya
//      cargada por consultas_mongodb.js;
//   2. contra un replica set de un nodo (puerto 27018), solo para la parte de transacciones.
// =====================================================================

const SEP = (t) => print(`\n== ${t} ==`);
const hello = db.hello();
const topologia = hello.setName ? `replica set "${hello.setName}"` : "standalone";
print(`Servidor: MongoDB ${db.version()} (${topologia})`);

if (!hello.setName) {
  db = db.getSiblingDB("foodstore_nosql");

  SEP("Afirmación 1: el validador también controla las ACTUALIZACIONES del total");
  const antes = db.pedidos.findOne({ _id: NumberLong("2118") }, { total: 1, "lineas.cantidad": 1 });
  printjson({ antes_total: antes.total.toString(), antes_cantidades: antes.lineas.map((l) => l.cantidad) });

  // 1.a Cambiar una cantidad sin recalcular subtotal ni total -> debe rechazarse.
  try {
    db.pedidos.updateOne({ _id: NumberLong("2118") }, { $inc: { "lineas.0.cantidad": 1 } });
    print("1.a ACEPTADO (no debería): cantidad cambiada sin recalcular");
  } catch (e) {
    print(`1.a RECHAZADO por el validador: código ${e.code} - ${e.message}`);
  }

  // 1.b La misma modificación hecha bien (cantidad, subtotal y total en una sola escritura
  //     atómica de un documento) -> se acepta. Se revierte después.
  const doc = db.pedidos.findOne({ _id: NumberLong("2118") });
  const precio = doc.lineas[0].precio_unitario;
  const r = db.pedidos.updateOne(
    { _id: NumberLong("2118") },
    [{ $set: {
        "lineas": { $map: { input: "$lineas", as: "l", in: { $cond: [
          { $eq: ["$$l.id_producto", doc.lineas[0].id_producto] },
          { $mergeObjects: ["$$l", { cantidad: { $add: ["$$l.cantidad", 1] },
                                     subtotal: { $multiply: [{ $add: ["$$l.cantidad", 1] }, "$$l.precio_unitario"] } }] },
          "$$l"] } } } } },
     { $set: { total: { $sum: { $map: {
        input: { $filter: { input: "$lineas", as: "l", cond: { $eq: ["$$l.anulada", false] } } },
        as: "l", in: "$$l.subtotal" } } } } }]
  );
  const despues = db.pedidos.findOne({ _id: NumberLong("2118") }, { total: 1 });
  print(`1.b ACEPTADO: modificadas=${r.modifiedCount}; total ${antes.total} -> ${despues.total} (+ ${precio})`);
  // Reversión al estado migrado.
  db.pedidos.replaceOne({ _id: NumberLong("2118") }, doc);
  print(`    revertido: total = ${db.pedidos.findOne({ _id: NumberLong("2118") }).total}`);
}

SEP("Afirmación 2: transacción multi-documento (pedido + descuento de stock)");
const lab = db.getSiblingDB("foodstore_tx_lab");
lab.productos.drop();
lab.pedidos.drop();
lab.productos.insertOne({ _id: NumberInt(3373), stock: NumberInt(5) });
lab.createCollection("pedidos");

const session = db.getMongo().startSession();
try {
  session.startTransaction();
  const prod = session.getDatabase("foodstore_tx_lab").productos;
  const ped = session.getDatabase("foodstore_tx_lab").pedidos;
  const u = prod.updateOne({ _id: NumberInt(3373), stock: { $gte: 2 } }, { $inc: { stock: -2 } });
  if (u.modifiedCount !== 1) throw new Error("sin stock");
  ped.insertOne({ _id: NumberLong("700001"), lineas: [{ id_producto: NumberInt(3373), cantidad: NumberInt(2) }] });
  session.commitTransaction();
  print(`Transacción CONFIRMADA: stock=${lab.productos.findOne().stock}, pedidos=${lab.pedidos.countDocuments()}`);
} catch (e) {
  try { session.abortTransaction(); } catch (_) { /* sin transacción abierta */ }
  print(`Transacción FALLIDA: código ${e.code} - ${e.message}`);
  print(`Estado tras el fallo: stock=${lab.productos.findOne().stock}, pedidos=${lab.pedidos.countDocuments()}`);
} finally {
  session.endSession();
}
