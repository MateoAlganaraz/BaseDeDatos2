# Informe técnico - TPI Food Store

## Alcance implementado por unidad

| Unidad | Implementación incorporada | Verificación |
|---|---|---|
| 1 - Integridad y concurrencia | CHECK, UNIQUE, borrado lógico, dos procedimientos PL/pgSQL, dos triggers, auditoría y rol de reportes. | `evidencia/20260923_214500/01_schema.txt` a `04_pruebas_objetos.txt`. |
| 2 - Optimización | Carga masiva, consultas con JOIN, agregación, subconsultas, ventana e índices medidos. | Evidencias históricas de `tp3/` y `tp4/`. |
| 3 - Índices y vistas | Índices de TP5, cuatro vistas, una vista materializada e índices parciales para bajas lógicas. | `tp5/evidencia/20260923_tpi/`. |

## Pruebas y resultados reales

La base aislada `food_store_tpi_verificacion_final` se creó desde `schema.sql` y se ejecutaron la migración, los objetos y las pruebas con PostgreSQL 18.4. El bloque reversible `03_pruebas_objetos.sql` terminó correctamente y verificó:

- precio de lista cero, precio de detalle cero y nombre vacío rechazados por CHECK;
- pedido válido: descuenta el stock y crea pedido más detalle en una única llamada;
- pedido con stock insuficiente: se rechaza sin crear un pedido parcial;
- trigger: no permite que un producto inactivo ingrese a un detalle;
- auditoría: registra los cambios de producto;
- baja lógica: la vista deja de mostrar el cliente y el email puede reutilizarse para una nueva fila vigente.

El control final informó 2 procedimientos, 2 triggers y 2 vistas; la transacción de prueba cerró con `ROLLBACK`.

## Transacciones, aislamiento y concurrencia

La ejecución real de dos sesiones está en `evidencia/20260923_214500/06_concurrencia.txt`.

| Escenario | Resultado observado |
|---|---|
| Lectura no repetible | `READ COMMITTED`: precio `10.00` y luego `20.00`; `REPEATABLE READ`: `10.00` y `10.00`. |
| Lectura fantasma | `READ COMMITTED`: conteo `2` y luego `3`; `REPEATABLE READ`: `2` y `2`. |
| Bloqueo de fila | B inició a las `20:30:49.634868-03` y adquirió la fila a las `20:30:52.401280-03`, en el mismo instante de la liberación de A (`20:30:52.401283-03`). |

## Optimización comprobada

TP3 y TP4 conservan sus planes originales. En TP5, la repetición de control de PostgreSQL 18.4 dejó la salida cruda antes/después y la equivalencia de vistas en `tp5/evidencia/20260923_tpi/`. Los planes siguen mostrando el cambio desde recorridos secuenciales hacia accesos por índice en las consultas seleccionadas; los ocho controles `EXCEPT` devolvieron cero diferencias. Los tiempos pueden variar por caché y carga, por eso la conclusión usa planes y evidencia de ambos estados, no un único valor.

## Uso de IA

Se utilizó Codex/OpenAI para estructurar scripts, documentación y controles reproducibles, y OpenCode para revisar propuestas de índices de TP5. Las propuestas no se aceptaron por autoridad de la herramienta: se contrastaron contra el esquema y salidas reales de PostgreSQL. Los registros específicos están en `duia_parte_*.md`, `tp3/duia_tp3.md`, `tp4/duia_tp4.md`, `tp5/duia.md` y `tp5/registro_codex.md`.
