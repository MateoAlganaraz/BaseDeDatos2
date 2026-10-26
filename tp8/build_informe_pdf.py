"""Genera tp8/informe_u6.pdf (y la copia DB_Mateo_Algañaraz.pdf para la plataforma).

Página 1: informe post-incidente (una página, como pide la consigna).
Páginas siguientes: anexo de evidencias, leído de los archivos de evidencia/.
Uso: python tp8/build_informe_pdf.py
"""
import shutil
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (KeepTogether, PageBreak, Paragraph, Preformatted, SimpleDocTemplate, Spacer,
                                Table, TableStyle)

ROOT = Path(__file__).resolve().parent
EVID = ROOT / "evidencia"
OUT = ROOT / "informe_u6.pdf"
COPIA = ROOT / "DB_Mateo_Algañaraz.pdf"


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
    "title": ParagraphStyle("t", parent=ss["Title"], fontName=BOLD, fontSize=13.5, leading=16, textColor=BLUE, spaceAfter=2),
    "sub": ParagraphStyle("s", parent=ss["BodyText"], fontName=BODY, fontSize=8, leading=10, alignment=1, spaceAfter=4),
    "h": ParagraphStyle("h", parent=ss["Heading2"], fontName=BOLD, fontSize=9.2, leading=11, textColor=BLUE,
                        spaceBefore=4, spaceAfter=2),
    "body": ParagraphStyle("b", parent=ss["BodyText"], fontName=BODY, fontSize=7.6, leading=9.6, spaceAfter=2.5),
    "cell": ParagraphStyle("c", parent=ss["BodyText"], fontName=BODY, fontSize=7.2, leading=8.8),
    "cellb": ParagraphStyle("cb", parent=ss["BodyText"], fontName=BOLD, fontSize=7.2, leading=8.8, textColor=colors.white),
    "code": ParagraphStyle("code", fontName=MONO, fontSize=5.6, leading=6.9),
    "cap": ParagraphStyle("cap", parent=ss["BodyText"], fontName=BODY, fontSize=7.2, leading=9,
                          textColor=colors.HexColor("#555555"), spaceAfter=6),
    "h1": ParagraphStyle("h1", parent=ss["Heading1"], fontName=BOLD, fontSize=12, leading=15, textColor=BLUE, spaceAfter=4),
}


def p(t, s="body"):
    return Paragraph(t, st[s])


def table(rows, widths):
    data = [[Paragraph(str(c), st["cellb"]) for c in rows[0]]] + [[Paragraph(str(c), st["cell"]) for c in r] for r in rows[1:]]
    t = Table(data, colWidths=widths, hAlign="LEFT")
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), BLUE), ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#C8C8C8")),
                           ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                           ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#EEF3F8")]),
                           ("TOPPADDING", (0, 0), (-1, -1), 1.8), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.8)]))
    return t


def capture(name, caption, filtro=None, width=160):
    lines = (EVID / name).read_text(encoding="utf-8").splitlines()
    if filtro:
        lines = [l for l in lines if filtro(l)]
    pre = Preformatted("\n".join(l.rstrip() for l in lines), st["code"], maxLineLength=width, newLineChars="")
    box = Table([[pre]], colWidths=[17.8 * cm])
    box.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F6F6F6")),
                             ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#A0A0A0"))]))
    return KeepTogether([box, p(caption, "cap")])


def solo_diagnosticos(lines_filter_state={"dentro": False}):
    def f(l):
        if l.startswith("== 2. Diag") or l.startswith("== 4. Diag"):
            lines_filter_state["dentro"] = True
        elif l.startswith("== "):
            lines_filter_state["dentro"] = False
        return lines_filter_state["dentro"]
    return f


def filas_bloque(nombre, inicio):
    filas, dentro = [], False
    for l in (EVID / nombre).read_text(encoding="utf-8").splitlines():
        if l.startswith(inicio):
            dentro = True
            continue
        if dentro and l.startswith("("):
            break
        if dentro and "|" in l and not l.lstrip().startswith("relname"):
            filas.append([c.strip() for c in l.split("|")])
    return filas


