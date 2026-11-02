"""Genera tp10/docs/informe.pdf (y la copia DB_Mateo_Algañaraz.pdf) desde la evidencia.

Uso: python tp10/build_informe_pdf.py   (después de tp10/run_tp10.sh)
Las cifras de los casos se leen de evidencia/; si falta un resultado esperado, el script falla.
"""
import re
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
OUT = ROOT / "docs" / "informe.pdf"


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
    "cell": ParagraphStyle("c", parent=ss["BodyText"], fontName=BODY, fontSize=7.2, leading=8.8),
    "cellb": ParagraphStyle("cb", parent=ss["BodyText"], fontName=BOLD, fontSize=7.2, leading=8.8),
    "mono": ParagraphStyle("m", fontName=MONO, fontSize=6.3, leading=7.6, textColor=colors.HexColor("#222222")),
    "cap": ParagraphStyle("cap", parent=ss["BodyText"], fontName=BODY, fontSize=6.8, leading=8.4,
                          textColor=colors.HexColor("#555555"), spaceAfter=4),
}


def P(t, s="body"):
    return Paragraph(t, st[s])


def tabla(filas, anchos):
    datos = [[P(c, "cellb" if i == 0 else "cell") for c in f] for i, f in enumerate(filas)]
    t = Table(datos, colWidths=[a * cm for a in anchos], repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#DCE6F0")),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#9AA9B8")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 3), ("RIGHTPADDING", (0, 0), (-1, -1), 3),
        ("TOPPADDING", (0, 0), (-1, -1), 2), ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
    ]))
    return t


def codigo(texto, pie):
    caja = Table([[Preformatted(texto, st["mono"])]], colWidths=[17.6 * cm])
    caja.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F4F6F8")),
                              ("BOX", (0, 0), (-1, -1), 0.4, colors.HexColor("#C5CED6")),
                              ("LEFTPADDING", (0, 0), (-1, -1), 4), ("TOPPADDING", (0, 0), (-1, -1), 3),
                              ("BOTTOMPADDING", (0, 0), (-1, -1), 3)]))
    return KeepTogether([caja, P(pie, "cap")])


def leer(nombre):
    return (EVID / nombre).read_text(encoding="utf-8")


def exigir(texto, patron, que):
    m = re.search(patron, texto, re.M)
    if not m:
        raise SystemExit(f"Falta en la evidencia: {que} ({patron})")
    return m


# ---------------------------------------------------------------------
# Datos tomados de la evidencia
# ---------------------------------------------------------------------
snap = leer("01_servidor_snapshot.txt")
pru = leer("03_pruebas_sqlite.txt")
cas = leer("04_casos_c2_c6.txt")
fin = leer("05_control_final.txt")
rev = leer("06_code_review.txt")

fecha_copia = exigir(leer("02_tablet_esquema_y_carga.txt"), r"instantánea cargada\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)",
                     "carga inicial")
filas_snap, disponibles, fecha = fecha_copia.group(1), fecha_copia.group(3), fecha_copia.group(5)
version_pg = exigir(snap, r"PostgreSQL (\d+\.\d+)", "versión de PostgreSQL").group(1)

estado = {}
for uuid, est in re.findall(r"^(c[2-6]000000-\S+)\s+(CONFLICTO|RECHAZADO|SIMULADO_APROBADO)", cas, re.M):
    estado[uuid] = est
esperado = {
    "c2000000-0000-4000-9000-000000000001": "CONFLICTO",
    "c2000000-0000-4000-9000-000000000002": "SIMULADO_APROBADO",
    "c3000000-0000-4000-9000-000000000001": "RECHAZADO",
    "c4000000-0000-4000-9000-000000000001": "RECHAZADO",
    "c5000000-0000-4000-9000-000000000001": "SIMULADO_APROBADO",
}
for u, e in esperado.items():
    if estado.get(u) != e:
        raise SystemExit(f"El caso {u} dio {estado.get(u)} y se esperaba {e}")
motivo_c2 = exigir(cas, r"(producto 101: precio visto \d+, actual \d+ \(centavos\))", "motivo C2").group(1)
motivo_c3 = exigir(cas, r"(producto 106: pide \d+, stock \d+)", "motivo C3").group(1)
exigir(cas, r"UNIQUE constraint failed: cola_sync.solicitud_uuid", "error de C6")
exigir(cas.split("C6 - Reenvío")[1], r"solicitudes evaluadas en esta corrida\|0", "segunda corrida de C6")
for control in ("pedidos", "detalles", "stock total"):
    exigir(fin, rf"^\s*{control}\s*\|\s*(\d+)\s*\|\s*\1\s*\|\s*t", f"control final de {control}")
