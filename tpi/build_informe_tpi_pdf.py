from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "DB_Mateo_Algañaraz.pdf"
styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="BodyTPI", parent=styles["BodyText"], fontSize=8.7, leading=11.2, spaceAfter=6))
styles.add(ParagraphStyle(name="H1TPI", parent=styles["Heading1"], fontSize=15, leading=18, spaceBefore=9, spaceAfter=7))
styles.add(ParagraphStyle(name="H2TPI", parent=styles["Heading2"], fontSize=11, leading=13, spaceBefore=7, spaceAfter=5))


def p(text, style="BodyTPI"):
    return Paragraph(text, styles[style])


def table(rows, widths, font_size=7.2):
    value = Table(rows, colWidths=widths, repeatRows=1, hAlign="LEFT")
    value.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#17365D")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), font_size),
        ("LEADING", (0, 0), (-1, -1), font_size + 1.5),
        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#D9D9D9")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 3.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#EDF3F8")]),
    ]))
    return value


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(colors.HexColor("#666666"))
    canvas.drawRightString(A4[0] - 1.5 * cm, 1.0 * cm, f"TPI Food Store - pagina {doc.page}")
    canvas.restoreState()


story = [
    Spacer(1, 1.2 * cm),
    p("Trabajo Practico Integrador - Primera entrega parcial", "Title"),
    p("Food Store - Base de Datos II", "H1TPI"),
    p("Estudiante: Mateo Algañaraz<br/>Repositorio: DB_Mateo_Algañaraz<br/>Motor validado: PostgreSQL 18.4"),
    Spacer(1, 0.25 * cm),
    p("<b>Resumen.</b> Esta entrega integra integridad, transacciones y concurrencia; optimizacion de consultas; e indices, vistas y objetos programables. Todas las afirmaciones de ejecucion referencian salidas versionadas del motor."),
    p("1. Cobertura de la consigna", "H1TPI"),
]

coverage = [
    [p("Punto"), p("Implementacion verificable")],
    [p("1. Modelo ER"), p("Diagrama, claves, cardinalidad y participacion: tpi/docs/01_modelo_er.md.")],
    [p("2. ER a relacional"), p("FKs 1:N y entidad asociativa detalle_pedido para la N:M.")],
    [p("3. Normalizacion"), p("Dependencias funcionales y justificacion 3FN/BCNF.")],
    [p("4. DDL"), p("schema.sql y migracion idempotente tpi/01_migracion_modelo_final.sql.")],
    [p("5. DML y consultas"), p("JOIN, agregacion, subconsultas, GROUP BY/HAVING y RANK en TP3/TP4.")],
    [p("6. Vistas y PL/pgSQL"), p("Vistas, materializada, 2 funciones y 2 procedimientos.")],
    [p("7. Reglas"), p("CHECK, UNIQUE, trigger de vigencia y trigger de auditoria.")],
    [p("8. Transacciones"), p("Atomicidad, COMMIT/ROLLBACK, aislamiento y bloqueo en dos sesiones.")],
    [p("9. Borrado logico"), p("deleted_at, indices parciales y vistas de entidades vigentes.")],
]
story += [table(coverage, [3.1 * cm, 13.0 * cm]), p("La trazabilidad completa de archivos se encuentra en tpi/docs/04_checklist_tpi.md.")]

story += [p("2. Modelo y reglas de negocio", "H1TPI"),
          p("El modelo contiene cliente, categoria, producto, pedido y detalle_pedido. La PK compuesta de detalle_pedido preserva cantidad y precio historico. Las FK usan ON DELETE RESTRICT; cliente y producto incorporan deleted_at para preservar el historial sin devolver bajas en las nuevas vistas."),
          p("El esquema final agrega nombres no vacios, precios positivos, categoria unica, email unico entre clientes vigentes e indices parciales para las consultas filtradas por deleted_at. El rol sin login food_store_reporter solo recibe SELECT sobre las vistas de reporte."),
          p("3. Objetos programables y prueba atomica", "H1TPI"),
          p("sp_tpi_registrar_pedido bloquea el producto, valida cliente y stock, descuenta unidades y crea pedido mas detalle. Ante stock insuficiente lanza excepcion sin dejar un pedido parcial. sp_tpi_baja_logica_cliente marca la baja. Los triggers impiden productos no vigentes en detalles y auditan cambios de producto."),
          p("La prueba reversible finalizo con ROLLBACK y confirmo 2 procedimientos, 2 triggers y 2 vistas. Tambien comprobó los tres CHECK, la auditoria y el reuso de email posterior a una baja logica.")]

story += [p("4. Transacciones y concurrencia observadas", "H1TPI")]
concurrency = [
    [p("Caso"), p("Resultado real en PostgreSQL 18.4")],
    [p("Lectura no repetible"), p("READ COMMITTED: 10.00 -> 20.00. REPEATABLE READ: 10.00 -> 10.00.")],
    [p("Lectura fantasma"), p("READ COMMITTED: 2 -> 3 filas activas. REPEATABLE READ: 2 -> 2.")],
    [p("Bloqueo de fila"), p("B inicio 20:30:49.634868-03; adquirio 20:30:52.401280-03, al liberar A.")],
]
story += [table(concurrency, [4.0 * cm, 12.1 * cm]),
          p("La ejecucion completa se conserva en tpi/evidencia/20260923_214500/06_concurrencia.txt. El ejecutor abre dos sesiones psql y limpia las filas de laboratorio al finalizar.")]

story += [p("5. Optimizacion, vistas y resultados", "H1TPI")]
metrics = [
    [p("Trabajo"), p("Resultado documentado")],
    [p("TP3 y TP4"), p("Planes antes/despues, equivalencias y decisiones de indices se preservan en sus carpetas de evidencia.")],
    [p("TP5 - indices"), p("Detalles por producto: 27.891 ms -> 0.152 ms; autocompletado: 8.988 ms -> 1.446 ms; apellido: 3.518 ms -> 0.176 ms.")],
    [p("TP5 - escritura"), p("INSERT reversible de 600 detalles: 8.299 ms sin los indices TP5 y 15.327 ms con ellos; costo reconocido y justificado.")],
    [p("TP5 - materializada"), p("Reporte de facturacion: 550.464 ms -> 0.067 ms; refresco concurrente documentado.")],
]
story += [table(metrics, [4.0 * cm, 12.1 * cm]),
          p("En la verificacion TPI se versionaron ademas los planes crudos, las ocho equivalencias EXCEPT = 0, la medicion de escritura y el refresh en tp5/evidencia/20260923_tpi/. Los tiempos pueden variar por cache; los planes y controles conservan la evidencia de la decision."),
          p("6. Uso responsable de IA", "H1TPI"),
          p("Codex/OpenAI se utilizo para estructurar scripts, documentacion y controles reproducibles. OpenCode reviso las propuestas de indices de TP5. Cada propuesta se acepto o descarto luego de verificarla contra el esquema y salidas reales de PostgreSQL; los registros estan versionados en los DUIA."),
          p("Reproduccion: seguir tpi/README.md sobre una copia aislada. Los scripts y las salidas de evidencia permiten inspeccionar cada requisito sin depender de valores inventados.")]

SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=1.5 * cm, rightMargin=1.5 * cm, topMargin=1.3 * cm, bottomMargin=1.5 * cm).build(story, onFirstPage=footer, onLaterPages=footer)
print(OUT)
