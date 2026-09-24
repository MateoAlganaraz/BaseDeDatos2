"""Agrega anexos de evidencia real al informe PDF del TP3.

Lee los planes conservados por PostgreSQL y genera una copia apta para entregar,
sin modificar el PDF original del estudiante.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import landscape, letter
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parent
EVIDENCE = ROOT / "evidencia" / "20260907_134508"
PAGE_WIDTH, PAGE_HEIGHT = landscape(letter)
MARGIN = 42
CODE_FONT_SIZE = 6.8
CODE_LINE_HEIGHT = 8.0


def extract_plans(path: Path) -> list[str]:
    """Devuelve los bloques QUERY PLAN sin alterar su salida original."""
    text = path.read_text(encoding="utf-8")
    blocks = re.findall(r"(?ms)^\s*QUERY PLAN.*?^\(\d+ rows\)$", text)
    if len(blocks) != 3:
        raise RuntimeError(f"Se esperaban tres planes en {path}, se encontraron {len(blocks)}.")
    return blocks


def wrap_code_line(line: str, width: int = 160) -> list[str]:
    """Parte solo para maquetar; conserva todos los caracteres de la salida."""
    if not line:
        return [""]
    return [line[index : index + width] for index in range(0, len(line), width)]


class Appendix:
    def __init__(self, output: Path) -> None:
        self.canvas = canvas.Canvas(str(output), pagesize=landscape(letter))
        self.page_number = 0
        self.y = PAGE_HEIGHT - MARGIN

    def new_page(self, title: str, subtitle: str = "") -> None:
        if self.page_number:
            self.canvas.showPage()
        self.page_number += 1
        self.y = PAGE_HEIGHT - MARGIN
        self.canvas.setFillColor(HexColor("#17365D"))
        self.canvas.setFont("Helvetica-Bold", 13)
        self.canvas.drawString(MARGIN, self.y, title)
        self.y -= 18
        if subtitle:
            self.canvas.setFillColor(HexColor("#444444"))
            self.canvas.setFont("Helvetica", 8.5)
            self.canvas.drawString(MARGIN, self.y, subtitle)
            self.y -= 15
        self.canvas.setStrokeColor(HexColor("#17365D"))
        self.canvas.line(MARGIN, self.y, PAGE_WIDTH - MARGIN, self.y)
        self.y -= 14

    def heading(self, text: str) -> None:
        self.canvas.setFillColor(HexColor("#17365D"))
        self.canvas.setFont("Helvetica-Bold", 10.5)
        self.canvas.drawString(MARGIN, self.y, text)
        self.y -= 14

    def paragraph(self, text: str) -> None:
        self.canvas.setFillColor(HexColor("#111111"))
        self.canvas.setFont("Helvetica", 8.5)
        words = text.split()
        line = ""
        for word in words:
            candidate = f"{line} {word}".strip()
            if self.canvas.stringWidth(candidate, "Helvetica", 8.5) > PAGE_WIDTH - 2 * MARGIN:
                self.canvas.drawString(MARGIN, self.y, line)
                self.y -= 11
                line = word
            else:
                line = candidate
        if line:
            self.canvas.drawString(MARGIN, self.y, line)
            self.y -= 14

    def code(self, text: str) -> None:
        self.canvas.setFillColor(HexColor("#111111"))
        self.canvas.setFont("Courier", CODE_FONT_SIZE)
        for original_line in text.splitlines():
            for line in wrap_code_line(original_line):
                if self.y < MARGIN + 16:
                    self.new_page("Anexo A - Planes EXPLAIN ANALYZE", "Continuación de la salida literal de PostgreSQL")
                    self.canvas.setFillColor(HexColor("#111111"))
                    self.canvas.setFont("Courier", CODE_FONT_SIZE)
                self.canvas.drawString(MARGIN, self.y, line)
                self.y -= CODE_LINE_HEIGHT

    def footer(self) -> None:
        self.canvas.setFillColor(HexColor("#666666"))
        self.canvas.setFont("Helvetica", 7.5)
        self.canvas.drawRightString(PAGE_WIDTH - MARGIN, 24, f"Anexo TP3 - página {self.page_number}")

    def finish(self) -> None:
        self.footer()
        self.canvas.save()


def build_appendix(output: Path) -> None:
    before = extract_plans(EVIDENCE / "02_planes_antes.txt")
    after = extract_plans(EVIDENCE / "04_planes_despues.txt")
    appendix = Appendix(output)

    labels = ("Q1", "Q2", "Q3")
    for label, plan in zip(labels, before):
        appendix.new_page("Anexo A - Planes EXPLAIN ANALYZE", f"{label}: medición antes del índice o cambio propuesto")
        appendix.heading(f"{label} - plan completo antes")
        appendix.code(plan)
        appendix.footer()
    for label, plan in zip(labels, after):
        appendix.new_page("Anexo A - Planes EXPLAIN ANALYZE", f"{label}: medición posterior al cambio aplicado")
        appendix.heading(f"{label} - plan completo después")
        appendix.code(plan)
        appendix.footer()

    appendix.new_page("Anexo B - Evidencia de Parte 3", "Plan posterior, prompt y respuesta de IA usados para la lectura crítica")
    appendix.heading("Plan posterior elegido: Q2")
    appendix.code(after[1])
    appendix.heading("Prompt enviado a la IA")
    appendix.paragraph(
        "Explicá este plan EXPLAIN ANALYZE de PostgreSQL nodo por nodo, sin contexto adicional. "
        "Indicá qué filtros usa, si necesita ordenar, qué representan cost, actual time, rows, loops y buffers, "
        "y no confundas costos estimados con milisegundos reales."
    )
    appendix.heading("Respuesta de IA contrastada")
    appendix.paragraph(
        "El plan utiliza el índice compuesto idx_tp3_pedido_forma_pago_fecha para localizar pedidos de "
        "TARJETA dentro del rango de 90 días. El Index Cond contiene ambos filtros. Como el índice conserva "
        "el orden de fecha descendente requerido por ORDER BY, PostgreSQL puede devolver los primeros 200 "
        "registros sin un nodo Sort. El costo 0.42..143.13 es una estimación del planificador; la medida "
        "real debe leerse en Execution Time, que es 0.553 ms. El acceso registró 200 buffers en memoria y "
        "4 lecturas, por lo que no se recorrió toda la tabla pedido."
    )
    appendix.paragraph(
        "Para el contraste crítico se agregó además la afirmación deliberadamente imprecisa «el costo final "
        "143.13 representa 143.13 ms», marcada como incorrecta en la tabla de la Parte 3."
    )
    appendix.footer()
    appendix.finish()


def merge(source: Path, appendix: Path, output: Path) -> None:
    writer = PdfWriter()
    for page in PdfReader(str(source)).pages:
        writer.add_page(page)
    for page in PdfReader(str(appendix)).pages:
        writer.add_page(page)
    with output.open("wb") as stream:
        writer.write(stream)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Uso: build_anexos_pdf.py PDF_ORIGINAL PDF_COMPLETO")
    source, output = map(Path, sys.argv[1:])
    appendix = ROOT / "tmp_pdf_review" / "anexos_tp3.pdf"
    appendix.parent.mkdir(parents=True, exist_ok=True)
    build_appendix(appendix)
    merge(source, appendix, output)
    print(output)


if __name__ == "__main__":
    main()