exigir(fin, r"productos con stock distinto de la línea base \|\s+0", "stock producto por producto")
pedidos = exigir(fin, r"^\s*pedidos\s*\|\s*(\d+)", "pedidos").group(1)


def bloque(texto, desde, hasta=None):
    a = texto.index(desde)
    b = texto.index(hasta, a + len(desde)) if hasta else len(texto)
    return texto[a:b].strip()


def miles(n):
    return f"{int(n):,}".replace(",", ".")


# ---------------------------------------------------------------------
# Documento
# ---------------------------------------------------------------------
h = []
h.append(P("TP N.º 8 - Food Store en la feria: la base de la tablet y el cierre de la capa de datos", "title"))
h.append(P(f"Base de Datos II - Integrante: Mateo Algañaraz - Repositorio MateoAlganaraz/BaseDeDatos2, carpeta tp10/ "
           f"(rama tp-u8) - PostgreSQL {version_pg} y SQLite 3.50.4 - Todo con datos de laboratorio inventados", "sub"))

h.append(P("1.a Qué datos viajan a la tablet", "h"))
h.append(tabla([
    ["Viaja (columna de v_snapshot_movil)", "Origen en PostgreSQL", "No viaja", "Por qué"],
    ["id", "producto.id_producto", "descripcion, id_categoria", "La tablet solo muestra y vende; no los necesita."],
    ["nombre", "producto.nombre", "cliente (nombre, email, teléfono)", "Datos personales: regla 2 de la consigna. La tablet no los necesita para vender."],
    ["precio_centavos", "precio_lista × 100 (entero)", "pedido y detalle_pedido", "Las ventas las registra el servidor; la tablet nunca confirma ventas."],
    ["stock (stock_visto en la tablet)", "producto.stock", "usuarios, contraseñas, auditoría", "Credenciales y datos de seguridad no salen del servidor."],
    ["disponible / eliminado", "activo y deleted_at (lápida)", "", ""],
], [4.2, 4.0, 4.4, 5.0]))
h.append(P("<b>La fuente de verdad es PostgreSQL.</b> La tablet guarda una copia fechada (<i>copiado_en</i>) para vender sin señal. "
           "El stock que ve no es una reserva y el precio puede cambiar: por eso cada borrador pasa por el semáforo antes de "
           "convertirse en una venta, y esa conversión ocurre en el servidor, no en la tablet. Las bajas lógicas viajan como "
           "lápidas para que la tablet las deje de ofrecer sin borrar filas que los borradores referencian."))
h.append(P(f"Instantánea inicial (2.a): {miles(filas_snap)} productos exportados con <font name='{MONO}'>\\copy</font> "
           f"e importados con <font name='{MONO}'>.import --csv --skip 1</font>; {miles(disponibles)} disponibles. "
           f"Fecha de la copia: <b>{fecha}</b>. La base de la tablet (1.b) tiene cuatro tablas STRICT con "
           f"<font name='{MONO}'>PRAGMA foreign_keys = ON</font>; las pruebas 1.c (COMMIT, ROLLBACK, C1 sin servidor y C7) "
           "están en <i>evidencia/03_pruebas_sqlite.txt</i>."))

h.append(P("2.c Los casos del semáforo", "h"))
h.append(P("Orden de cada caso: borrador en la tablet → cambio preparado en la <b>copia de pruebas</b> del servidor "
           "(foodstore_tp10_lab) → nueva instantánea → <font name='%s'>cargar_snapshot.sql</font> → "
           "<font name='%s'>semaforo.sql</font>. El orquestador <i>run_tp10.sh</i> registra cada comando." % (MONO, MONO)))
