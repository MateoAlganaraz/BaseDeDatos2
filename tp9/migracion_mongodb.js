// Generado por scripts/exportar_migracion.py desde PostgreSQL (vista nosql_lab.documento_pedido).
// Mateo Algañaraz - Base de Datos II - 2026 - TP Unidad 7. Datos de laboratorio, sin datos personales reales.
// 12 pedidos de Food Store con sus líneas, cliente, precios históricos y estado.
// Se ejecuta desde consultas_mongodb.js con load(), sobre la base foodstore_nosql.
const resultadoMigracion = db.pedidos.insertMany([
  {
    _id: NumberLong(1),
    fecha: ISODate("2026-10-25T05:11:59.000Z"),
    estado: "VIGENTE",
    anulado_en: null,
    forma_pago: "TARJETA",
    cliente: { id_cliente: NumberLong(32), nombre: "Cliente00032", apellido: "TP600032", email: "tp6_cliente_00032@example.invalid" },
    lineas: [
      { id_producto: NumberInt(14), producto: "TP6_PRODUCTO_00014", categoria: "Almacén", cantidad: NumberInt(4), precio_unitario: NumberDecimal("968.00"), subtotal: NumberDecimal("3872.00"), anulada: false },
      { id_producto: NumberInt(7933), producto: "TP6_PRODUCTO_07933", categoria: "Almacén", cantidad: NumberInt(5), precio_unitario: NumberDecimal("1971.00"), subtotal: NumberDecimal("9855.00"), anulada: false }
    ],
    total: NumberDecimal("13727.00"),
    cantidad_lineas_vigentes: NumberInt(2)
  },
  {
    _id: NumberLong(2),
    fecha: ISODate("2026-10-24T07:23:58.000Z"),
    estado: "VIGENTE",
    anulado_en: null,
    forma_pago: "TRANSFERENCIA",
    cliente: { id_cliente: NumberLong(63), nombre: "Cliente00063", apellido: "TP600063", email: "tp6_cliente_00063@example.invalid" },
    lineas: [
      { id_producto: NumberInt(27), producto: "TP6_PRODUCTO_00027", categoria: "Lácteos", cantidad: NumberInt(1), precio_unitario: NumberDecimal("1749.00"), subtotal: NumberDecimal("1749.00"), anulada: false },
      { id_producto: NumberInt(5865), producto: "TP6_PRODUCTO_05865", categoria: "Panadería", cantidad: NumberInt(3), precio_unitario: NumberDecimal("1905.00"), subtotal: NumberDecimal("5715.00"), anulada: false },
      { id_producto: NumberInt(7946), producto: "TP6_PRODUCTO_07946", categoria: "Panadería", cantidad: NumberInt(2), precio_unitario: NumberDecimal("902.00"), subtotal: NumberDecimal("1804.00"), anulada: false }
    ],
    total: NumberDecimal("9268.00"),
    cantidad_lineas_vigentes: NumberInt(3)
  },
  {
    _id: NumberLong(3),
    fecha: ISODate("2026-10-23T09:35:57.000Z"),
    estado: "VIGENTE",
    anulado_en: null,
    forma_pago: "EFECTIVO",
    cliente: { id_cliente: NumberLong(94), nombre: "Cliente00094", apellido: "TP600094", email: "tp6_cliente_00094@example.invalid" },
    lineas: [
      { id_producto: NumberInt(40), producto: "TP6_PRODUCTO_00040", categoria: "Congelados", cantidad: NumberInt(4), precio_unitario: NumberDecimal("2830.00"), subtotal: NumberDecimal("11320.00"), anulada: false },
      { id_producto: NumberInt(3797), producto: "TP6_PRODUCTO_03797", categoria: "Snacks", cantidad: NumberInt(1), precio_unitario: NumberDecimal("2289.00"), subtotal: NumberDecimal("2289.00"), anulada: false },
      { id_producto: NumberInt(5878), producto: "TP6_PRODUCTO_05878", categoria: "Perfumería", cantidad: NumberInt(6), precio_unitario: NumberDecimal("3136.00"), subtotal: NumberDecimal("18816.00"), anulada: false },
      { id_producto: NumberInt(7959), producto: "TP6_PRODUCTO_07959", categoria: "Limpieza", cantidad: NumberInt(5), precio_unitario: NumberDecimal("1983.00"), subtotal: NumberDecimal("9915.00"), anulada: false }
    ],
    total: NumberDecimal("42340.00"),
    cantidad_lineas_vigentes: NumberInt(4)
  },
  {
    _id: NumberLong(7),
    fecha: ISODate("2026-10-19T18:23:53.000Z"),
    estado: "ANULADO",
    anulado_en: ISODate("2026-10-19T20:23:53.000Z"),
    forma_pago: "TARJETA",
    cliente: { id_cliente: NumberLong(218), nombre: "Cliente00218", apellido: "TP600218", email: "tp6_cliente_00218@example.invalid" },
    lineas: [
      { id_producto: NumberInt(92), producto: "TP6_PRODUCTO_00092", categoria: "Snacks", cantidad: NumberInt(4), precio_unitario: NumberDecimal("3204.00"), subtotal: NumberDecimal("12816.00"), anulada: false },
      { id_producto: NumberInt(3849), producto: "TP6_PRODUCTO_03849", categoria: "Almacén", cantidad: NumberInt(1), precio_unitario: NumberDecimal("863.00"), subtotal: NumberDecimal("863.00"), anulada: false },
      { id_producto: NumberInt(5930), producto: "TP6_PRODUCTO_05930", categoria: "Mascotas", cantidad: NumberInt(6), precio_unitario: NumberDecimal("3510.00"), subtotal: NumberDecimal("21060.00"), anulada: false },
      { id_producto: NumberInt(8011), producto: "TP6_PRODUCTO_08011", categoria: "Golosinas", cantidad: NumberInt(5), precio_unitario: NumberDecimal("2357.00"), subtotal: NumberDecimal("11785.00"), anulada: false }
    ],
    total: NumberDecimal("46524.00"),
    cantidad_lineas_vigentes: NumberInt(4)
  },
  {
    _id: NumberLong(57),
    fecha: ISODate("2026-08-30T08:23:03.000Z"),
    estado: "ANULADO",
    anulado_en: ISODate("2026-08-30T10:23:03.000Z"),
    forma_pago: "EFECTIVO",
    cliente: { id_cliente: NumberLong(1768), nombre: "Cliente01768", apellido: "TP601768", email: "tp6_cliente_01768@example.invalid" },
    lineas: [
      { id_producto: NumberInt(742), producto: "TP6_PRODUCTO_00742", categoria: "Verdulería", cantidad: NumberInt(4), precio_unitario: NumberDecimal("2654.00"), subtotal: NumberDecimal("10616.00"), anulada: false },
      { id_producto: NumberInt(8661), producto: "TP6_PRODUCTO_08661", categoria: "Verdulería", cantidad: NumberInt(5), precio_unitario: NumberDecimal("1657.00"), subtotal: NumberDecimal("8285.00"), anulada: false }
    ],
    total: NumberDecimal("18901.00"),
    cantidad_lineas_vigentes: NumberInt(2)
  },
  {
    _id: NumberLong(107),
    fecha: ISODate("2026-07-11T22:22:13.000Z"),
    estado: "ANULADO",
    anulado_en: ISODate("2026-07-12T00:22:13.000Z"),
    forma_pago: "TRANSFERENCIA",
    cliente: { id_cliente: NumberLong(3318), nombre: "Cliente03318", apellido: "TP603318", email: "tp6_cliente_03318@example.invalid" },
    lineas: [
      { id_producto: NumberInt(1392), producto: "TP6_PRODUCTO_01392", categoria: "Bebidas", cantidad: NumberInt(4), precio_unitario: NumberDecimal("2104.00"), subtotal: NumberDecimal("8416.00"), anulada: false },
      { id_producto: NumberInt(5149), producto: "TP6_PRODUCTO_05149", categoria: "Panadería", cantidad: NumberInt(1), precio_unitario: NumberDecimal("1413.00"), subtotal: NumberDecimal("1413.00"), anulada: false },
      { id_producto: NumberInt(7230), producto: "TP6_PRODUCTO_07230", categoria: "Panadería", cantidad: NumberInt(6), precio_unitario: NumberDecimal("2410.00"), subtotal: NumberDecimal("14460.00"), anulada: false },
      { id_producto: NumberInt(9311), producto: "TP6_PRODUCTO_09311", categoria: "Lácteos", cantidad: NumberInt(5), precio_unitario: NumberDecimal("1257.00"), subtotal: NumberDecimal("6285.00"), anulada: false }
    ],
    total: NumberDecimal("30574.00"),
    cantidad_lineas_vigentes: NumberInt(4)
  },
  {
    _id: NumberLong(2118),
    fecha: ISODate("2026-01-06T06:00:42.000Z"),
    estado: "VIGENTE",
    anulado_en: null,
    forma_pago: "EFECTIVO",
    cliente: { id_cliente: NumberLong(5659), nombre: "Cliente05659", apellido: "TP605659", email: "tp6_cliente_05659@example.invalid" },
    lineas: [
      { id_producto: NumberInt(3373), producto: "TP6_PRODUCTO_03373", categoria: "Almacén", cantidad: NumberInt(3), precio_unitario: NumberDecimal("1251.00"), subtotal: NumberDecimal("3753.00"), anulada: false },
      { id_producto: NumberInt(5454), producto: "TP6_PRODUCTO_05454", categoria: "Almacén", cantidad: NumberInt(2), precio_unitario: NumberDecimal("2248.00"), subtotal: NumberDecimal("4496.00"), anulada: false },
      { id_producto: NumberInt(7535), producto: "TP6_PRODUCTO_07535", categoria: "Mascotas", cantidad: NumberInt(1), precio_unitario: NumberDecimal("2895.00"), subtotal: NumberDecimal("2895.00"), anulada: false }
    ],
    total: NumberDecimal("11144.00"),
    cantidad_lineas_vigentes: NumberInt(3)
  },
  {
    _id: NumberLong(5355),
    fecha: ISODate("2026-02-23T22:30:45.000Z"),
    estado: "VIGENTE",
    anulado_en: null,
    forma_pago: "EFECTIVO",
    cliente: { id_cliente: NumberLong(6006), nombre: "Cliente06006", apellido: "TP606006", email: "tp6_cliente_06006@example.invalid" },
    lineas: [
      { id_producto: NumberInt(3373), producto: "TP6_PRODUCTO_03373", categoria: "Almacén", cantidad: NumberInt(1), precio_unitario: NumberDecimal("1251.00"), subtotal: NumberDecimal("1251.00"), anulada: false },
      { id_producto: NumberInt(5454), producto: "TP6_PRODUCTO_05454", categoria: "Almacén", cantidad: NumberInt(6), precio_unitario: NumberDecimal("2248.00"), subtotal: NumberDecimal("13488.00"), anulada: false },
      { id_producto: NumberInt(7535), producto: "TP6_PRODUCTO_07535", categoria: "Mascotas", cantidad: NumberInt(5), precio_unitario: NumberDecimal("2895.00"), subtotal: NumberDecimal("14475.00"), anulada: false },
      { id_producto: NumberInt(9616), producto: "TP6_PRODUCTO_09616", categoria: "Golosinas", cantidad: NumberInt(4), precio_unitario: NumberDecimal("3742.00"), subtotal: NumberDecimal("14968.00"), anulada: false }
    ],
    total: NumberDecimal("44182.00"),
    cantidad_lineas_vigentes: NumberInt(4)
  },
  {
    _id: NumberLong(5644),
    fecha: ISODate("2026-05-10T10:13:56.000Z"),
    estado: "VIGENTE",
    anulado_en: null,
    forma_pago: "TARJETA",
    cliente: { id_cliente: NumberLong(14965), nombre: "Cliente14965", apellido: "TP614965", email: "tp6_cliente_14965@example.invalid" },
    lineas: [
      { id_producto: NumberInt(3373), producto: "TP6_PRODUCTO_03373", categoria: "Almacén", cantidad: NumberInt(1), precio_unitario: NumberDecimal("1251.00"), subtotal: NumberDecimal("1251.00"), anulada: false }
    ],
    total: NumberDecimal("1251.00"),
    cantidad_lineas_vigentes: NumberInt(1)
  },
  {
    _id: NumberLong(8881),
    fecha: ISODate("2026-06-28T02:43:59.000Z"),
    estado: "VIGENTE",
    anulado_en: null,
    forma_pago: "TARJETA",
    cliente: { id_cliente: NumberLong(15312), nombre: "Cliente15312", apellido: "TP615312", email: "tp6_cliente_15312@example.invalid" },
    lineas: [
      { id_producto: NumberInt(3373), producto: "TP6_PRODUCTO_03373", categoria: "Almacén", cantidad: NumberInt(5), precio_unitario: NumberDecimal("1251.00"), subtotal: NumberDecimal("6255.00"), anulada: false },
      { id_producto: NumberInt(5454), producto: "TP6_PRODUCTO_05454", categoria: "Almacén", cantidad: NumberInt(4), precio_unitario: NumberDecimal("2248.00"), subtotal: NumberDecimal("8992.00"), anulada: false }
    ],
    total: NumberDecimal("15247.00"),
    cantidad_lineas_vigentes: NumberInt(2)
  },
  {
    _id: NumberLong(12118),
    fecha: ISODate("2026-08-14T19:14:02.000Z"),
    estado: "VIGENTE",
    anulado_en: null,
    forma_pago: "TARJETA",
    cliente: { id_cliente: NumberLong(15659), nombre: "Cliente15659", apellido: "TP615659", email: "tp6_cliente_15659@example.invalid" },
    lineas: [
      { id_producto: NumberInt(3373), producto: "TP6_PRODUCTO_03373", categoria: "Almacén", cantidad: NumberInt(3), precio_unitario: NumberDecimal("1251.00"), subtotal: NumberDecimal("3753.00"), anulada: false },
      { id_producto: NumberInt(5454), producto: "TP6_PRODUCTO_05454", categoria: "Almacén", cantidad: NumberInt(2), precio_unitario: NumberDecimal("2248.00"), subtotal: NumberDecimal("4496.00"), anulada: false },
      { id_producto: NumberInt(7535), producto: "TP6_PRODUCTO_07535", categoria: "Mascotas", cantidad: NumberInt(1), precio_unitario: NumberDecimal("2895.00"), subtotal: NumberDecimal("2895.00"), anulada: false }
    ],
    total: NumberDecimal("11144.00"),
    cantidad_lineas_vigentes: NumberInt(3)
  },
  {
    _id: NumberLong(598881),
    fecha: ISODate("2026-01-18T14:50:39.000Z"),
    estado: "VIGENTE",
    anulado_en: null,
    forma_pago: "EFECTIVO",
    cliente: { id_cliente: NumberLong(5312), nombre: "Cliente05312", apellido: "TP605312", email: "tp6_cliente_05312@example.invalid" },
    lineas: [
      { id_producto: NumberInt(3373), producto: "TP6_PRODUCTO_03373", categoria: "Almacén", cantidad: NumberInt(5), precio_unitario: NumberDecimal("1251.00"), subtotal: NumberDecimal("6255.00"), anulada: true },
      { id_producto: NumberInt(5454), producto: "TP6_PRODUCTO_05454", categoria: "Almacén", cantidad: NumberInt(4), precio_unitario: NumberDecimal("2248.00"), subtotal: NumberDecimal("8992.00"), anulada: true }
    ],
    total: NumberDecimal("0.00"),
    cantidad_lineas_vigentes: NumberInt(0)
  }
], { ordered: true });
print(`Documentos insertados: ${Object.keys(resultadoMigracion.insertedIds).length}`);
