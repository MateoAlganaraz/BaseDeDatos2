"""Genera el informe breve del TP6 (Unidad 4) a partir de la evidencia real.

Los bloques de plan se leen de evidencia/02_desnormalizacion_top_categorias.txt y
evidencia/03_mediciones_repetidas.txt, para que el PDF muestre la salida tal cual la
devolvió PostgreSQL. Uso: python tp6/build_informe_pdf.py
"""
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (KeepTogether, PageBreak, Paragraph, Preformatted, SimpleDocTemplate,
                                Spacer, Table, TableStyle)

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "DB_Mateo_Algañaraz.pdf"
EVID = ROOT / "evidencia"

FONT_DIRS = [Path("/usr/share/fonts/truetype/dejavu"), Path("C:/Windows/Fonts")]


def register_fonts():
    names = {"Sans": "DejaVuSans.ttf", "Sans-Bold": "DejaVuSans-Bold.ttf",
             "Sans-Oblique": "DejaVuSans-Oblique.ttf", "Mono": "DejaVuSansMono.ttf"}
    for d in FONT_DIRS:
        if all((d / f).exists() for f in names.values()):
            for n, f in names.items():
                pdfmetrics.registerFont(TTFont(n, str(d / f)))
            pdfmetrics.registerFontFamily("Sans", normal="Sans", bold="Sans-Bold", italic="Sans-Oblique",
                                          boldItalic="Sans-Bold")
            return "Sans", "Sans-Bold", "Mono"
    return "Helvetica", "Helvetica-Bold", "Courier"


BODY, BOLD, MONO = register_fonts()
BLUE = colors.HexColor("#2E5C8A")

ss = getSampleStyleSheet()
st = {
    "title": ParagraphStyle("t", parent=ss["Title"], fontName=BOLD, fontSize=17, leading=21, textColor=BLUE),
    "sub": ParagraphStyle("s", parent=ss["BodyText"], fontName=BODY, fontSize=10, leading=13, alignment=1),
    "h1": ParagraphStyle("h1", parent=ss["Heading1"], fontName=BOLD, fontSize=13.5, leading=17, textColor=BLUE,
                         spaceBefore=10, spaceAfter=6),
    "h2": ParagraphStyle("h2", parent=ss["Heading2"], fontName=BOLD, fontSize=11, leading=14, textColor=BLUE,
                         spaceBefore=7, spaceAfter=4),
    "body": ParagraphStyle("b", parent=ss["BodyText"], fontName=BODY, fontSize=8.8, leading=12, spaceAfter=5),
    "cell": ParagraphStyle("c", parent=ss["BodyText"], fontName=BODY, fontSize=7.8, leading=9.8),
    "cellb": ParagraphStyle("cb", parent=ss["BodyText"], fontName=BOLD, fontSize=7.8, leading=9.8,
                            textColor=colors.white),
    "code": ParagraphStyle("code", fontName=MONO, fontSize=5.6, leading=6.9, textColor=colors.HexColor("#1E1E1E")),
    "caption": ParagraphStyle("cap", parent=ss["BodyText"], fontName=BODY, fontSize=7.6, leading=9.5,
                              textColor=colors.HexColor("#555555"), spaceAfter=6),
}


def p(text, style="body"):
    return Paragraph(text, st[style])


def table(rows, widths):
    data = [[Paragraph(str(c), st["cellb"]) for c in rows[0]]]
    data += [[Paragraph(str(c), st["cell"]) for c in r] for r in rows[1:]]
    t = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), BLUE),
        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#C8C8C8")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#EEF3F8")]),
        ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    return t


def capture(lines, caption):
    """Bloque monoespaciado tal como lo imprimió psql, con marco (captura de salida)."""
    text = "\n".join(line.rstrip() for line in lines)
    pre = Preformatted(text, st["code"], maxLineLength=150, newLineChars="")
    box = Table([[pre]], colWidths=[17.6 * cm])
    box.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F6F6F6")),
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#A0A0A0")),
        ("LEFTPADDING", (0, 0), (-1, -1), 5), ("TOPPADDING", (0, 0), (-1, -1), 4),
    ]))
    return KeepTogether([box, p(caption, "caption")])


