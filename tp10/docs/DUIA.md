# DUIA - Declaración de Uso de IA - TP N.º 8 (Unidad 8)

## Declaración transparente

- **Herramienta de IA utilizada:** Claude (Anthropic), en Claude Code.
- **Herramientas que pide la consigna y no se usaron:** Kiro y OpenCode. No estaban disponibles en el entorno de resolución; ver `bitacora_ia.md`.
- **Uso:** redacción de la spec (`kiro/`), del esquema y las pruebas de SQLite, de la vista de la instantánea, del semáforo, de los scripts de los casos y del orquestador `run_tp10.sh`; revisión de los scripts de la cursada (3.c); redacción del README y del informe.
- **Datos compartidos con la IA:** solo el esquema y los datos de laboratorio, todos inventados (`TP6_PRODUCTO_*`, `tablet-feria-01`). No se compartieron contraseñas, mails ni datos personales reales.
- **Responsabilidad del estudiante:** leer cada script, ejecutarlo en su entorno y poder explicarlo en la defensa. Lo que no pueda explicar cuenta como no hecho (regla 4 de la consigna).

## Aporte de la IA y control humano

| Aporte | Control aplicado | Evidencia |
|---|---|---|
| Esquema SQLite con cuatro tablas STRICT, CHECK, FK y trigger | Se ejecutaron las pruebas de 1.c: el `COMMIT` guarda, el `ROLLBACK` deshace y C7 da error sin filas nuevas. | `evidencia/02_tablet_esquema_y_carga.txt`, `evidencia/03_pruebas_sqlite.txt` |
| Vista `v_snapshot_movil` con lápidas | Exportada e importada: 10.000 filas, y después 1 lápida en C4. | `evidencia/01_servidor_snapshot.txt` |
| Semáforo | C2 a C6 dan el resultado esperado. La segunda corrida evalúa 0 solicitudes. | `evidencia/04_casos_c2_c6.txt` |
| Garantía "la tablet no cambia el servidor" | El control final da 600.000 pedidos, 1.500.000 detalles y el mismo stock, con 0 productos distintos. | `evidencia/05_control_final.txt` |
| Code review | Cada hallazgo se comprobó en la base. Dos se descartaron con fundamento. | `evidencia/06_code_review.txt` |

## Qué se rechazó o corrigió

Se registra en `bitacora_ia.md`: la validación de UUID ilegible (B1), el caso borde del borrador sin ítems (B2), la preparación de C3 que habría invalidado el control de stock (B3), el orquestador que se cortaba en los errores esperados (B4), dos hallazgos del code review (R1) y el `mongodump` diario descartado (R2).