h.append(tabla([
    ["Caso", "Comando (preparación)", "Resultado", "Explicación"],
    ["C2", "casos/c2_borrador.sql; servidor/c2_subir_precio.sql (+5 % al producto 101); semáforo; "
           "casos/c2_aceptar.sql; semáforo",
     f"CONFLICTO: {motivo_c2}. Luego, solicitud nueva: SIMULADO_APROBADO",
     "No hay rojo, pero el precio visto difiere del actual. El cliente acepta el precio nuevo: la tablet actualiza el "
     "precio visto y envía una solicitud nueva. La que quedó en CONFLICTO se conserva como registro."],
    ["C3", "casos/c3_borrador.sql (stock visto + 6 unidades del 106)", f"RECHAZADO: {motivo_c3}",
     "El stock que vio la tablet no es una reserva. El semáforo compara la cantidad con el stock del servidor."],
    ["C4", "casos/c4_borrador.sql; servidor/c4_baja_logica.sql (deleted_at del 109); semáforo; casos/c4_catalogo.sql",
     "RECHAZADO: producto 109: dado de baja. En la tablet, 0 en el catálogo disponible y la fila con eliminado = 1",
     "La baja viaja como lápida. Al recargar, el producto desaparece del catálogo, pero su fila queda porque el borrador "
     "viejo la referencia. Un borrador nuevo ya no puede incluirlo (trigger)."],
    ["C5", "casos/c5_borrador.sql (110 × 3 y 111 × 1)", "SIMULADO_APROBADO",
     "Existencia, disponibilidad, stock y precio coinciden. Es una simulación: no crea ningún pedido en PostgreSQL."],
    ["C6", "casos/c6_reenviar.sql (mismo UUID de C5); semáforo",
     "UNIQUE constraint failed: cola_sync.solicitud_uuid; la segunda corrida evalúa 0 solicitudes",
     "solicitud_uuid es la clave primaria (SQLite informa la violación de una PK de texto como UNIQUE). Como solo se "
     "evalúa PENDIENTE, repetir la simulación no reevalúa nada."],
], [1.0, 5.0, 5.0, 6.6]))
h.append(P("<b>Dónde iría la protección real (parada 8):</b> en el servidor. El endpoint que reciba la solicitud debe guardar "
           "<i>solicitud_uuid</i> en una tabla con restricción UNIQUE <b>dentro de la misma transacción</b> que crea el pedido y "
           "descuenta el stock. Así, un reenvío después de un corte devuelve el resultado ya registrado en lugar de vender dos "
           "veces. La PK de la tablet solo evita duplicados locales."))
h.append(codigo(bloque(fin, "   control", "(5 rows)") + "\n(5 rows)",
                f"Control final en PostgreSQL (servidor/99_control_final.sql): {miles(pedidos)} pedidos y el mismo stock que la "
                "línea base, producto por producto. Solo cambiaron el precio del 101 (C2) y la baja del 109 (C4), preparados "
                "a mano como servidor. SIMULADO_APROBADO no creó ventas."))

h.append(P("3.a Mapa de la capa de datos", "h"))
h.append(tabla([
    ["Motor", "Qué guarda", "Quién manda sobre cada dato"],
    ["PostgreSQL 16 (foodstore)", "Catálogo, precios, stock, clientes, pedidos y detalles, usuarios y auditoría "
     "(TPI y Unidades 1 a 6).", "<b>Manda sobre todo.</b> Precio, stock y ventas se deciden acá. Es el único sistema de registro."],
    ["MongoDB 8.0 (foodstore_nosql.pedidos, Unidad 7)", "Copia documental de 12 pedidos con cliente y líneas embebidas, "
     "precios históricos en Decimal128.", "<b>No manda.</b> Es una proyección de lectura que se regenera desde PostgreSQL "
     "(tp9/scripts/exportar_migracion.py). Si difiere, gana PostgreSQL."],
    ["SQLite (foodstore_movil.db, tablet)", "producto_cache (copia fechada), snapshot_servidor, borradores, ítems y cola_sync.",
     "<b>Manda solo sobre sus borradores y su cola.</b> El caché obedece a la última instantánea. SIMULADO_APROBADO es una "
     "propuesta, no una venta."],
], [4.2, 6.4, 7.0]))
h.append(P("Flujo: PostgreSQL → (export) → MongoDB, solo lectura. PostgreSQL → (v_snapshot_movil, CSV) → SQLite. "
           "SQLite → (cola_sync, propuesta) → PostgreSQL decide. Ninguna flecha escribe precio, stock ni ventas desde un "
           "motor secundario."))

h.append(P("3.b Plan de mantenimiento (agregado al de la Unidad 6)", "h"))
h.append(tabla([
    ["Pregunta", "Respuesta"],
    ["¿Qué se respalda y cómo se prueba la restauración?",
     "PostgreSQL: pg_dump -Fc diario con restauración cronometrada en foodstore_restore_test (tp8/backup_foodstore.sh y "
     "restore_test.sh; RPO 24 h). MongoDB: no se respalda, porque se regenera desde PostgreSQL. Tablet: al cierre de cada "
     "feria, <font name='%s'>sqlite3 foodstore_movil.db \".backup respaldo_tablet.db\"</font>, antes de sincronizar. Se "
     "prueba abriendo la copia con <font name='%s'>PRAGMA integrity_check</font> (ok), <font name='%s'>foreign_key_check</font> "
     "(sin filas) y comparando la cola por estado: 1 CONFLICTO, 2 RECHAZADO y 3 SIMULADO_APROBADO en ambas "
     "(evidencia/07_respaldo_tablet.txt)." % (MONO, MONO, MONO)],
    ["Si se restaura un respaldo viejo de PostgreSQL, ¿qué hacen las tablets?",
     "No le envían nada al servidor como verdad. Descartan su instantánea, porque puede ser más nueva que el servidor "
     "restaurado, y bajan una nueva. Las solicitudes evaluadas contra una copia con copiado_en posterior a la fecha del "
     "respaldo se reenvían como solicitudes nuevas (UUID nuevo), para que el semáforo las juzgue contra el servidor "
     "restaurado. Los borradores no se pierden: viven en la tablet."],
    ["¿Cada cuánto y quién revisa CONFLICTO o RECHAZADO?",
     "Al cierre de cada jornada de feria, y antes de la sincronización real, el responsable del food truck "
     "(rol responsable). CONFLICTO: se contacta al cliente; si acepta, solicitud nueva con el precio actual, como en C2. "
     "RECHAZADO: el borrador se anula o se rearma sin el producto. La consulta de revisión está en "
     "evidencia/07_respaldo_tablet.txt."],
], [4.4, 13.2]))