def section(path, start_marker, end_predicate):
    lines = path.read_text(encoding="utf-8").splitlines()
    i = next(n for n, l in enumerate(lines) if start_marker in l)
    out = []
    for l in lines[i:]:
        out.append(l)
        if end_predicate(l) and len(out) > 1:
            break
    return out


def strip_cost(lines):
    # Quita "(cost=...)" para que el plan entre en el ancho de página; se conservan los tiempos reales.
    import re
    out = []
    for l in lines:
        l = re.sub(r"\(cost=[^)]*\) ", "", l)
        if set(l.strip()) == {"-"}:
            l = "-" * 60
        elif l.strip() == "QUERY PLAN":
            l = " QUERY PLAN"
        out.append(l)
    return out


ev2 = EVID / "02_desnormalizacion_top_categorias.txt"
ev1 = EVID / "01_fnbc_control_lote.txt"
ev3 = EVID / "03_mediciones_repetidas.txt"

antes = strip_cost(section(ev2, "EXPLAIN ANALYZE de la consulta original", lambda l: l.startswith("(") and "rows)" in l))
despues = strip_cost(section(ev2, "leyendo el resumen (DESPUÉS)", lambda l: l.startswith("(") and "rows)" in l))
equiv = section(ev2, "== Equivalencia", lambda l: l.startswith("(") and "rows)" in l)
auditoria = section(ev2, "5.2(e) Auditoría completa", lambda l: l.startswith("(") and "rows)" in l)
pruebas = [l for l in section(ev2, "== 5.1 Alta", lambda l: "Auditoría final" in l)
           if "|" in l and "caso" not in l]
fnbc_equiv = section(ev1, "== 5. Equivalencia", lambda l: l.startswith("(") and "rows)" in l)
anomalias = section(ev1, "== 3.a", lambda l: "CREATE TABLE" in l)
medicion = section(ev3, "== Original (4 tablas)", lambda l: "Alternativa" in l)
escritura = section(ev3, "Costo de escritura", lambda l: l.startswith("(") and "rows)" in l)


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont(BODY, 7)
    canvas.setFillColor(colors.HexColor("#666666"))
    canvas.drawString(1.6 * cm, 1.0 * cm, "Tecnicatura Universitaria en Programación - UTN - Base de Datos II")
    canvas.drawRightString(A4[0] - 1.6 * cm, 1.0 * cm, f"TP Unidad 4 - página {doc.page}")
    canvas.restoreState()


S = []
S += [Spacer(1, 0.6 * cm),
      p("Trabajo Práctico - Unidad 4", "title"),
      p("Forma Normal de Boyce-Codd y desnormalización controlada en Food Store", "title"),
      p("Base de Datos II - Estudiante: Mateo Algañaraz - Repositorio: MateoAlganaraz/BaseDeDatos2, carpeta <b>tp6/</b>", "sub"),
      Spacer(1, 0.3 * cm),
      p("Entorno: PostgreSQL 16.15, base de laboratorio <b>food_store_tp6_lab</b> creada desde <b>schema.sql</b>. "
        "Scripts: <b>tp_fnbc_control_lote.sql</b> (Parte 1) y <b>tp_desnormalizacion_top_categorias.sql</b> (Parte 2). "
        "Todas las cifras provienen de las salidas guardadas en <b>tp6/evidencia/</b>; los recuadros grises son capturas "
        "textuales de psql.")]

# ------------------------------------------------------------------ Parte 1
S += [p("Parte 1 - FNBC sobre control_lote_almacen", "h1"),
      p("Esquema R(LoteID, DepositoID, ResponsableControlID), PK (lote_id, deposito_id). Las tablas maestras lote, "
        "deposito y usuario no existen en el esquema del repositorio; se crean mínimas en un esquema aislado "
        "<b>mayorista</b> para que las FOREIGN KEY de la consigna sean válidas."),
      p("a) Dependencias funcionales", "h2"),
      p("<b>DF1:</b> {LoteID, DepositoID} → {ResponsableControlID}. &nbsp; <b>DF2:</b> {ResponsableControlID} → {DepositoID}. "
        "LoteID solo no determina nada (un lote se controla desde varios depósitos) y DepositoID tampoco."),
      p("b) Clausuras y claves candidatas", "h2")]
