# DU/IA - Parte 1: restricciones de integridad

## Declaracion transparente

- Herramienta de IA utilizada: OpenCode / OpenAI, modelo `openai/gpt-5.6-terra`.
- Uso: asistencia para convertir requisitos de integridad en restricciones declarativas y diseñar pruebas transaccionales.
- Responsabilidad del estudiante: revisar sintaxis, ejecutar en su entorno y registrar evidencia real.

## Prompt utilizado

> Implementar para un esquema PostgreSQL Food Store tres reglas: `producto.precio_lista > 0`, `btrim(producto.nombre) <> ''` y `detalle_pedido.precio_unitario > 0`. El esquema actual admite cero en los precios. Preparar un script de ALTER TABLE que no inicie una transaccion automatica, indique revision previa y sea aplicable manualmente con BEGIN/ROLLBACK. Preparar pruebas autocontenidas con categoria, cliente, producto y pedido temporales; los INSERT invalidos deben estar protegidos por SAVEPOINT y el script debe terminar en ROLLBACK.

## Aporte de IA y control humano

La IA propuso reemplazar los dos `CHECK` no negativos por `CHECK (> 0)` y agregar un `CHECK` basado en `btrim`. Tambien propuso el uso de `SAVEPOINT` seguido de `ROLLBACK TO SAVEPOINT` para que un error esperado no invalide la transaccion exterior. El estudiante debe verificar que no haya filas existentes que violen las nuevas reglas antes de confirmar los cambios.

## Verificacion real

Ejecución verificada el 23/09/2026 sobre `food_store_tpi_verificacion_final`, PostgreSQL 18.4. `tpi/03_pruebas_objetos.sql` comprobó mediante bloques que capturan `check_violation` el rechazo de precio de lista cero, nombre compuesto solo por espacios y precio unitario cero. La transacción terminó con `ROLLBACK`; salida en `tpi/evidencia/20260923_214500/04_pruebas_objetos.txt`.
