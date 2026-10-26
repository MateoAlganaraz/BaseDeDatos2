"""Genera tp7/DB_Mateo_Algañaraz.pdf: resumen del TP Unidad 5 para la plataforma.

El PDF resume; el detalle y la evidencia están en el repositorio (README, docs/, evidencia/,
BITACORA.md). Los fragmentos de log y de verificación se leen de los archivos de evidencia.
Uso: python tp7/scripts/build_informe_pdf.py
"""
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import KeepTogether, Paragraph, Preformatted, SimpleDocTemplate, Spacer, Table, TableStyle

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "DB_Mateo_Algañaraz.pdf"
DOCS, EVID = ROOT / "docs", ROOT / "evidencia"


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
    "title": ParagraphStyle("t", parent=ss["Title"], fontName=BOLD, fontSize=16, leading=20, textColor=BLUE),
    "sub": ParagraphStyle("s", parent=ss["BodyText"], fontName=BODY, fontSize=9.5, leading=12.5, alignment=1),
    "h1": ParagraphStyle("h1", parent=ss["Heading1"], fontName=BOLD, fontSize=12.5, leading=16, textColor=BLUE,
                         spaceBefore=9, spaceAfter=5),
    "body": ParagraphStyle("b", parent=ss["BodyText"], fontName=BODY, fontSize=8.6, leading=11.6, spaceAfter=5),
    "cell": ParagraphStyle("c", parent=ss["BodyText"], fontName=BODY, fontSize=7.6, leading=9.6),
    "cellb": ParagraphStyle("cb", parent=ss["BodyText"], fontName=BOLD, fontSize=7.6, leading=9.6, textColor=colors.white),
    "code": ParagraphStyle("code", fontName=MONO, fontSize=5.5, leading=6.8),
    "cap": ParagraphStyle("cap", parent=ss["BodyText"], fontName=BODY, fontSize=7.4, leading=9.2,
                          textColor=colors.HexColor("#555555"), spaceAfter=6),
}


def p(t, s="body"):
    return Paragraph(t, st[s])


def table(rows, widths):
    data = [[Paragraph(str(c), st["cellb"]) for c in rows[0]]] + [[Paragraph(str(c), st["cell"]) for c in r] for r in rows[1:]]
    t = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), BLUE), ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#C8C8C8")),
                           ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                           ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#EEF3F8")]),
                           ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3)]))
    return t


def capture(lines, caption, width=150):
    pre = Preformatted("\n".join(l.rstrip() for l in lines), st["code"], maxLineLength=width, newLineChars="")
    box = Table([[pre]], colWidths=[17.8 * cm])
    box.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F6F6F6")),
                             ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#A0A0A0"))]))
    return KeepTogether([box, p(caption, "cap")])


def section(path, start, stop):
    lines = path.read_text(encoding="utf-8").splitlines()
    i = next(n for n, l in enumerate(lines) if start in l)
    out = []
    for l in lines[i:]:
        out.append(l)
        if stop(l) and len(out) > 1:
            break
    return out


def acortar_log(lines):
    # Quita la fecha (se conserva la hora) y el nombre de la base para que entre en la página.
    return [re.sub(r"^2026-10-26 ", "", l).replace("@food_store_tp7_lab", "") for l in lines]


fin_tabla = lambda l: l.startswith("(") and "row" in l
esperado = section(DOCS / "verificacion_permisos.txt", "== 3. Esperado", fin_tabla)
pruebas = [l for l in (DOCS / "verificacion_permisos.txt").read_text().splitlines() if re.match(r"^ +\d+ \|", l)]
log_b = acortar_log([l for l in (DOCS / "log_auditoria_prueba.txt").read_text().splitlines()
                     if ("statement:" in l or "FATAL" in l or "ERROR" in l or "authorized" in l) and not l.startswith("\t")])
log_c = acortar_log([l for l in (DOCS / "log_simulacro_anonimizado.txt").read_text().splitlines()
                     if "statement:" in l or "ERROR" in l or "fn_autenticar:" in l])
verif_c = section(EVID / "C_verificacion_escalamiento.txt", "C.2.1", lambda l: "C.2.4" in l)[:-1]
equiv = section(EVID / "D_verificacion_equivalencia.txt", "D.3.3", fin_tabla)
totales = section(EVID / "D_verificacion_equivalencia.txt", "D.3.4", fin_tabla)