S += [table([
    ["Conjunto X", "X⁺", "¿Superclave?"],
    ["{LoteID}", "{LoteID}", "No"],
    ["{DepositoID}", "{DepositoID}", "No"],
    ["{ResponsableControlID}", "{ResponsableControlID, DepositoID}", "No"],
    ["{LoteID, DepositoID}", "{LoteID, DepositoID, ResponsableControlID} (DF1)", "Sí, mínima → clave candidata"],
    ["{LoteID, ResponsableControlID}", "{LoteID, ResponsableControlID, DepositoID} (DF2)", "Sí, mínima → clave candidata"],
    ["{DepositoID, ResponsableControlID}", "{DepositoID, ResponsableControlID}", "No (falta LoteID)"],
], [4.6 * cm, 7.6 * cm, 5.4 * cm])]
S += [p("LoteID no aparece en ningún lado derecho, así que integra toda clave. <b>Claves candidatas:</b> {LoteID, DepositoID} "
        "y {LoteID, ResponsableControlID}. <b>Primos:</b> los tres atributos. <b>No primos:</b> ninguno."),
      p("c) Verificación de FNBC", "h2"),
      p("R está en FNBC si toda DF no trivial X → Y tiene X superclave. DF1 cumple. <b>DF2 viola FNBC</b>: es no trivial y "
        "{ResponsableControlID}⁺ = {ResponsableControlID, DepositoID} ≠ R, porque no determina LoteID; en la instancia, "
        "801 aparece en dos filas (lotes 501 y 502). La tabla sí está en 3FN (DepositoID es primo), por eso se usa la "
        "definición de FNBC."),
      p("d) Anomalías (ejecutadas dentro de BEGIN ... ROLLBACK)", "h2"),
      p("<b>Actualización:</b> \"801 pertenece al depósito 30\" está repetido en las filas de 501 y 502. Si 801 se traslada al "
        "depósito 32 y solo se corrige la fila de 501, la tabla lo acepta y registra a 801 en {30, 32}. "
        "<b>Inserción:</b> la responsable 803, recién incorporada al depósito 31, no puede registrarse sin un lote (lote_id es "
        "NOT NULL y parte de la PK); además se acepta (504, 31, 801), dejando a 801 en {30, 31}. "
        "<b>Borrado:</b> al eliminar la fila del lote 503 se pierde el único registro de que 802 pertenece al depósito 31."),
      capture(anomalias[:-1], "Captura 1 - Salida de las tres anomalías (evidencia/01_fnbc_control_lote.txt, sección 3)."),
      p("e) Descomposición sin pérdida", "h2"),
      p("Con la DF violatoria X → Y, X = {ResponsableControlID}: <b>R1 = X⁺ = responsable_deposito(responsable_control_id PK, "
        "deposito_id)</b> y <b>R2 = R − (X⁺ − X) = control_lote_responsable(lote_id, responsable_control_id; PK compuesta)</b>. "
        "FK: R1 → usuario y deposito; R2 → lote y R1. En R1 la única DF es DF2 con determinante clave; en R2 no queda DF no "
        "trivial: ambas en FNBC. Vista de compatibilidad: <b>vw_control_lote_almacen</b> = control_lote_responsable NATURAL "
        "JOIN responsable_deposito. DF1 no se preserva (sus atributos quedan separados); se la protege con disparadores que "
        "rechazan un segundo responsable del mismo depósito para un lote."),
      p("f) Unión sin pérdida, migración y verificación", "h2"),
      p("R1 ∩ R2 = {ResponsableControlID} y por DF2 {ResponsableControlID} → R1: el atributo común es superclave (clave) de R1. "
        "Por el criterio de superclave sobre el atributo común, cada fila de R2 se combina con exactamente una de R1 y "
        "R1 ⋈ R2 = R sin tuplas espurias. La migración verifica DF2 sobre los datos, carga R1 y R2 con SELECT DISTINCT en una "
        "transacción y compara la tabla original con la vista en ambos sentidos."),
      capture(fnbc_equiv, "Captura 2 - Equivalencia tabla original vs. vista de compatibilidad: 0 diferencias y 3 filas en ambas."),
      p("Pruebas posteriores (revertidas): 803 se registra sin lote; el traslado de 801 se hace en una fila y la vista lo refleja "
        "en sus dos lotes; borrar el lote 503 conserva (802, 31); la PK rechaza un segundo depósito para 801 y el disparador "
        "rechaza un segundo responsable del depósito 30 para el lote 501.")]

