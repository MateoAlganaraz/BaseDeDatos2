# TP3 desde DBeaver

Estos SQL son la variante para DBeaver de los scripts del TP3. No contienen metacomandos de `psql`; se ejecutan con el boton **Execute SQL Script** de DBeaver. Los archivos originales de `tp3/` no se modifican.

> Ejecutar solamente sobre una copia de laboratorio. La carga agrega 50.000 productos, 20.000 clientes, 200.000 pedidos y 400.000 detalles.

## 1. Respaldo y copia de laboratorio

1. En el navegador de DBeaver, seleccionar la base original, por ejemplo `food_store_base`.
2. Hacer clic derecho y elegir **Tools > Backup**. Elegir formato **Custom**, guardar el archivo como `backups/food_store_base_antes_tp3.dump` y ejecutar. Si DBeaver solicita configurar un cliente PostgreSQL nativo, indicar la carpeta `C:\Program Files\PostgreSQL\18\bin` en las preferencias de clientes nativos de PostgreSQL.
3. Crear o usar una conexion administrativa a la base `postgres` del mismo servidor. No conectarse a la base original para el siguiente comando.
4. Desconectar las conexiones de DBeaver que esten abiertas sobre `food_store_base`. En el editor SQL conectado a `postgres`, con **Auto-commit** activado, ejecutar:

```sql
CREATE DATABASE food_store_tp3_carga
    WITH TEMPLATE food_store_base;
```

5. Crear una conexion nueva en DBeaver a `food_store_tp3_carga` y comprobarla con:

```sql
SELECT current_database(), current_user;
```

Si el nombre `food_store_tp3_carga` ya existe, detenerse: no reemplazar ni borrar una base existente. Elegir otro nombre de copia y usar ese nombre en los pasos siguientes.

## 2. Configurar el lote

Los archivos que usan datos generados comienzan con esta linea editable:

```sql
SET app.tp3_lote = 'SB2026TP3';
```

Mantener exactamente el mismo valor en `00_preflight.sql`, `01_carga_masiva.sql`, `02_consultas_candidatas.sql` y `05_validacion.sql`. El lote solo puede contener letras, numeros y `_`. Si la carga ya fue ejecutada con ese valor, elegir uno nuevo antes de volver a ejecutar `01`.

## 3. Carga unica y dos copias de trabajo

1. Abrir `00_preflight.sql` y `01_carga_masiva.sql` en un editor SQL conectado a **food_store_tp3_carga**. Usar **Execute SQL Script** (no solo la sentencia bajo el cursor). Esperar que la carga finalice sin errores.
2. Desconectar `food_store_tp3_carga` en DBeaver. Volver al editor conectado a `postgres` y crear dos copias del laboratorio ya poblado:

```sql
CREATE DATABASE food_store_tp3_mediciones
    WITH TEMPLATE food_store_tp3_carga;

CREATE DATABASE food_store_tp3_competencia
    WITH TEMPLATE food_store_tp3_carga;
```

3. Crear una conexion DBeaver para cada base nueva. La copia **mediciones** se usa para las Partes 2, 3 y 4. La copia **competencia** queda sin los indices de Parte 2 para la Parte 5.

## 4. Partes 2, 3 y 4 en la copia de mediciones

Abrir cada archivo en un editor SQL conectado a **food_store_tp3_mediciones**. Usar **Execute SQL Script** y conservar los resultados y planes reales que muestre DBeaver.

1. `00_preflight.sql`: verifica base, tablas y restricciones.
2. `02_consultas_candidatas.sql`: dejar `SET app.tp3_fase = 'antes';` y ejecutar; guardar los tres planes `EXPLAIN (ANALYZE, BUFFERS)`.
3. `03_indices_aceptados.sql`: crea y verifica los tres indices aceptados.
4. Volver a `02_consultas_candidatas.sql`, cambiar unicamente la linea superior a `SET app.tp3_fase = 'despues';`, ejecutar y guardar los planes posteriores.
5. `04_parte4_consultas.sql`: ejecutar las consultas y revisar que los cuatro controles de equivalencia den `0`.
6. `05_validacion.sql`: debe finalizar sin excepciones y devolver `VALIDACION_COMPLETA_SIN_ERRORES`.

La Q1 de `02_consultas_candidatas.sql` calcula internamente la categoria objetivo mediante una CTE; no requiere variables ni comandos especiales de `psql`.

## 5. Parte 5 en la copia de competencia

1. Conectarse a **food_store_tp3_competencia** y ejecutar `06_consulta_comun_competencia.sql`. Guardar el plan como evidencia **antes**.
2. No ejecutar `03_indices_aceptados.sql` en esta copia. La estrategia de la competencia se decide solo despues de leer el plan inicial y debe justificarse para la consulta comun real de la catedra.
3. Aplicar solamente el indice o reescritura que se haya decidido, volver a ejecutar exactamente la misma consulta y guardar el plan **despues**.
4. Completar la tabla de competencia y la DUIA con los dos tiempos reales y la razon de la decision. Si la catedra entrega una consulta comun distinta, reemplazar el contenido de `06_consulta_comun_competencia.sql` por esa consulta sin modificar su semantica.

## Si algo falla

- Error de conexion: confirmar que el servicio `postgresql-x64-18` este **En ejecucion**, host `localhost` y puerto `5432`.
- Error al clonar por conexiones activas: cerrar editores y desconectar `food_store_base`; dejar abierta solo la conexion administrativa a `postgres`.
- Error de lote ya cargado: no repetir la carga con el mismo lote. Cambiar el valor de `app.tp3_lote` en los cuatro archivos indicados y empezar sobre una copia limpia.