def footer(c, d):
    c.saveState()
    c.setFont(BODY, 7)
    c.setFillColor(colors.HexColor("#666666"))
    c.drawString(1.6 * cm, 1.0 * cm, "Tecnicatura Universitaria en Programación - UTN - Base de Datos II")
    c.drawRightString(A4[0] - 1.6 * cm, 1.0 * cm, f"TP Unidad 5 - página {d.page}")
    c.restoreState()


S = [Spacer(1, 0.4 * cm),
     p("Trabajo Práctico - Unidad 5", "title"),
     p("Administración y seguridad de Food Store: roles, auditoría, incidentes y protección de datos personales", "title"),
     p("Base de Datos II - Estudiante: Mateo Algañaraz - Repositorio MateoAlganaraz/BaseDeDatos2, carpeta <b>tp7/</b>", "sub"),
     Spacer(1, 0.25 * cm),
     p("Este PDF resume la resolución. Los scripts, la especificación, los logs, las respuestas completas de la IA y la "
       "BITACORA.md están en <b>tp7/</b>, con un commit por parte. Todo se ejecutó solo sobre la base de laboratorio propia "
       "<b>food_store_tp7_lab</b> (PostgreSQL 16.15, localhost). <b>Herramientas:</b> OpenCode y Kiro no estaban disponibles "
       "en el entorno de resolución. Las consultas a la IA se hicieron con instancias separadas de Claude sin acceso al "
       "repositorio, y la especificación se escribió en formato Kiro. Los prompts literales están en tp7/docs/ia/."),

     p("Parte A - Roles y permisos de mínimo privilegio", "h1"),
     p("La spec (requirements, design y tasks) se escribió antes que <b>roles.sql</b>. Separa propiedad, privilegios e "
       "identidades. <b>food_store_owner</b> (sin login) es dueño de todo. Los roles de grupo son rol_app_lectura, "
       "rol_app_escritura, rol_soporte, rol_reportes y rol_auditor (este último es adicional). Los logins son "
       "<b>app_web</b> (miembro de lectura y escritura) y <b>admin_datos</b> (miembro de food_store_owner con INHERIT "
       "FALSE: necesita SET ROLE). Permisos de columna: rol_app_lectura lee usuario sin password_hash ni teléfono; "
       "soporte, todo menos el hash; la app actualiza solo producto.stock y las columnas editables de cliente, pedido y "
       "detalle. Las tablas futuras nacen sin privilegios y las funciones futuras sin EXECUTE para PUBLIC (ALTER DEFAULT "
       "PRIVILEGES)."),
     capture(esperado, "Verificación esperado vs. real (role_table_grants + privilegios de columna y de función): 42 = 42, "
                       "0 diferencias. Además, \\du y 31/31 pruebas funcionales con SET ROLE (docs/verificacion_permisos.txt)."),
     p("<b>Auditoría de roles.sql con IA:</b> se aceptó quitar el SELECT automático sobre tablas futuras (un error de la "
       "v1), el UPDATE por columna, CONNECT para los roles de grupo, ROUTINES, los límites de sesión de app_web y la "
       "prohibición de que soporte resetee cuentas ADMIN. <b>Se rechazaron por ser más amplias de lo necesario</b> "
       "<i>GRANT rol_app_lectura TO rol_app_escritura</i> y <i>UPDATE (intentos_fallidos, bloqueado_hasta)</i> para "
       "soporte. También se detectaron errores de la IA: columnas inexistentes y una restricción CHECK que ya existía."),

     p("Parte B - Auditoría", "h1")]
S += [table([["Parámetro", "Antes", "Después"],
             ["log_connections / log_disconnections", "off / off", "on / on"],
             ["log_statement", "none", "mod (y all solo para app_web)"],
             ["log_line_prefix", "%m [%p] %q%u@%d ", "%m [%p] %q%u@%d %h app=%a "],
             ["log_timezone", "Etc/UTC", "America/Argentina/Buenos_Aires"]], [5.5 * cm, 4.5 * cm, 7.8 * cm]),
      Spacer(1, 0.2 * cm),
      capture(log_b, "Fragmento de docs/log_auditoria_prueba.txt (líneas de sentencias, errores y autorizaciones): lectura, "
                     "inserción, actualización, fn_autenticar fallido, admin_datos sin y con SET ROLE, login fallido."),
      p("<b>Útil:</b> cuándo (%m), quién (%u e identidad SCRAM), desde dónde (%h), con qué aplicación (%a), qué sentencia "
        "y qué falló (ERROR/FATAL con la regla de pg_hba). <b>Fuera de alcance:</b> filas leídas o modificadas, lo que pasa "
        "dentro de funciones, la identidad efectiva tras SET ROLE y las lecturas de los demás roles. pgaudit agregaría "
        "auditoría por clase y por objeto. <b>El log es sensible:</b> contiene emails y las contraseñas pasadas a "
        "fn_autenticar en claro. Debería leerlo solo la cuenta postgres y un grupo de auditoría reducido (archivo 0640 "
        "postgres:adm, log_file_mode 0600); en el motor, solo superusuarios o pg_read_server_files.")]