# ------------------------------------------------------------------ Parte 2
S += [PageBreak(),
      p("Parte 2 - Top 5 de categorías por monto vendido en el día", "h1"),
      p("Adaptación al esquema real: id → id_producto / id_categoria / id_pedido; subtotal → cantidad × precio_unitario; "
        "eliminado = FALSE → deleted_at IS NULL (convención del TPI; se agregó deleted_at a pedido y detalle_pedido); "
        "fecha = CURRENT_DATE → rango del día sobre fecha TIMESTAMPTZ (zona America/Argentina/Buenos_Aires). "
        "Instancia: 12 categorías, 10.000 productos, 20.000 clientes, 600.000 pedidos (12.000 con baja lógica), "
        "1.500.000 detalles (6.186 con baja lógica), 1.643 pedidos del día."),
      p("a) Consulta original: Execution Time 33,129 ms; nodo dominante Parallel Seq Scan on pedido", "h2"),
      p("El Parallel Seq Scan sobre pedido insume 20,062 ms de los 25,439 ms del subárbol de joins de cada proceso (≈ 79 %): "
        "lee los 600.000 pedidos para conservar 1.643 (Rows Removed by Filter: 199452 en cada uno de 3 procesos). Luego "
        "hace 1.643 búsquedas en pk_detalle_pedido y 4.091 en producto_pkey, Hash Join con categoría y agrega. Mediana de 30 "
        "ejecuciones: 28,695 ms."),
      capture(antes, "Captura 3 - EXPLAIN (ANALYZE, BUFFERS) ANTES. Se omitieron los valores (cost=...) para que entre en la "
              "página; la salida completa está en evidencia/02_desnormalizacion_top_categorias.txt."),
      p("b) Patrón elegido: columna/tabla precalculada con disparadores", "h2"),
      p("Se eligió una tabla resumen <b>resumen_venta_diaria_categoria</b> (una fila por día y categoría) mantenida por "
        "disparadores. La evidencia de (a) muestra que casi todo el costo es localizar los pedidos del día recorriendo 600.000 "
        "filas y luego resolver tres joins y una agregación sobre miles de detalles, trabajo que se repite completo en cada una "
        "de las muchas ejecuciones por minuto aunque entre ellas cambien pocos pedidos; un índice sobre pedido(fecha), medido "
        "como alternativa, solo baja la mediana a 8,556 ms porque sigue uniendo y agregando 4.091 detalles. La vista "
        "materializada se descartó porque el panel exige tiempo real y cada REFRESH recalcula 1.500.000 detalles. La "
        "sincronización la garantizan disparadores AFTER ... FOR EACH STATEMENT sobre detalle_pedido (alta, modificación, "
        "borrado y TRUNCATE), pedido (fecha y baja lógica) y producto (categoría), que aplican un delta agregado con INSERT ... "
        "ON CONFLICT DO UPDATE en la misma transacción que el cambio, más el script de auditoría de (e). Es reversible sin "
        "pérdida: las tablas fuente no se modifican, el resumen se reconstruye con fn_tp6_reconstruir_resumen() y eliminarlo "
        "(DROP TABLE ... CASCADE y funciones fn_tp6_*) no borra ningún dato."),
      p("c) Implementación", "h2"),
      p("Tabla (dia, id_categoria, total_vendido, lineas, actualizado_en), PK (dia, id_categoria) y FK a categoria; "
        "fn_tp6_dia_negocio() fija el día en Buenos Aires; carga inicial de 4.380 filas bajo LOCK TABLE; seis disparadores "
        "por sentencia con tablas de transición, que agrupan los deltas por (día, categoría) y los aplican ordenados. "
        "Script completo en tp_desnormalizacion_top_categorias.sql, sección 2.")]

