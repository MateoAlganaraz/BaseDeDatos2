from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Preformatted

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'DB_Mateo_Algañaraz.pdf'
EVIDENCIA = ROOT / 'evidencia' / '20260915_producto'

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name='BodySmall', parent=styles['BodyText'], fontSize=8.5, leading=11, spaceAfter=7))
styles.add(ParagraphStyle(name='H1x', parent=styles['Heading1'], fontSize=15, leading=19, textColor=colors.black, spaceBefore=10, spaceAfter=8))
styles.add(ParagraphStyle(name='H2x', parent=styles['Heading2'], fontSize=11.5, leading=14, textColor=colors.black, spaceBefore=8, spaceAfter=6))
styles.add(ParagraphStyle(name='Tiny', fontName='Courier', fontSize=6.2, leading=7.2))

def P(text, style='BodySmall'):
    return Paragraph(text, styles[style])

def table(data, widths):
    t = Table(data, colWidths=widths, repeatRows=1, hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#17365D')),
        ('TEXTCOLOR',(0,0),(-1,0),colors.white),
        ('FONTNAME',(0,0),(-1,0),'Helvetica-Bold'),
        ('FONTSIZE',(0,0),(-1,-1),7.2),
        ('LEADING',(0,0),(-1,-1),8.5),
        ('GRID',(0,0),(-1,-1),0.35,colors.HexColor('#D9D9D9')),
        ('VALIGN',(0,0),(-1,-1),'MIDDLE'),
        ('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),5),
        ('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4),
        ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white, colors.HexColor('#EDF3F8')]),
    ]))
    return t

def wrap_lines(text, n=125):
    out=[]
    for line in text.splitlines():
        out.extend(line[i:i+n] for i in range(0, max(1,len(line)), n))
    return '\n'.join(out)

def footer(canvas, doc):
    canvas.saveState(); canvas.setFont('Helvetica',7); canvas.setFillColor(colors.HexColor('#666666'))
    canvas.drawRightString(letter[0]-1.6*cm, 1.1*cm, f'TP4 Food Store - página {doc.page}')
    canvas.restoreState()

story=[]
story += [Spacer(1,1.8*cm), P('Trabajo Práctico 4', 'Title'), P('Reportes analíticos asistidos por IA sobre Food Store', 'H1x')]
story += [P('Base de Datos II - Unidad 2 - Semana 4'), P('Estudiante: Mateo Algañaraz'), P('Repositorio: DB_Mateo_Algañaraz'), Spacer(1,0.5*cm)]
story += [P('<b>Conclusión.</b> El trabajo se ejecutó sobre copias aisladas de la base masiva. Se aceptó únicamente el índice que PostgreSQL usó en el plan real; las hipótesis no usadas se documentan como descartadas.')]
story += [P('1. Preparación y protocolo', 'H1x'), P('Se creó la copia <b>food_store_tp4_evidencia</b> a partir de la base masiva de TP3. La carga disponible contiene 20.000 clientes, 50.000 productos, 200.000 pedidos y 400.000 detalles. Se trabajó con respaldo previo y sin modificar practica_bd2.')]
story += [P('2. Parte 1 - Consultas analíticas y medición', 'H1x')]
data=[[P('Consulta'),P('Plan antes'),P('Cambio'),P('Plan después'),P('Mejora / decisión')],
      [P('Q1 Facturación por categoría y mes'),P('Parallel Hash Join, Hash Join y Seq Scan de detalle; 392,846 ms.'),P('Índices de fecha y cobertura de pedido.'),P('Tres Hash Join; Seq Scan conservado; 424,434 ms.'),P('0,93x. Rechazado: empeoró y no usó los índices nuevos.')],
      [P('Q2 Ranking de clientes por gasto'),P('Tres Hash Join, agregación y ventana; 402,742 ms.'),P('Misma hipótesis de cobertura.'),P('Tres Hash Join conservados; 334,318 ms.'),P('1,20x observado, no aceptado como causal: sin cambio de nodo.')],
      [P('Q3 Ventas mensuales del producto 100001'),P('Parallel Seq Scan de detalle; 65,141 ms.'),P('Índice idx_tp4_detalle_producto_pedido.'),P('Index Only Scan; 0,460 ms.'),P('141,61x. Aceptado.')]]
