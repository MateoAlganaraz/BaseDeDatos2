# Parte D - Anonimización y verificación de equivalencia

## 1. `usuario_anon`

Script: [`sql/usuario_anon.sql`](../sql/usuario_anon.sql). Salida: [`evidencia/D_usuario_anon.txt`](../evidencia/D_usuario_anon.txt).

`usuario_anon` sigue el patrón de la clase: datos sintéticos **deterministas** derivados de un seudónimo, de modo que con la misma tabla `usuario` y la misma sal siempre se obtiene la misma copia.

| Columna real | En `usuario_anon` | Técnica |
|---|---|---|
| `id_usuario` | `id_anon` | Seudónimo secuencial asignado en el orden de `md5(sal ‖ id)`: no conserva el orden de alta ni permite volver al id sin la sal. |
| `nombre`, `apellido`, `email` | `Nombre_00001`, `Apellido_00001`, `usuario_00001@ejemplo.invalid` | Reemplazo sintético derivado de `id_anon`. |
| `telefono`, `password_hash`, `intentos_fallidos`, `bloqueado_hasta` | no existen | Supresión. |
| `fecha_alta` | `mes_alta` | Generalización al primer día del mes, en hora de Buenos Aires. |
| `rol`, `activo` | sin cambios | Son los atributos que el análisis agregado necesita. |

Controles ejecutados: 0 emails reales y 0 pares nombre + apellido reales presentes en `usuario_anon`; 2.000 filas en ambas tablas; `rol_reportes` puede leer `usuario_anon` pero ninguna columna de `usuario`. **Riesgo residual detectado:** el grupo más chico por (rol, mes) tiene 1 persona y hay 3 grupos con menos de 3 (por ejemplo, un único ADMIN dado de alta en un mes). Para publicar ese cruce fuera de la empresa habría que suprimir o agrupar los grupos chicos (k-anonimato). Para reportes internos se acepta.

## 2. Consultas especificadas a la IA

[Prompt](ia/D_prompt_consultas_equivalentes.md): definición de ambas tablas (sin datos) y la especificación exacta (una fila por rol y mes de alta con al menos un usuario; columnas `rol`, `mes_alta` como `date`, `cantidad_usuarios` y `cantidad_activos`; orden por mes y rol). [Respuesta completa](ia/D_respuesta_consultas_equivalentes.md).

**Q_anon** (generada por la IA, sin cambios):

```sql
SELECT
    rol,
    mes_alta,
    count(*)                         AS cantidad_usuarios,
    count(*) FILTER (WHERE activo)   AS cantidad_activos
FROM usuario_anon
GROUP BY rol, mes_alta
ORDER BY mes_alta, rol;
```

**Q_real** (generada por la IA, sin cambios):

```sql
SELECT
    rol,
    date_trunc('month', fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS mes_alta,
    count(*)                         AS cantidad_usuarios,
    count(*) FILTER (WHERE activo)   AS cantidad_activos
FROM usuario
GROUP BY rol, date_trunc('month', fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
ORDER BY mes_alta, rol;
```

## 3. Evidencia de equivalencia

Script: [`sql/verificacion_equivalencia.sql`](../sql/verificacion_equivalencia.sql). Salida completa: [`evidencia/D_verificacion_equivalencia.txt`](../evidencia/D_verificacion_equivalencia.txt).

| Control | Resultado |
|---|---:|
| `Q_real EXCEPT Q_anon` | 0 |
| `Q_anon EXCEPT Q_real` | 0 |
| Grupos (rol, mes) en Q_real / Q_anon | 74 / 74 |
| Usuarios totales real / anon | 2.000 / 2.000 |
| Activos totales real / anon | 1.914 / 1.914 |
| Tipos de columna | idénticos: `varchar(20)`, `date`, `bigint`, `bigint` |

Totales por rol:

| Rol | Usuarios (real) | Usuarios (anon) | Activos (real) | Activos (anon) |
|---|---:|---:|---:|---:|
| ADMIN | 20 | 20 | 20 | 20 |
| CLIENTE | 1.699 | 1.699 | 1.625 | 1.625 |
| OPERADOR | 121 | 121 | 116 | 116 |
| REPARTIDOR | 160 | 160 | 153 | 153 |