S += [p("Parte C - Simulacro de incidente", "h1"),
      p("Como app_web desde <i>sqlcli</i>: 4 fallos y 1 acierto contra fn_autenticar sobre la cuenta 17 (contraseña débil). "
        "SELECT * FROM usuario denegado por el hash, pero la lectura por columnas devolvió 2.000 filas. Los cinco intentos "
        "de escalamiento fallaron: GRANT admin_datos (x2), SET ROLE admin_datos, fn_resetear_password y DELETE de la "
        "auditoría."),
      capture(log_c, "Log anonimizado (docs/log_simulacro_anonimizado.txt), filtrado a sentencias, errores y mensajes de "
                     "fn_autenticar. Es lo único que recibió la IA."),
      capture(verif_c, "Verificación como administrador: admin_datos sin miembros, membresías sin cambios y ningún reseteo "
                       "de contraseña. El escalamiento falló."),
      p("<b>Contraste con la IA:</b> acertó la secuencia completa, los motivos de cada rechazo y que la lectura parcial de "
        "usuario era lo más grave. <b>No sustentado por el log:</b> que el usuario 1 fuera administrador (es OPERADOR), que "
        "el bloqueo no se aplicara en la sesión (el umbral es 5) y el volumen leído dado como hecho. <b>Omisiones:</b> el "
        "origen real era 127.0.0.1, así que bloquear la IP no sirve e indica un acceso al host; tampoco mencionó el corte de "
        "servicio al rotar app_web ni la Ley 25.326. <b>Decisión del equipo</b>, tomada con evidencia sin anonimizar: "
        "terminar sesiones de app_web ajenas a la tienda, rotar la credencial coordinada con el despliegue, restringir "
        "pg_hba e investigar el acceso al host, resetear la cuenta 17, evaluar la notificación por la exposición de 2.000 "
        "emails y corregir el diseño (perfil propio en lugar del SELECT por columnas, bloqueo a 3 con retardo, pgaudit). No "
        "se revierte ningún rol, porque nada cambió.")]

S += [p("Parte D - Anonimización y equivalencia", "h1"),
      p("<b>usuario_anon</b>: seudónimo determinista por md5(sal ‖ id), nombres y emails sintéticos, teléfono y hash "
        "suprimidos, fecha generalizada a mes; solo rol_reportes la lee. Tiene 0 emails reales y 0 nombres reales. Riesgo "
        "residual documentado: hay grupos (rol, mes) de 1 persona. Las consultas de agregación por rol y mes las generó la "
        "IA a partir de una especificación precisa y se ejecutaron sin cambios:"),
      capture(equiv + [""] + totales, "Equivalencia: EXCEPT 0 y 0, 74 = 74 grupos y mismos totales; la tabla de los 74 "
                                      "grupos está en docs/verificacion_equivalencia.md. Control negativo: sin AT TIME "
                                      "ZONE y con TimeZone Asia/Tokyo difieren 28 grupos."),
      p("<b>Nunca hacia una IA sin anonimizar:</b> nombre, email, teléfono y dirección de usuarios y clientes con su "
        "historial; password_hash, contraseñas del log y credenciales; y los logs o la auditoria_acceso sin procesar, que "
        "combinan email, IP y horario."),

      p("Parte E - Bitácora e historial", "h1"),
      p("BITACORA.md tiene 8 registros (prompt, respuesta resumida y validación humana) y explica las herramientas usadas. "
        "Caso más significativo: la reconstrucción del incidente, porque sus afirmaciones sin sustento habrían orientado mal "
        "la contención. Se detectó exigiendo para cada afirmación una línea de evidencia en el log original, el script o "
        "la base. Historial: un commit por parte (A, B, C, D, E) con mensajes descriptivos, y una nota sobre qué se haría "
        "distinto.")]

SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=1.6 * cm, rightMargin=1.6 * cm, topMargin=1.3 * cm, bottomMargin=1.6 * cm,
                  title="TP Unidad 5 - Administración y seguridad - Mateo Algañaraz",
                  author="Mateo Algañaraz").build(S, onFirstPage=footer, onLaterPages=footer)
print(OUT)