story += [table(data,[3.0*cm,3.2*cm,3.2*cm,3.0*cm,3.2*cm]), Spacer(1,0.3*cm)]
story += [P('Q3 combina producto, categoría, detalle_pedido y pedido. El índice aceptado es <b>CREATE INDEX idx_tp4_detalle_producto_pedido ON detalle_pedido (id_producto, id_pedido) INCLUDE (cantidad, precio_unitario)</b>. El filtro por id_producto dejó de recorrer 400.000 detalles y accedió solo a las ocho líneas correspondientes.')]
story += [P('3. Parte 2 - Lectura crítica del plan de joins', 'H1x')]
data=[[P('Afirmación de IA'),P('¿Correcta?'),P('Evidencia del plan real')],
      [P('El índice localiza las líneas del producto sin recorrer toda detalle_pedido.'),P('Sí'),P('Plan posterior: Index Only Scan con Index Cond id_producto = 100001.')],
      [P('El costo estimado 121,28 representa milisegundos.'),P('No'),P('cost es estimado; el tiempo real está en Execution Time: 0,460 ms.')],
      [P('El Nested Loop externo entrega líneas de detalle y el interno resuelve producto/categoría/pedido.'),P('Sí'),P('El plan posterior muestra Nested Loop y ocho búsquedas por id_pedido.')]]
story += [table(data,[6.0*cm,2.0*cm,8.6*cm])]
story += [PageBreak(), P('4. Parte 3 - Specs y equivalencia', 'H1x')]
story += [P('<b>Spec 1 - Ranking.</b> Un cliente por fila, con nombre, apellido, total gastado en pedidos del período y RANK descendente; empates comparten puesto. Se comparó agregación previa más ventana contra subconsulta correlacionada.')]
story += [P('<b>Spec 2 - Productos sin ventas.</b> Productos y categorías activas sin detalle asociado a un pedido dentro de la ventana; se comparó NOT EXISTS contra LEFT JOIN con HAVING.')]
data=[[P('Control EXCEPT'),P('Resultado real')],
      [P('spec_1_ia_menos_propia'),P('0')],[P('spec_1_propia_menos_ia'),P('0')],
      [P('spec_2_ia_menos_propia'),P('0')],[P('spec_2_propia_menos_ia'),P('0')]]
story += [table(data,[8.5*cm,4.0*cm])]
story += [P('5. Parte 4 - Competencia', 'H1x')]
data=[[P('Equipo'),P('Estrategia aplicada'),P('Antes'),P('Después'),P('Mejora')],
      [P('Mateo Algañaraz'),P('Índice inverso por producto sobre detalle_pedido, con columnas de cobertura.'),P('65,141 ms'),P('0,460 ms'),P('141,61x')]]
story += [table(data,[3*cm,7*cm,2.2*cm,2.2*cm,2*cm])]
story += [P('La competencia usa la misma consulta analítica Q3, con cuatro tablas, agregación mensual y los mismos datos antes/después.')]
story += [P('6. Declaración de Uso de IA', 'H1x')]
data=[[P('Uso'),P('Prompt o spec resumido'),P('Decisión')],
      [P('Consultas e índices'),P('Proponer reportes con joins y un índice solo si el plan lo justificaba.'),P('Q1 y Q2 descartados; Q3 aceptado por Index Only Scan y tiempo real.')],
      [P('Lectura crítica'),P('Explicar plan nodo por nodo sin confundir costos con tiempos.'),P('Contraste realizado con Q3.')],
      [P('Equivalencia'),P('Crear versión alternativa para ranking y subconsulta correlacionada.'),P('Cuatro EXCEPT devolvieron 0.')]]
story += [table(data,[3.0*cm,6.4*cm,6.0*cm])]
story += [PageBreak(), P('Anexo A - Plan Q3 antes', 'H1x')]
story += [Preformatted(wrap_lines(EVIDENCIA.joinpath('q_producto_antes.txt').read_text(encoding='utf-8')), styles['Tiny'])]
story += [PageBreak(), Spacer(1, 0.6*cm), P('Anexo B - Plan Q3 después', 'H1x')]
story += [Preformatted(wrap_lines(EVIDENCIA.joinpath('q_producto_despues.txt').read_text(encoding='utf-8')), styles['Tiny'])]

SimpleDocTemplate(str(OUT), pagesize=letter, leftMargin=1.6*cm, rightMargin=1.6*cm, topMargin=1.5*cm, bottomMargin=1.6*cm).build(story, onFirstPage=footer, onLaterPages=footer)
print(OUT)
