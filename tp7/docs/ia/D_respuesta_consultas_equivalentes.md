# Parte D - Respuesta completa de la IA (consultas equivalentes)

Texto devuelto por la IA, sin editar. Las consultas se ejecutaron tal cual en `sql/verificacion_equivalencia.sql`.

---

Las dos consultas usan la misma agregación. La única diferencia es que en la tabla real el mes se calcula con la misma expresión que se usó para generar `usuario_anon.mes_alta`.

**Sobre `usuario_anon`:**

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

**Sobre `usuario` (tabla real):**

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

**Por qué devuelven exactamente lo mismo:**

- **Mismo mes:** `fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'` pasa de `timestamptz` a `timestamp` en hora de Buenos Aires. Así no influye el `TimeZone` de la sesión. Después `date_trunc` lo lleva al primer día del mes y `::date` lo deja como `date`. Es la misma expresión con la que se cargó `mes_alta`, así que cada usuario cae en el mismo grupo en las dos tablas. Si la agrupación se hiciera sobre `fecha_alta` sin `AT TIME ZONE`, las altas cercanas a la medianoche del último día del mes podrían quedar en otro mes.
- **Mismos tipos:**
  - `rol` es `varchar(20)` en las dos tablas.
  - `mes_alta` es `date` en las dos.
  - Los dos `count(...)` devuelven `bigint`.
  - El ordenamiento por `rol` usa la misma intercalación (collation), porque la columna tiene el mismo tipo.
- **Conteo de activos:** `count(*) FILTER (WHERE activo)` devuelve 0 cuando ningún usuario del grupo está activo, nunca NULL. En `usuario_anon`, `activo` admite NULL, pero se copió de una columna `NOT NULL`, así que en la práctica nunca es NULL. Igualmente, un NULL no se contaría como activo, que es lo mismo que pide la especificación.
- **Solo combinaciones con usuarios:** `GROUP BY` sin `JOIN` a un calendario solo genera grupos que tienen filas. Como cada combinación (rol, mes) aparece una sola vez, el orden por `mes_alta, rol` queda completamente determinado.

Revisé las dos consultas contra la especificación: columnas y orden, tipo `date` del mes, conteo total y de activos, y orden por mes y rol. No las ejecuté, porque me pediste no usar herramientas.

result: Escribí las dos consultas de agregación por (rol, mes de alta) para PostgreSQL 16, una sobre `usuario_anon` y otra sobre `usuario`, y deberían devolver las mismas filas y tipos (no las ejecuté).