"""Anonimiza un fragmento de log de PostgreSQL antes de entregarlo a un asistente de IA.

Criterio (el mismo que usuario_anon, Parte D): reemplazar todo dato que identifique a una
persona o que sea secreto por un valor sintético DETERMINISTA, de modo que el análisis siga
siendo posible (el mismo email siempre se convierte en el mismo seudónimo) pero el dato real
no salga del entorno.

  * emails                          -> usuario_N@ejemplo.invalid (N por orden de aparición)
  * contraseñas en llamadas a        -> '[CLAVE_REDACTADA]'
    fn_autenticar / fn_resetear_password, PASSWORD '...' y password=...
  * direcciones IP                   -> ip_origen_N
  * nombres de personas de la lista  -> Persona_N (por si aparecen en literales)
  * usuario del sistema operativo del DBA (root, postgres) en el prefijo -> dba_local

Se conservan: marcas de tiempo, PID, roles del motor, nombre de la base, application_name,
sentencias SQL (con los literales sensibles ya reemplazados), códigos de error e id_usuario
(identificador interno sin significado fuera de la base).

Uso: python3 anonimizar_log.py log_original.txt > log_anonimizado.txt
"""
import re
import sys

NOMBRES = ["Ana", "Bruno", "Carla", "Diego", "Elena", "Facundo", "Gabriela", "Hernán", "Inés", "Julián",
           "Lucía", "Martín", "Natalia", "Oscar", "Paula", "Ramiro", "Sofía", "Tomás", "Valentina", "Joaquín",
           "Gómez", "Pereyra", "Sosa", "Ríos", "Funes", "Videla", "Molina", "Correa", "Ortiz", "Lucero",
           "Quiroga", "Morales", "Aguirre", "Domínguez", "Ponce", "Navarro", "Herrera", "Zapata"]

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
IP = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b|(?<![\w:])::1\b")
CLAVE_FN = re.compile(r"((?:fn_autenticar|fn_resetear_password)\s*\(\s*[^,]+,\s*)'(?:[^']|'')*'", re.IGNORECASE)
CLAVE_PASSWORD = re.compile(r"(PASSWORD\s+)'(?:[^']|'')*'", re.IGNORECASE)
CLAVE_CONN = re.compile(r"(password=)\S+", re.IGNORECASE)
NOMBRE = re.compile(r"\b(" + "|".join(map(re.escape, NOMBRES)) + r")\b")
DBA = re.compile(r"(\] )(root|postgres)(@)")


class Seudonimos:
    def __init__(self, formato):
        self.formato = formato
        self.mapa = {}

    def __call__(self, match):
        valor = match.group(0)
        clave = valor.lower()
        if clave not in self.mapa:
            self.mapa[clave] = self.formato.format(len(self.mapa) + 1)
        return self.mapa[clave]


def anonimizar(texto):
    emails = Seudonimos("usuario_{}@ejemplo.invalid")
    ips = Seudonimos("ip_origen_{}")
    nombres = Seudonimos("Persona_{}")
    texto = CLAVE_FN.sub(r"\1'[CLAVE_REDACTADA]'", texto)
    texto = CLAVE_PASSWORD.sub(r"\1'[CLAVE_REDACTADA]'", texto)
    texto = CLAVE_CONN.sub(r"\1[CLAVE_REDACTADA]", texto)
    texto = EMAIL.sub(emails, texto)
    texto = IP.sub(ips, texto)
    texto = NOMBRE.sub(nombres, texto)
    texto = DBA.sub(r"\1dba_local\3", texto)
    return texto


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
        sys.stdout.write(anonimizar(f.read()))
