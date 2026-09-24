# Resultados reales TP3

Evidencia generada el 2026-09-07 en las copias locales `food_store_tp3_mediciones` y `food_store_tp3_competencia`.

## Carga masiva

La validacion confirmo 20.000 clientes, 50.000 productos, 200.000 pedidos y 400.000 detalles del lote `SB2026TP3`. La salida completa esta en `evidencia/20260907_134508/06_validacion.txt`.

## Parte 2

| Consulta | Tiempo antes | Tiempo despues | Mejora | Decision |
|---|---:|---:|---:|---|
| Q1 | 44.727 ms | 45.011 ms | 0.994x | No se acepta como mejora. El indice se uso, pero la CTE para calcular la categoria mantuvo un Seq Scan y el tiempo total subio levemente. |
| Q2 | 26.940 ms | 0.553 ms | 48.72x | Aceptado. Cambia de Parallel Seq Scan + Sort a Index Scan con `idx_tp3_pedido_forma_pago_fecha`. |
| Q3 | 68.061 ms | 52.491 ms | 1.30x | Aceptado. Cambia el filtrado temporal de `pedido` a Bitmap Index Scan con `idx_tp3_pedido_fecha`. |

## Parte 4

Los cuatro controles `EXCEPT` devolvieron 0 filas distintas. Las dos versiones de cada consulta son equivalentes sobre la base de laboratorio.

## Parte 5

La consulta comun paso de un Seq Scan de `producto` y Sort de 31.669 filas a un Index Only Scan con `idx_tp3_comp_producto_precio_activo`. Tiempo antes: 22.246 ms. Tiempo despues: 0.549 ms. Mejora: 40.52x.

## Evidencia

- `02_planes_antes.txt` y `04_planes_despues.txt`: Parte 2.
- `05_parte4_consultas_y_except.txt` y `06_validacion.txt`: equivalencia y controles.
- `07_competencia_antes.txt`, `08_indice_competencia.txt` y `09_competencia_despues.txt`: Parte 5.
