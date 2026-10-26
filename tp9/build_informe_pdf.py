"""Genera tp9/informe_u7.pdf (y la copia DB_Mateo_Algañaraz.pdf) desde las evidencias.

Uso: python tp9/build_informe_pdf.py
"""
import shutil
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import KeepTogether, Paragraph, Preformatted, SimpleDocTemplate, Spacer, Table, TableStyle

ROOT = Path(__file__).resolve().parent
EVID = ROOT / "evidencia"
OUT = ROOT / "informe_u7.pdf"


def fonts():
    names = {"Sans": "DejaVuSans.ttf", "Sans-Bold": "DejaVuSans-Bold.ttf", "Mono": "DejaVuSansMono.ttf"}
    for d in (Path("/usr/share/fonts/truetype/dejavu"), Path("C:/Windows/Fonts")):
        if all((d / f).exists() for f in names.values()):
            for n, f in names.items():
                pdfmetrics.registerFont(TTFont(n, str(d / f)))
            pdfmetrics.registerFontFamily("Sans", normal="Sans", bold="Sans-Bold", italic="Sans", boldItalic="Sans-Bold")
            return "Sans", "Sans-Bold", "Mono"
    return "Helvetica", "Helvetica-Bold", "Courier"


BODY, BOLD, MONO = fonts()
BLUE = colors.HexColor("#2E5C8A")
ss = getSampleStyleSheet()
st = {
    "title": ParagraphStyle("t", parent=ss["Title"], fontName=BOLD, fontSize=14, leading=17, textColor=BLUE, spaceAfter=2),
    "sub": ParagraphStyle("s", parent=ss["BodyText"], fontName=BODY, fontSize=8, leading=10, alignment=1, spaceAfter=4),
    "h": ParagraphStyle("h", parent=ss["Heading2"], fontName=BOLD, fontSize=10.5, leading=13, textColor=BLUE,
                        spaceBefore=6, spaceAfter=3),
    "body": ParagraphStyle("b", parent=ss["BodyText"], fontName=BODY, fontSize=8, leading=10.3, spaceAfter=3),
    "cell": ParagraphStyle("c", parent=ss["BodyText"], fontName=BODY, fontSize=7.4, leading=9),
    "cellb": ParagraphStyle("cb", parent=ss["BodyText"], fontName=BOLD, fontSize=7.4, leading=9, textColor=colors.white),
    "code": ParagraphStyle("code", fontName=MONO, fontSize=6, leading=7.3),
    "cap": ParagraphStyle("cap", parent=ss["BodyText"], fontName=BODY, fontSize=7.2, leading=9,
                          textColor=colors.HexColor("#555555"), spaceAfter=5),
}


def p(t, s="body"):
    return Paragraph(t, st[s])


def table(rows, widths):
    data = [[Paragraph(str(c), st["cellb"]) for c in rows[0]]] + [[Paragraph(str(c), st["cell"]) for c in r] for r in rows[1:]]
    t = Table(data, colWidths=widths, hAlign="LEFT", repeatRows=1)
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), BLUE), ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#C8C8C8")),
                           ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                           ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#EEF3F8")]),
                           ("TOPPADDING", (0, 0), (-1, -1), 2), ("BOTTOMPADDING", (0, 0), (-1, -1), 2)]))
    return t


def bloque(texto, caption):
    pre = Preformatted(texto.rstrip(), st["code"], maxLineLength=150, newLineChars="")
    box = Table([[pre]], colWidths=[18 * cm])
    box.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F6F6F6")),
                             ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#A0A0A0"))]))
    return KeepTogether([box, p(caption, "cap")])


def seccion(nombre, desde, hasta=None):
    lineas = (EVID / nombre).read_text(encoding="utf-8").splitlines()
    i = next(n for n, l in enumerate(lineas) if desde in l)
    out = []
    for l in lineas[i:]:
        if hasta and hasta in l and out:
            break
        out.append(l)
    return "\n".join(out)


def compacto(texto):
    # Une los arreglos que mongosh imprime en varias líneas para ahorrar espacio.
    import re
    texto = re.sub(r"\[\s+([^\[\]]*?)\s+\]", lambda m: "[" + re.sub(r"\s+", " ", m.group(1)) + "]", texto)
    return texto


def objetos_en_linea(texto):
    # Une en una sola línea cada objeto anidado del arreglo de líneas (para la evidencia del documento).
    import re
    return re.sub(r"\{\n((?:\s{6}[^\n]*\n)+)\s{4}\}", lambda m: "{ " + " ".join(x.strip() for x in m.group(1).splitlines()) + " }", texto)


