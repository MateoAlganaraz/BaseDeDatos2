from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "DB_Mateo_Algañaraz.pdf"

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="BodySmall", parent=styles["BodyText"], fontSize=8.5, leading=11, spaceAfter=7))
styles.add(ParagraphStyle(name="H1x", parent=styles["Heading1"], fontSize=15, leading=19, spaceBefore=10, spaceAfter=8))
styles.add(ParagraphStyle(name="H2x", parent=styles["Heading2"], fontSize=11.5, leading=14, spaceBefore=8, spaceAfter=6))


def p(text, style="BodySmall"):
    return Paragraph(text, styles[style])


def table(data, widths):
    result = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    result.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#17365D")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 7.1),
        ("LEADING", (0, 0), (-1, -1), 8.5),
        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#D9D9D9")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#EDF3F8")]),
    ]))
    return result


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(colors.HexColor("#666666"))
    canvas.drawRightString(letter[0] - 1.6 * cm, 1.1 * cm, f"TP5 Food Store - página {doc.page}")
    canvas.restoreState()


story = [
    Spacer(1, 1.8 * cm),
    p("Trabajo Práctico Unidad 3 Semana 1", "Title"),
    p("Índices, vistas y vistas materializadas en Food Store", "H1x"),
    p("Base de Datos II"),
    p("Estudiante: Mateo Algañaraz"),
    p("Repositorio: DB_Mateo_Algañaraz"),
    Spacer(1, 0.45 * cm),
    p("<b>Conclusión.</b> Se trabajó sobre copias aisladas de la base masiva de TP3. Se aceptaron solo los índices cuyo plan cambió y cuyo tiempo real mejoró; también se documentó su costo en escritura."),
    p("1. Entorno y método", "H1x"),
    p("PostgreSQL 18.4. La carga heredada contiene 400.000 detalles, 200.000 pedidos, 50.000 productos y 20.000 clientes. Se comparó <b>food_store_tp5_base</b> contra <b>food_store_tp5_indices_vistas</b> con EXPLAIN ANALYZE y BUFFERS."),
    p("2. Parte A - Plan de indexado", "H1x"),
]

indices = [
    [p("Consulta"), p("Antes"), p("Índice aceptado"), p("Después"), p("Mejora")],
    [p("Q1 Detalles por producto"), p("Parallel Seq Scan; 27,891 ms"), p("(id_producto, id_pedido) INCLUDE cantidad, precio"), p("Bitmap Index Scan; 0,152 ms"), p("183,49x")],
    [p("Q2 Autocompletado"), p("Seq Scan; 8,988 ms"), p("nombre text_pattern_ops WHERE activo"), p("Index Only Scan; 1,446 ms"), p("6,22x")],
    [p("Q3 Clientes por apellido"), p("Seq Scan; 3,518 ms"), p("apellido text_pattern_ops"), p("Index Only Scan; 0,176 ms"), p("19,99x")],
]
story += [table(indices, [2.55 * cm, 2.8 * cm, 4.3 * cm, 2.7 * cm, 1.4 * cm])]
story += [p("Q2 escapa los guiones bajos del código de producto: en LIKE, `_` es comodín. Al tratarlos como literales, PostgreSQL pudo usar el índice parcial de prefijo."),
          p("Costo de escritura", "H2x")]

write_cost = [
    [p("Prueba reversible"), p("Tiempo INSERT de 600 detalles"), p("Lectura")],
    [p("Sin índices TP5"), p("8,299 ms"), p("Base de comparación")],
    [p("Con índices TP5"), p("15,327 ms"), p("1,85x más lento por mantenimiento de índices")],
]
story += [table(write_cost, [3.3 * cm, 4.0 * cm, 6.4 * cm])]
story += [p("La inserción se ejecutó dentro de BEGIN y terminó en ROLLBACK. Se descartó un índice aislado sobre producto.activo: 47.500 de 50.000 productos están activos, por lo que su baja cardinalidad no justifica el mantenimiento adicional."),
          p("3. Parte B - Vistas", "H1x")]

views = [
    [p("Vista"), p("Uso"), p("Equivalencia")],
    [p("vw_tp5_productos_vigentes_categoria"), p("Catálogo de productos y categorías activas"), p("EXCEPT: 0 / 0")],
    [p("vw_tp5_pedidos_cliente"), p("Pedidos con identificación pública del cliente"), p("EXCEPT: 0 / 0")],
    [p("vw_tp5_detalle_pedido_producto"), p("Detalle, producto y subtotal"), p("EXCEPT: 0 / 0")],
    [p("vw_tp5_clientes_reportes"), p("Mínimo privilegio: no expone teléfono"), p("EXCEPT: 0 / 0")],
]
story += [table(views, [5.3 * cm, 6.3 * cm, 2.1 * cm])]
story += [p("El esquema real no contiene contraseña. La vista de clientes aplica mínimo privilegio al exponer solo los datos necesarios para el reporte, sin teléfono."),
          p("4. Parte C - Vista materializada", "H1x")]

materializada = [
    [p("Reporte"), p("Plan / acceso"), p("Tiempo")],
    [p("Consulta original de facturación por categoría y mes"), p("Joins, Parallel Seq Scan, Gather Merge y GroupAggregate"), p("550,464 ms")],
    [p("mv_tp5_facturacion_categoria_mes"), p("Resumen precalculado de 65 filas"), p("0,067 ms")],
]
story += [table(materializada, [4.5 * cm, 6.6 * cm, 2.6 * cm])]
story += [p("La consulta del resumen materializado fue 8.215,88x más rápida. La vista se creó con WITH DATA y el índice único (mes, id_categoria), que habilita REFRESH MATERIALIZED VIEW CONCURRENTLY."),
          p("Refresco y consistencia", "H2x"),
          p("Para un reporte de gestión diaria se recomienda un refresh nocturno. La prueba de REFRESH CONCURRENTLY tomó 539,135 ms. Durante el refresco los usuarios mantienen acceso a la versión anterior; por esa razón los datos pueden tener la antigüedad del último refresh."),
          p("5. Declaración de Uso de IA", "H1x")]

ai = [
    [p("Herramienta"), p("Uso real"), p("Decisión")],
    [p("Codex / OpenAI"), p("Especificaciones, scripts, revisión de sintaxis y planes"), p("Aceptar solo con plan y tiempo real verificable")],
    [p("OpenCode"), p("Revisión de las tres specs de índices"), p("Propuso los tres índices luego validados en PostgreSQL")],
]
story += [table(ai, [3.1 * cm, 5.5 * cm, 5.1 * cm])]
story += [p("Los detalles del flujo, prompts y decisiones están en duia.md y registro_codex.md. Los scripts, variantes DBeaver, mediciones y commits separados permiten reproducir y defender cada decisión."),
          p("6. Reproducibilidad", "H1x"),
          p("1. Ejecutar las consultas y la escritura reversible en food_store_tp5_base. 2. Crear los índices en food_store_tp5_indices_vistas. 3. Repetir las mediciones. 4. Crear vistas, ejecutar las equivalencias y materializar el reporte. La guía exacta está en tp5/README.md.")]

SimpleDocTemplate(str(OUT), pagesize=letter, leftMargin=1.6 * cm, rightMargin=1.6 * cm, topMargin=1.5 * cm, bottomMargin=1.6 * cm).build(story, onFirstPage=footer, onLaterPages=footer)
print(OUT)
