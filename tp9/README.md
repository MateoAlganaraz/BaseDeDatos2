# TP9 - Unidad 7: NoSQL y nuevas formas de almacenamiento

Subconjunto "pedidos y detalle de pedidos" de Food Store representado en MongoDB, consultado en ambos motores y comparado. Ejecutado con PostgreSQL 16.15 (base `foodstore`) y **MongoDB 8.0.4** con mongosh 2.3.8. Todas las cifras salen de `evidencia/`.

## Entregables

| Consigna | Archivo |
|---|---|
| PDF (hasta 5 páginas) | [`informe_u7.pdf`](informe_u7.pdf): modelo, evidencias, tabla de verificación, contraste de la IA y conclusión. `DB_Mateo_Algañaraz.pdf` es la misma copia para la plataforma. |
| `consultas_mongodb.js` | [`consultas_mongodb.js`](consultas_mongodb.js): colección con validador, migración, verificación y consultas a) a d). |
| `consultas_postgresql.sql` | [`consultas_postgresql.sql`](consultas_postgresql.sql): claves del subconjunto, selección de pedidos, documentos, consultas b) y c) y reglas. |

Archivos de apoyo:

| Archivo | Para qué sirve |
|---|---|
| `migracion_mongodb.js` | El `insertMany()` generado desde PostgreSQL con `scripts/exportar_migracion.py`. |
| `pruebas_afirmaciones_ia.js` y `scripts/probar_afirmaciones.sh` | Laboratorio de las dos afirmaciones de la IA (Consigna 7). |
| `lectura_pedido_completo.sql` / `.js` | Costo de leer un pedido completo en cada motor. |
| `ia/` | Prompt y respuesta completa de la IA. |
| `evidencia/` | Salidas completas de cada ejecución. |

## Modelo

Un documento por pedido en la colección `pedidos`:

- `_id` es el `id_pedido` original.
- `cliente` es un objeto embebido (snapshot) que conserva `id_cliente`.
- `lineas` es un arreglo embebido con `id_producto`, `cantidad`, el precio histórico `precio_unitario` (Decimal128), `subtotal` y `anulada`.
- `total` es la suma de las líneas no anuladas.
- `estado` vale `VIGENTE` o `ANULADO` y se deriva del borrado lógico, porque el esquema real no tiene una columna de estado.

Un validador `$jsonSchema` + `$expr` aplica las dos reglas de integridad: coherencia de importes, y unicidad de producto por pedido con cantidades y precios positivos.

## Resultados

| Consulta | PostgreSQL | MongoDB | IDs |
|---|---|---|---|
| b) estado ANULADO | 3 (7, 57, 107) | 3 (7, 57, 107) | coinciden |
| c) producto 3373, primera versión | 5 | 6 (incluye 598881, con la línea anulada) | **no coinciden** |
| c) producto 3373, corregida con `$elemMatch` | 5 | 5 | coinciden |

La IA recomendó mantener PostgreSQL. De sus afirmaciones se contrastaron dos:

- **"Un validador con `$expr` ayuda solo de forma limitada": imprecisa.** El validador rechazó totales incoherentes tanto al insertar como al actualizar.
- **"Las transacciones multi-documento requieren un replica set": correcta.** La transacción falló en el servidor standalone (código 20) y se confirmó en un replica set de un nodo.

Conclusión: mantener PostgreSQL como sistema de registro.

## Reproducir

Requisitos: la base `foodstore` del TP8, incluida `tp8/sql/01_simular_actividad.sql`, que anula las líneas del pedido 598881. Además, MongoDB Community Server 8.0 y mongosh. En Windows se instalan desde mongodb.com y el servicio queda en `localhost:27017`.

```bash
psql -X -d foodstore -f tp9/consultas_postgresql.sql
python tp9/scripts/exportar_migracion.py          # regenera migracion_mongodb.js
cd tp9
mongosh --quiet "mongodb://localhost:27017/foodstore_nosql" consultas_mongodb.js
mongosh --quiet "mongodb://localhost:27017/foodstore_nosql" pruebas_afirmaciones_ia.js   # parte standalone
python build_informe_pdf.py
```

`scripts/probar_afirmaciones.sh` (Linux) también levanta un replica set temporal en el puerto 27018 para la prueba de transacciones.

**Uso de IA:** la herramienta consultada en la Consigna 6 fue Claude (Anthropic), en una instancia sin acceso al repositorio. Claude también asistió en la redacción de los scripts, y cada uno se verificó ejecutándolo en ambos motores.