def footer(c, d):
    c.saveState()
    c.setFont(BODY, 7)
    c.setFillColor(colors.HexColor("#666666"))
    c.drawString(1.5 * cm, 0.9 * cm, "Tecnicatura Universitaria en Programación - UTN - Base de Datos II")
    c.drawRightString(A4[0] - 1.5 * cm, 0.9 * cm, f"TP Unidad 7 - página {d.page}")
    c.restoreState()



S = [p("TP Unidad 7 - NoSQL y nuevas formas de almacenamiento: Food Store", "title"),
     p("Base de Datos II - Integrante: Mateo Algañaraz - Repositorio MateoAlganaraz/BaseDeDatos2, carpeta <b>tp9/</b> - "
       "PostgreSQL 16.15 y MongoDB 8.0.4 (mongosh 2.3.8)", "sub"),

     p("1. Subconjunto y modelo documental (Consigna 1)", "h"),
     p("<b>Tablas y claves en PostgreSQL:</b> <i>pedido</i> (PK id_pedido; FK id_cliente → cliente), <i>detalle_pedido</i> "
       "(PK compuesta id_pedido + id_producto; FK a pedido y a producto; CHECK cantidad &gt; 0 y precio &gt; 0), "
       "<i>cliente</i> (PK id_cliente), <i>producto</i> (PK id_producto; FK id_categoria) y <i>categoria</i>. El esquema real "
       "no tiene una columna <i>estado</i>: el estado se deriva del borrado lógico (<i>pedido.deleted_at</i> nulo → "
       "VIGENTE, si no ANULADO), y una línea anulada es <i>detalle_pedido.deleted_at</i> no nulo."),
     table([["Campo del documento (colección pedidos)", "Origen en PostgreSQL", "Tipo / decisión"],
            ["_id", "pedido.id_pedido", "Long. <b>Identificador conservado</b>"],
            ["fecha, forma_pago", "pedido.fecha, pedido.forma_pago", "Date, string"],
            ["estado, anulado_en", "pedido.deleted_at", "VIGENTE / ANULADO; fecha de anulación"],
            ["cliente {id_cliente, nombre, apellido, email}", "cliente", "<b>Objeto embebido</b> (snapshot); id_cliente conservado"],
            ["lineas [ {id_producto, producto, categoria, cantidad, precio_unitario, subtotal, anulada} ]",
             "detalle_pedido + producto + categoria", "<b>Arreglo embebido</b>; id_producto conservado; "
                                                      "<b>precio histórico</b> (precio_unitario cobrado) en Decimal128"],
            ["total, cantidad_lineas_vigentes", "Σ cantidad × precio_unitario de líneas no anuladas", "Decimal128 calculado"]],
           [6.3 * cm, 5.2 * cm, 6.5 * cm]),

     p("2. Migración y reglas de integridad (Consignas 2 y 3)", "h"),
     p("Se migraron <b>12 pedidos</b> con 34 líneas, elegidos para cubrir todos los casos: 3 vigentes sin el producto 3373, "
       "5 con el producto 3373, 3 anulados y el pedido 598881, cuya línea del producto 3373 está anulada. Son datos de "
       "laboratorio, sin personas reales. <i>scripts/exportar_migracion.py</i> genera <i>migracion_mongodb.js</i> "
       "(<b>insertMany</b>) desde la vista <i>nosql_lab.documento_pedido</i>. Resultado: \"Documentos insertados: 12\", con "
       "12 documentos, 34 líneas e importe vigente total de 148.303,00."),
     p("<b>Regla 1 - coherencia de importes:</b> cada subtotal = cantidad × precio_unitario histórico, y total = suma de "
       "subtotales de líneas no anuladas. El precio que manda es el cobrado, no el actual: en PostgreSQL el producto 3373 "
       "hoy cuesta 1.351,08, pero en el pedido 2118 se cobró a 1.251,00. Por eso el total con precio actual "
       "(11.803,92) difiere del histórico (11.144,00). <b>Regla 2 - identidad y unicidad:</b> _id = id_pedido, cada "
       "id_producto aparece una sola vez por pedido (PK compuesta), cantidad &gt; 0 y precio &gt; 0. Ambas reglas se "
       "aplican en el motor con un validador ($jsonSchema + $expr). Tres documentos inválidos fueron rechazados con el "
       "código 121: total incoherente, producto repetido y cantidad 0."),
     p("<b>Qué se embebió y por qué:</b> las líneas y el cliente se embeben porque la aplicación lee el pedido completo y "
       "las líneas no existen fuera de él (relación \"contiene\", uno a pocos, unas 2,5 líneas por pedido). Así se lee y se "
       "escribe en una sola operación atómica, y el cliente y el producto quedan como foto del momento de la compra. "
       "<b>No se embebieron</b> el stock ni el precio de lista: son estado compartido entre pedidos y deben tener una "
       "única fuente."),
     bloque(objetos_en_linea(seccion("02_mongodb.txt", "== 3. Documento completo", "== 3. El validador")),
            "Evidencia de la colección: documento migrado del pedido 2118, tal como lo devuelve findOne() en MongoDB 8.0.4."),
     bloque(compacto(seccion("02_mongodb.txt", "== 3. El validador", "Documentos después")),
            "Evidencia: rechazos del validador (evidencia/02_mongodb.txt)."),

     p("3. Consultas y verificación (Consignas 4 y 5)", "h"),
     bloque(seccion("02_mongodb.txt", "== 4.a", "== 4.b").replace("\t", "   "),
            "MongoDB a): todos los pedidos con su identificador (_id = id_pedido) y estado."),
     bloque(compacto(seccion("02_mongodb.txt", "== 4.b", "== 4.c Plan")).replace("\n\n", "\n"),
            "MongoDB: b) estado ANULADO; c) primera versión y versión corregida (evidencia/02_mongodb.txt; la consulta a) "
            "lista los 12 _id con su estado)."),
     bloque(seccion("02_mongodb.txt", "== 4.d Pedidos", None).replace("\t", "   "),
            "MongoDB d): total &gt; 20.000. El umbral está entre la mediana (14.487) y el P75 (33.515) de los totales "
            "migrados: marca los pedidos grandes, con más de 1,4 veces la mediana. Devuelve 4 (2 vigentes)."),
     bloque(seccion("01_postgresql.txt", "== 4.b", "== 4. Resumen"),
            "PostgreSQL: consultas equivalentes a b) y c) sobre los pedidos migrados (evidencia/01_postgresql.txt)."),
     table([["Consulta", "Cantidad en PostgreSQL", "Cantidad en MongoDB", "¿Coinciden los IDs?"],
            ["Estado seleccionado (ANULADO)", "3 (7, 57, 107)", "3 (7, 57, 107)", "Sí"],
            ["Producto seleccionado (3373), primera versión", "5 (2118, 5355, 5644, 8881, 12118)",
             "6 (los mismos + 598881)", "<b>No</b>"],
            ["Producto seleccionado (3373), corregida", "5 (2118, 5355, 5644, 8881, 12118)",
             "5 (2118, 5355, 5644, 8881, 12118)", "Sí"]],
           [5 * cm, 4.6 * cm, 4.6 * cm, 3.8 * cm]),
     Spacer(1, 0.1 * cm),
     p("<b>Diferencias detectadas y corrección.</b> (1) <b>Línea anulada:</b> la consulta en PostgreSQL filtra "
       "<i>deleted_at IS NULL</i>, pero la primera versión en MongoDB (<i>{\"lineas.id_producto\": 3373}</i>) también "
       "encontraba el pedido 598881, cuya línea está anulada. Se corrigió la consulta con <i>$elemMatch: {id_producto: "
       "3373, anulada: false}</i>, que aplica ambas condiciones al mismo elemento del arreglo; usa el índice multiclave "
       "lineas.id_producto (IXSCAN, 6 examinados, 5 devueltos). El modelo no se cambió: conservar la línea anulada es "
       "correcto, y PostgreSQL también la conserva. (2) <b>Alcance:</b> sin restringir al subconjunto, PostgreSQL devuelve "
       "12.000 pedidos anulados y 239 con el producto 3373. Por eso la comparación se hace sobre los 12 pedidos migrados "
       "(<i>nosql_lab.pedido_migrado</i>)."),

     p("4. Evaluación con IA y contraste (Consignas 6 y 7)", "h"),
     p("Se consultó a Claude (Anthropic), en una instancia sin acceso al repositorio. El prompt describía el modelo actual, "
       "el acceso frecuente a pedidos completos y la coherencia de cantidades, precios y stock "
       "(<i>ia/prompt_comparacion.md</i>; respuesta completa en <i>ia/respuesta_comparacion.md</i>). Recomendó mantener "
       "PostgreSQL y usar MongoDB, a lo sumo, como modelo de lectura. Se contrastaron dos afirmaciones:"),
     table([["Afirmación de la IA", "Documentación oficial", "Laboratorio", "Veredicto"],
            ["\"$jsonSchema no puede verificar que total sea la suma de los subtotales; un validador con $expr ayuda "
             "solo de forma limitada, y en la práctica se confía en el código.\"",
             "<i>Specify Validation With Query Operators</i>: el ejemplo usa $expr para exigir totalWithVAT = total × "
             "(1 + VAT). Solo excluye $function, $where, $near y $text.",
             "El validador con $expr rechazó un total incoherente al insertar y también un $inc de cantidad sin "
             "recalcular (código 121), y aceptó la misma actualización con subtotal y total recalculados.",
             "<b>Imprecisa.</b> El motor sí garantiza la regla dentro del documento. Lo que no cubre es lo que cruza "
             "documentos (stock)."],
            ["\"La transacción multi-documento (que requiere un replica set) asegura que el pedido y los descuentos de "
             "stock se confirmen juntos.\"",
             "<i>Transactions</i>: se soportan en replica sets y clusters fragmentados, con un costo mayor que las "
             "escrituras de un solo documento.",
             "En standalone: error 20 <i>\"Transaction numbers are only allowed on a replica set member or mongos\"</i>, "
             "y el stock queda intacto. En un replica set de un nodo: transacción confirmada, stock 5 → 3 y 1 pedido.",
             "<b>Correcta.</b> Sumar MongoDB para pedidos y stock exige operar un replica set."]],
           [4.8 * cm, 4.4 * cm, 5.3 * cm, 3.5 * cm]),
     Spacer(1, 0.1 * cm),
     bloque(seccion("03_pruebas_afirmaciones_ia.txt", "### 1.", None),
            "Laboratorio de las dos afirmaciones (pruebas_afirmaciones_ia.js, evidencia/03_pruebas_afirmaciones_ia.txt)."),
     p("Además, la IA propuso agregar <i>CHECK (stock &gt;= 0)</i>, una restricción que el esquema ya tiene "
       "(<i>ck_producto_stock_no_negativo</i>), y afirmó que a este volumen el rendimiento no decide. El laboratorio lo "
       "confirma: armar el pedido completo con JOIN y json_agg sobre 600.000 pedidos tarda 0,170 ms en PostgreSQL (tres "
       "Index Scan), y MongoDB lee el documento por _id (EXPRESS_IXSCAN, 1 examinado, 0 ms)."),

     p("5. Conclusión", "h"),
     p("Conviene <b>mantener PostgreSQL como sistema de registro de los pedidos</b> y usar MongoDB, si hiciera falta, solo "
       "como modelo de lectura sincronizado. <b>Criterio 1, integridad transaccional:</b> las reglas críticas de Food "
       "Store cruzan entidades. Descontar stock y registrar el pedido debe ser atómico, y PostgreSQL lo garantiza con "
       "ACID, FK y CHECK. En MongoDB, el laboratorio mostró que esa transacción falla en un servidor standalone y exige un "
       "replica set. <b>Criterio 2, patrón de acceso y rendimiento:</b> el documento embebido refleja bien la lectura del "
       "pedido completo y el validador con $expr protege total y líneas dentro del documento. Pero a este volumen "
       "PostgreSQL arma el mismo pedido en 0,17 ms con json_agg, así que no hay una ganancia que justifique duplicar "
       "datos. <b>Criterio 3, operación:</b> un segundo motor suma sincronización, respaldos y monitoreo. Combinar "
       "tecnologías se justificaría solo si la lectura del historial se vuelve un cuello de botella medido o si el "
       "esquema de los pedidos necesita variar mucho."),
     p("<b>Archivos:</b> consultas_mongodb.js, consultas_postgresql.sql, migracion_mongodb.js, pruebas_afirmaciones_ia.js, "
       "lectura_pedido_completo.sql/.js, scripts/ y evidencia/ (salidas completas). La herramienta de IA (Claude) también "
       "asistió en la redacción de los scripts; cada uno se verificó ejecutándolo en ambos motores.", "cap"),
     ]

SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=1.5 * cm, rightMargin=1.5 * cm, topMargin=1.1 * cm,
                  bottomMargin=1.4 * cm, title="TP Unidad 7 - Food Store NoSQL - Mateo Algañaraz",
                  author="Mateo Algañaraz").build(S, onFirstPage=footer, onLaterPages=footer)
shutil.copyfile(OUT, ROOT / "DB_Mateo_Algañaraz.pdf")
print(OUT)
