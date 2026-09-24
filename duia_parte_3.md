# DU/IA - Parte 3: informe y lectura critica

## Declaracion transparente

- Herramienta de IA utilizada: OpenCode / OpenAI, modelo `openai/gpt-5.6-terra`.
- Uso: asistencia para organizar el informe, separar expectativas de evidencia y explicar riesgos frecuentes de SQL.
- El contenido generado requiere validacion del estudiante frente al esquema real y los resultados reales de la practica.

## Prompt utilizado

> Redactar en español un informe de concurrencia con tres escenarios del laboratorio Food Store. Cada sección debe contener orden exacto de comandos, explicación basada en PostgreSQL y una separación clara entre resultado esperado y resultado observado. Agregar una lectura crítica de un UPDATE que desactiva todas las películas y de un DELETE basado en NOT IN que falla si la subconsulta contiene NULL; proponer una corrección segura sin inventar columnas del esquema.

## Aporte de IA y control humano

La IA explico que la condicion de baja de cartelera necesita una regla de negocio verificable, por ejemplo una fecha de fin validada en el esquema, y que `NOT EXISTS` evita la semantica de tres valores de `NOT IN` con `NULL`. La revision estatica incluyo la aclaracion de que las tablas del ejercicio son genericas de catedra y una reproduccion minima del caso `NULL`. El estudiante debe sustituir los campos ilustrativos por nombres confirmados de su propia base antes de ejecutar.

## Verificacion real

La ejecución posterior se documentó con evidencia de motor en `tpi/evidencia/20260923_214500/06_concurrencia.txt`. El informe actualizado en `informe_concurrencia.md` incorpora los resultados observados y mantiene la lectura crítica como análisis separado de las tablas genéricas de cátedra.
