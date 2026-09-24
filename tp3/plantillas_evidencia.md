# TP3 - Plantillas de evidencia real

No reemplazar campos sin medir con valores estimados. La fuente de evidencia es la salida generada por `run_mediciones.ps1` en `evidencia/<fecha_hora>/`.

## Parte 2

Para cada Q1, Q2 y Q3, transcribir desde el plan real: nodo principal, `cost`, `actual time`, filas, `loops`, `Buffers` si aparecen y tiempo de ejecucion total. La mejora temporal se calcula solo con tiempos reales comparables:

```text
Tiempo antes (ms): transcribir desde la salida del motor
Tiempo despues (ms): transcribir desde la salida del motor
Mejora x = tiempo antes / tiempo despues: calcular con ambos tiempos
```

Si el plan no mejora, registrarlo como resultado y justificarlo con los nodos reales; no eliminar el intento.

## Parte 3

Conservar una copia textual inalterada del plan elegido y de la respuesta de IA en `lectura_critica_plan.md`. No completar la columna "Correcta?" sin citar el campo del plan que la confirma o contradice.

## Parte 5

Ejecutar `06_consulta_comun_competencia.sql` antes de todo cambio de competencia y repetirlo despues. Guardar ambos archivos en la misma carpeta de evidencia y completar:

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo despues (ms) | Mejora (x) |
|---|---|---:|---:|---:|
| Mateo Algañaraz | Justificar con plan real | Transcribir antes | Transcribir después | Calcular con evidencia |

El indice de competencia no se crea de antemano: se propone solo despues de observar la consulta comun y se documenta en DUIA, incluso si se descarta.