h.append(P("3.c Code review de los scripts de la cursada con IA", "h"))
h.append(P("La consigna pide OpenCode en el agente Plan. No estaba disponible, así que la revisión se hizo con Claude "
           "(Claude Code) sobre los scripts de las Unidades 1 a 8 (ver docs/bitacora_ia.md). Cada hallazgo se comprobó "
           "en la base; la salida está en evidencia/06_code_review.txt."))
h.append(tabla([
    ["#", "Unidad / script", "Hallazgo", "Comprobación en la base", "Decisión y motivo"],
    ["H1", "U7 - tp9/consultas_postgresql.sql §1", "La consulta de claves une constraint_column_usage y multiplica filas: "
     "la PK compuesta sale como «id_pedido, id_pedido, id_producto, id_producto».",
     "Versión de main contra versión corregida, sobre foodstore: 4 columnas antes y «id_pedido, id_producto» después.",
     "<b>Corregido</b> en la rama tp-u7: la tabla referenciada se busca en una subconsulta. Las cifras del informe de la "
     "Unidad 7 no cambian."],
    ["H2", "U1 - sql/01_restricciones_integridad.sql", "Falla sobre una base creada con schema.sql: intenta crear "
     "restricciones que ya existen.", "Dentro de BEGIN … ROLLBACK, sobre la copia: «constraint "
     "ck_producto_precio_positivo … already exists».",
     "<b>Aceptado</b> y documentado, sin modificar el entregable del TP2: el script es para el esquema anterior al TPI, y "
     "schema.sql ya incorporó esas reglas."],
    ["H3", "U8 - servidor/01_v_snapshot_movil.sql", "Propuesta: usar round(precio_lista × 100) en lugar del cast, por "
     "si se pierden centavos.", "precio_lista es NUMERIC(12,2): 0 de 10.000 productos tienen fracción de centavo y el "
     "cast coincide con round() en todos.", "<b>Descartado:</b> con escala 2, × 100 es un entero exacto. round() no "
     "agrega nada."],
    ["H4", "U8 - movil/cargar_snapshot.sql", "Propuesta: recargar producto_cache con DELETE + INSERT, más simple que el "
     "UPSERT.", "En una copia de la tablet: «FOREIGN KEY constraint failed». Hay 7 productos referenciados por "
     "borradores y 1 lápida.", "<b>Descartado:</b> rompería la FK de los borradores y perdería las lápidas que C4 necesita."],
], [0.7, 3.2, 4.4, 4.6, 4.7]))

h.append(P("Archivos: movil/schema_sqlite.sql, pruebas_sqlite.sql, cargar_snapshot.sql, semaforo.sql, casos/, "
           "servidor_snapshot.csv y foodstore_movil.db; servidor/; run_tp10.sh; docs/kiro/, bitacora_ia.md y DUIA.md; "
           "evidencia/ (salidas completas).", "cap"))


def pie(c, d):
    c.saveState()
    c.setFont(BODY, 7)
    c.setFillColor(colors.HexColor("#666666"))
    c.drawString(1.6 * cm, 1.0 * cm, "Tecnicatura Universitaria en Programación - UTN - Base de Datos II")
    c.drawRightString(A4[0] - 1.6 * cm, 1.0 * cm, f"TP N.º 8 - página {d.page}")
    c.restoreState()


OUT.parent.mkdir(parents=True, exist_ok=True)
doc = SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=1.6 * cm, rightMargin=1.6 * cm,
                        topMargin=1.3 * cm, bottomMargin=1.6 * cm, title="TP N.º 8 - Food Store en la feria",
                        author="Mateo Algañaraz")
doc.build(h, onFirstPage=pie, onLaterPages=pie)
shutil.copyfile(OUT, ROOT / "DB_Mateo_Algañaraz.pdf")
print(f"Generado {OUT.relative_to(ROOT.parent)} y DB_Mateo_Algañaraz.pdf")