S += [p("d) Consulta sobre la estructura desnormalizada", "h2"),
      Preformatted("SELECT c.nombre AS categoria, r.total_vendido\nFROM resumen_venta_diaria_categoria r\n"
                   "JOIN categoria c ON c.id_categoria = r.id_categoria\nWHERE r.dia = CURRENT_DATE AND r.lineas > 0\n"
                   "ORDER BY r.total_vendido DESC\nLIMIT 5;", ParagraphStyle("sql", parent=st["code"], fontSize=7.5,
                                                                          leading=9.2)),
      Spacer(1, 0.2 * cm),
      capture(despues, "Captura 4 - EXPLAIN (ANALYZE, BUFFERS) DESPUÉS: 0,037 ms, 10 buffers.")]
S += [table([
    ["Medida", "Antes (4 tablas)", "Después (resumen)"],
    ["Execution Time (EXPLAIN ANALYZE)", "33,129 ms", "0,037 ms"],
    ["Mediana de 30 ejecuciones", "28,695 ms", "0,017 ms"],
    ["Nodo dominante", "Parallel Seq Scan on pedido (600.000 filas leídas, 1.643 útiles)",
     "Bitmap Heap Scan on resumen_venta_diaria_categoria vía Bitmap Index Scan on su PK (12 filas)"],
    ["Buffers", "22.645 hit + 810 read", "10 hit"],
], [4.6 * cm, 6.5 * cm, 6.5 * cm]),
      Spacer(1, 0.2 * cm),
      p("Ambas consultas devuelven el mismo top 5 (Almacén, Bebidas, Golosinas, Mascotas, Snacks, con los mismos montos), y "
        "los controles EXCEPT en ambos sentidos, sin LIMIT, para el día y para los últimos 7 días dan 0:"),
      capture(equiv, "Captura 5 - Equivalencia de resultados entre la consulta original y la desnormalizada."),
      p("Costo aceptado: insertar 1.000 detalles pasa de 8,485 ms a 10,889 ms de mediana (+2,4 ms, ≈ 28 %), y las ventas "
        "del mismo día y categoría se serializan sobre la misma fila del resumen hasta el COMMIT. Se justifica porque cada "
        "lectura del panel, que ocurre muchas veces por minuto, ahorra ≈ 28 ms."),
      capture([l for l in medicion[:-1] + escritura[1:] if l != "CREATE FUNCTION"], "Captura 6 - Mediciones repetidas y costo de escritura (evidencia/03_mediciones_repetidas.txt).")]

S += [p("e) Auditoría de sincronización", "h2"),
      p("Recalcula desde detalle_pedido, pedido y producto el total y las líneas por día y categoría y los compara con FULL JOIN "
        "contra el resumen. Sobre la base migrada devuelve 0 filas. Las pruebas de sincronización (revertidas) auditan después "
        "de cada operación; el control negativo corrompe el resumen a mano y la auditoría lo detecta."),
      capture(auditoria, "Captura 7 - Auditoría sobre la base migrada: resultado vacío."),
      table([["Prueba de sincronización (dentro de BEGIN ... ROLLBACK)", "Diferencias de auditoría"]]
            + [[c.split("|")[0].strip(), c.split("|")[1].strip()] for c in pruebas], [11 * cm, 6.6 * cm]),
      p("Diferencias detectadas después de cada prueba, transcriptas de evidencia/02_desnormalizacion_top_categorias.txt "
        "(0 en todas; 1 en el control negativo, que corrompe el resumen a mano).", "caption")]

S += [p("Declaración de uso de IA", "h2"),
      p("Se usó Claude (Anthropic) como asistente para redactar los scripts, el generador de datos y el informe. Todo se "
        "verificó ejecutándolo en PostgreSQL 16.15 y las cifras provienen de las salidas en tp6/evidencia/.")]

SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=1.6 * cm, rightMargin=1.6 * cm, topMargin=1.4 * cm,
                  bottomMargin=1.6 * cm, title="TP Unidad 4 - FNBC y desnormalización - Mateo Algañaraz",
                  author="Mateo Algañaraz").build(S, onFirstPage=footer, onLaterPages=footer)
print(OUT)