def tabla_mantenimiento():
    antes = {f[0]: f for f in filas_bloque("05_maintenance.txt", "== 2. Diag")}
    despues = {f[0]: f for f in filas_bloque("05_maintenance.txt", "== 4. Diag")}
    rows = [["Tabla", "n_dead_tup antes", "¿Requiere VACUUM?", "¿Requiere ANALYZE?", "Último ANALYZE antes",
             "n_dead_tup después", "¿Requiere algo después?", "Último ANALYZE después"]]
    for t in ["producto", "detalle_pedido", "pedido", "cliente", "categoria"]:
        a, d = antes[t], despues[t]
        rows.append([t, a[2], "sí" if a[5] == "t" else "no", "sí" if a[8] == "t" else "no", a[10] or "(nunca)",
                     d[2], "no" if d[4] == "f" and d[6] == "f" else "sí", d[8][:19]])
    return KeepTogether([table(rows, [2.4 * cm, 1.9 * cm, 2 * cm, 2 * cm, 2.3 * cm, 1.9 * cm, 2.1 * cm, 3.4 * cm]),
                         Spacer(1, 0.1 * cm),
                         p("A6. maintenance.sql: diagnóstico antes y después, transcripto de 05_maintenance.txt (salida "
                           "completa con los mensajes de VACUUM VERBOSE en ese archivo). Las cinco tablas figuraban sin "
                           "ANALYZE por la pérdida de estadísticas; producto además superaba el umbral de VACUUM.", "cap")])


def footer(c, d):
    c.saveState()
    c.setFont(BODY, 7)
    c.setFillColor(colors.HexColor("#666666"))
    c.drawString(1.5 * cm, 0.9 * cm, "Tecnicatura Universitaria en Programación - UTN - Base de Datos II")
    c.drawRightString(A4[0] - 1.5 * cm, 0.9 * cm, f"TP Unidad 6 - página {d.page}")
    c.restoreState()


W = 18 * cm
S = [p("Informe post-incidente - TP Unidad 6: mantenimiento, respaldo y recuperación", "title"),
     p("Food Store - Base de Datos II - Mateo Algañaraz - PostgreSQL 16.15 - simulacro del 26/10/2026 - "
       "repositorio MateoAlganaraz/BaseDeDatos2, carpeta <b>tp8/</b>", "sub"),

     p("1. Respaldo utilizado y resultado del simulacro", "h"),
     table([["Dato", "Valor observado", "Evidencia"],
            ["Respaldo", "foodstore_20261026_111838.dump, formato custom, 18.780.506 bytes (18 MB), creado el "
                         "<b>26/10/2026 11:18:39 -03</b> por <i>foodstore_backup</i> (solo lectura); pg_dump: 2,44 s",
             "02_backup_ok.txt"],
            ["Restauración + validación", "Destino <b>foodstore_restore_test</b> (foodstore intacta). Cronómetro desde createdb "
                                          "hasta la última validación: <b>4,04 s</b> (restauración 3,78 s)",
             "07_simulacro_restauracion.txt"],
            ["Conteos (5 tablas)", "Iguales al conteo previo al respaldo: categoria 12, cliente 20.000, producto 10.000, "
                                   "pedido 600.000, detalle_pedido 1.500.000", "07, 10"],
            ["Restricciones lógicas", "productos_invalidos = 0, detalles_invalidos = 0; 18 restricciones en origen = 18 en "
                                      "la restaurada", "07, 10"]],
           [3.2 * cm, 11.6 * cm, 3.2 * cm]),

     p("2. RPO y RTO: previstos vs. observados", "h"),
     table([["", "Previsto (SPEC_U6)", "Observado", "Lectura"],
            ["<b>RPO</b> (datos que se pueden perder)", "24 h (respaldo lógico diario)",
             "39 s (antigüedad del respaldo al iniciar el simulacro)",
             "Se perdería lo escrito después de las 11:18:39. El valor es bajo porque el simulacro se hizo enseguida; con el "
             "respaldo diario de las 03:00 el peor caso real es casi 24 h de pedidos."],
            ["<b>RTO</b> (tiempo hasta volver a operar)", "5 min (laboratorio)", "4,04 s (primera corrida, caché fría); "
                                                                                  "mediana 2,36 s en 3 repeticiones",
             "Cumple con amplio margen. Mide solo restauración y validación; un incidente real suma detección, decisión y "
             "redirigir la aplicación."]],
           [3.3 * cm, 3.2 * cm, 4.3 * cm, 7.2 * cm]),

     p("3. Problema real encontrado", "h"),
     p("<b>Las estadísticas de actividad se perdieron por un apagado no limpio.</b> El servidor del laboratorio se detuvo "
       "abruptamente dos veces y arrancó con recuperación automática (\"database system was not properly shut down\"). En "
       "PostgreSQL 15+ esa recuperación descarta las estadísticas acumuladas. Por eso <i>health_check.sql</i> mostró "
       "n_live_tup = 0 y last_analyze/last_autovacuum vacíos en todas las tablas, y el 100 % de tuplas muertas en producto "
       "era un artefacto. Autovacuum decide con esas cifras, así que quedaba \"ciego\". <i>maintenance.sql</i> lo detectó "
       "(\"nunca analizadas\") y ejecutó VACUUM (ANALYZE) solo sobre esas tablas; la revisión posterior las mostró "
       "resueltas. También se corrigieron, antes de programar el respaldo: permisos 644 en los .dump (ahora umask 077), un "
       ".counts.csv vacío que quedaba si pg_dump fallaba, la falta de -w (en una tarea programada psql podía quedar "
       "esperando una contraseña) y la consulta de validación de la consigna, que usa la columna <i>precio</i> cuando en "
       "este esquema se llama <i>precio_lista</i>."),

     p("4. Mejora concreta para la próxima ejecución", "h"),
     p("<b>Restaurar con pg_restore -j 2</b> (procesos paralelos para datos e índices): con el mismo respaldo y 3 corridas "
       "por variante, la mediana del RTO bajó de <b>2,36 s a 1,93 s (−18 %)</b> en 2 CPU, y ya es el modo documentado "
       "(JOBS=2). Para el <b>riesgo</b> de perder hasta 24 h de pedidos, la mejora es sumar archivado de WAL "
       "(archive_mode + pg_basebackup) para recuperar a un punto en el tiempo, y programar restore_test semanal con alerta "
       "si devuelve un código distinto de 0."),

     p("5. Trabajo asistido con IA y cómo se verificó", "h"),
     p("En el entorno de resolución OpenCode no estaba disponible. El asistente fue Claude (Anthropic), que generó la "
       "primera versión de los scripts a partir de <i>SPEC_U6.md</i> y <i>tp8/AGENTS.md</i>. Nada se aceptó sin "
       "ejecutarlo. Cada script de respaldo se corrió en su camino exitoso y en dos caminos de error (base inexistente y "
       "servidor inaccesible), comprobando el código de salida y que no quedaran archivos parciales. Las versiones .ps1 "
       "se probaron con PowerShell 7.4. La restauración se validó contra los conteos tomados antes del respaldo. Las "
       "correcciones de la sección 3 salieron de esa revisión. Ningún script ni log contiene contraseñas."),
     ]