**Control negativo:** la versión ingenua de Q_real, agrupando por `date_trunc('month', fecha_alta)` sin `AT TIME ZONE`, ejecutada en una sesión con `TimeZone = 'Asia/Tokyo'`, produce **28 grupos distintos** de Q_anon: las altas de la tarde del último día de cada mes en Buenos Aires caen en el mes siguiente en Tokio. La equivalencia depende de que ambas consultas usen la misma definición de "mes", y la de la IA la respeta porque el prompt la especificaba.

Resultados lado a lado (los 74 grupos):

| Mes de alta | Rol | Usuarios (real) | Usuarios (anon) | Activos (real) | Activos (anon) | ¿Igual? |
|---|---|---:|---:|---:|---:|:-:|
| 2025-01-01 | ADMIN | 2 | 2 | 2 | 2 | sí |
| 2025-01-01 | CLIENTE | 80 | 80 | 77 | 77 | sí |
| 2025-01-01 | OPERADOR | 5 | 5 | 5 | 5 | sí |
| 2025-01-01 | REPARTIDOR | 6 | 6 | 6 | 6 | sí |
| 2025-02-01 | CLIENTE | 70 | 70 | 69 | 69 | sí |
| 2025-02-01 | OPERADOR | 7 | 7 | 7 | 7 | sí |
| 2025-02-01 | REPARTIDOR | 8 | 8 | 6 | 6 | sí |
| 2025-03-01 | CLIENTE | 83 | 83 | 78 | 78 | sí |
| 2025-03-01 | OPERADOR | 5 | 5 | 5 | 5 | sí |
| 2025-03-01 | REPARTIDOR | 6 | 6 | 6 | 6 | sí |
| 2025-04-01 | ADMIN | 3 | 3 | 3 | 3 | sí |
| 2025-04-01 | CLIENTE | 75 | 75 | 72 | 72 | sí |
| 2025-04-01 | OPERADOR | 6 | 6 | 5 | 5 | sí |
| 2025-04-01 | REPARTIDOR | 7 | 7 | 7 | 7 | sí |
| 2025-05-01 | CLIENTE | 80 | 80 | 77 | 77 | sí |
| 2025-05-01 | OPERADOR | 7 | 7 | 6 | 6 | sí |
| 2025-05-01 | REPARTIDOR | 7 | 7 | 7 | 7 | sí |
| 2025-06-01 | CLIENTE | 78 | 78 | 74 | 74 | sí |
| 2025-06-01 | OPERADOR | 5 | 5 | 5 | 5 | sí |
| 2025-06-01 | REPARTIDOR | 7 | 7 | 7 | 7 | sí |
| 2025-07-01 | ADMIN | 3 | 3 | 3 | 3 | sí |
| 2025-07-01 | CLIENTE | 78 | 78 | 74 | 74 | sí |
| 2025-07-01 | OPERADOR | 5 | 5 | 5 | 5 | sí |
| 2025-07-01 | REPARTIDOR | 8 | 8 | 8 | 8 | sí |
| 2025-08-01 | CLIENTE | 79 | 79 | 75 | 75 | sí |
| 2025-08-01 | OPERADOR | 7 | 7 | 7 | 7 | sí |
| 2025-08-01 | REPARTIDOR | 8 | 8 | 8 | 8 | sí |
| 2025-09-01 | CLIENTE | 78 | 78 | 75 | 75 | sí |
| 2025-09-01 | OPERADOR | 5 | 5 | 5 | 5 | sí |
| 2025-09-01 | REPARTIDOR | 8 | 8 | 6 | 6 | sí |
| 2025-10-01 | ADMIN | 3 | 3 | 3 | 3 | sí |
| 2025-10-01 | CLIENTE | 78 | 78 | 75 | 75 | sí |
| 2025-10-01 | OPERADOR | 5 | 5 | 5 | 5 | sí |
| 2025-10-01 | REPARTIDOR | 8 | 8 | 8 | 8 | sí |
| 2025-11-01 | CLIENTE | 77 | 77 | 74 | 74 | sí |
| 2025-11-01 | OPERADOR | 7 | 7 | 7 | 7 | sí |
| 2025-11-01 | REPARTIDOR | 6 | 6 | 6 | 6 | sí |
| 2025-12-01 | CLIENTE | 79 | 79 | 76 | 76 | sí |
| 2025-12-01 | OPERADOR | 4 | 4 | 3 | 3 | sí |
| 2025-12-01 | REPARTIDOR | 10 | 10 | 9 | 9 | sí |
| 2026-01-01 | ADMIN | 3 | 3 | 3 | 3 | sí |
| 2026-01-01 | CLIENTE | 80 | 80 | 76 | 76 | sí |
| 2026-01-01 | OPERADOR | 4 | 4 | 4 | 4 | sí |
| 2026-01-01 | REPARTIDOR | 6 | 6 | 6 | 6 | sí |
| 2026-02-01 | CLIENTE | 71 | 71 | 68 | 68 | sí |
| 2026-02-01 | OPERADOR | 7 | 7 | 7 | 7 | sí |
| 2026-02-01 | REPARTIDOR | 6 | 6 | 6 | 6 | sí |
| 2026-03-01 | CLIENTE | 79 | 79 | 75 | 75 | sí |
| 2026-03-01 | OPERADOR | 4 | 4 | 4 | 4 | sí |
| 2026-03-01 | REPARTIDOR | 10 | 10 | 10 | 10 | sí |
| 2026-04-01 | ADMIN | 3 | 3 | 3 | 3 | sí |
| 2026-04-01 | CLIENTE | 77 | 77 | 74 | 74 | sí |
| 2026-04-01 | OPERADOR | 4 | 4 | 4 | 4 | sí |
| 2026-04-01 | REPARTIDOR | 6 | 6 | 5 | 5 | sí |
| 2026-05-01 | CLIENTE | 79 | 79 | 76 | 76 | sí |
| 2026-05-01 | OPERADOR | 6 | 6 | 6 | 6 | sí |
| 2026-05-01 | REPARTIDOR | 8 | 8 | 7 | 7 | sí |
| 2026-06-01 | CLIENTE | 77 | 77 | 73 | 73 | sí |
| 2026-06-01 | OPERADOR | 5 | 5 | 5 | 5 | sí |
| 2026-06-01 | REPARTIDOR | 8 | 8 | 8 | 8 | sí |
| 2026-07-01 | ADMIN | 2 | 2 | 2 | 2 | sí |
| 2026-07-01 | CLIENTE | 79 | 79 | 77 | 77 | sí |
| 2026-07-01 | OPERADOR | 6 | 6 | 4 | 4 | sí |
| 2026-07-01 | REPARTIDOR | 6 | 6 | 6 | 6 | sí |
| 2026-08-01 | ADMIN | 1 | 1 | 1 | 1 | sí |
| 2026-08-01 | CLIENTE | 79 | 79 | 75 | 75 | sí |
| 2026-08-01 | OPERADOR | 5 | 5 | 5 | 5 | sí |
| 2026-08-01 | REPARTIDOR | 8 | 8 | 8 | 8 | sí |
| 2026-09-01 | CLIENTE | 76 | 76 | 72 | 72 | sí |
| 2026-09-01 | OPERADOR | 8 | 8 | 8 | 8 | sí |
| 2026-09-01 | REPARTIDOR | 6 | 6 | 6 | 6 | sí |
| 2026-10-01 | CLIENTE | 67 | 67 | 63 | 63 | sí |
| 2026-10-01 | OPERADOR | 4 | 4 | 4 | 4 | sí |
| 2026-10-01 | REPARTIDOR | 7 | 7 | 7 | 7 | sí |

## 4. Qué no debe salir nunca hacia un asistente de IA sin anonimizar

Ningún dato que identifique a un usuario o cliente de Food Store: nombre y apellido, email, teléfono y dirección de `usuario` y `cliente`, junto con su historial de pedidos asociado a esas personas. Tampoco los secretos: `password_hash`, las contraseñas que aparecen en el log (Parte B) ni las credenciales de `app_web` y `admin_datos`. Y tampoco los registros técnicos sin procesar: el log del servidor y `auditoria_acceso` combinan email, IP de origen y horario, y con eso se reconstruye quién hizo qué. Todo eso se entrega solo después de pasar por `usuario_anon` o por `anonimizar_log.py`, y únicamente si la consulta lo requiere.
