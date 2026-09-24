# Ejercicio de lectura critica

Los ejemplos `pelicula`, `funcion` y `categoria` de este documento son un ejercicio generico de catedra, no tablas del esquema Food Store. No se debe modificar el esquema del proyecto para agregar esas tablas o columnas solo para resolver este ejercicio.

## Script 1: baja masiva de peliculas

Un `UPDATE` sin una condicion de negocio acotada que asigna `activo = false` desactiva todas las filas de la tabla. Agregar una condicion temporal generica, como `fecha_hora < CURRENT_TIMESTAMP`, tampoco demuestra que una pelicula haya salido de cartelera: esa columna podria representar una funcion, alta o actualizacion y no la vigencia en cartelera.

La correccion es intencionalmente esquematica: la columna temporal necesaria no forma parte del esquema Food Store. Si, en el modelo generico confirmado por la catedra, `pelicula.fecha_fin_cartel` representa efectivamente el fin de exhibicion, se puede previsualizar y aplicar dentro de una transaccion:

```sql
BEGIN;

SELECT id_pelicula, titulo, fecha_fin_cartel
FROM pelicula
WHERE fecha_fin_cartel IS NOT NULL
  AND fecha_fin_cartel < CURRENT_TIMESTAMP
  AND activo IS DISTINCT FROM FALSE;

UPDATE pelicula
SET activo = FALSE
WHERE fecha_fin_cartel IS NOT NULL
  AND fecha_fin_cartel < CURRENT_TIMESTAMP
  AND activo IS DISTINCT FROM FALSE
RETURNING id_pelicula, titulo;

ROLLBACK; -- Reemplazar por COMMIT solo despues de revisar el RETURNING.
```

Si no existe una columna que modele el fin de cartelera, primero debe definirse la condicion de negocio con el responsable funcional; no es seguro inventarla en el `UPDATE` ni cambiar Food Store por este ejemplo generico.

## Script 2: borrado con `NOT IN`

Una reproduccion minima muestra la semantica de tres valores. Aunque `2` no esta entre los identificadores no nulos de `funcion`, el `NULL` hace que `2 NOT IN (...)` sea desconocido y por eso no selecciona filas:

```sql
WITH pelicula(id_pelicula) AS (
    VALUES (1), (2), (3)
), funcion(id_pelicula) AS (
    VALUES (1), (NULL)
)
SELECT p.id_pelicula
FROM pelicula p
WHERE p.id_pelicula NOT IN (SELECT f.id_pelicula FROM funcion f);
-- Resultado esperado: cero filas, no las filas 2 y 3.
```

La forma preferible es `NOT EXISTS`, que correlaciona por una clave no nula y expresa directamente que no hay referencias:

```sql
DELETE FROM pelicula p
WHERE NOT EXISTS (
    SELECT 1
    FROM funcion f
    WHERE f.id_pelicula = p.id_pelicula
);
```

Antes de ejecutar, confirmar nombres de tablas, columnas, claves foraneas y la politica de conservacion de datos. Para una prueba segura, ejecutar primero el mismo predicado como `SELECT`, dentro de `BEGIN`, y terminar con `ROLLBACK` hasta contar con aprobacion explicita.