# ---------------- Anexo ----------------
S += [PageBreak(), p("Anexo - Evidencias (salidas reales en tp8/evidencia/)", "h1"),
      capture("02_backup_ok.txt", "A1. Respaldo con backup_foodstore.sh: log, archivos generados (permisos 600) y cabecera del "
                                  "dump.", lambda l: not l.startswith(";") or "Archive created" in l or "dbname" in l),
      capture("01_backup_caminos_de_error.txt", "A2. Caminos de error: código de salida 2 y sin archivos parciales."),
      capture("07_simulacro_restauracion.txt", "A3. Simulacro cronometrado: conteos, restricciones, RTO y RPO."),
      capture("08_comparacion_jobs.txt", "A4. Mejora medida: pg_restore -j 1 vs. -j 2 (3 corridas cada uno)."),
      capture("05b_reinicio_no_limpio.txt", "A5. Problema real: dos recuperaciones automáticas tras apagados no limpios (log "
                                            "del servidor).", width=170),
      tabla_mantenimiento(),
      capture("06_backup_ps1.txt", "A7. backup_foodstore.ps1 probado con PowerShell: camino exitoso y de error."),
      capture("09_restore_ps1.txt", "A8. restore_test.ps1 probado con PowerShell (-Jobs 2)."),
      capture("10_foodstore_intacta_y_validacion.txt", "A9. foodstore intacta tras los simulacros y validación mínima de la "
                                                       "consigna sobre foodstore_restore_test.")]

doc = SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=1.5 * cm, rightMargin=1.5 * cm, topMargin=1.1 * cm,
                        bottomMargin=1.4 * cm, title="Informe TP Unidad 6 - Food Store - Mateo Algañaraz",
                        author="Mateo Algañaraz")
doc.build(S, onFirstPage=footer, onLaterPages=footer)
shutil.copyfile(OUT, COPIA)
print(OUT)
print(COPIA)
