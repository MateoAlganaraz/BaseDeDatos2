# Parte D - Prompt enviado a la IA (consultas equivalentes)

Asistente: Claude (Anthropic), instancia separada sin acceso al repositorio ni a la base. Recibió solo la definición de las dos tablas (sin datos) y la especificación. Antes del texto se agregó la línea técnica "No uses herramientas ni leas archivos: respondé solo con texto, en español, a partir del mensaje que sigue."

## Prompt (literal)

Tengo dos tablas en PostgreSQL 16:

```sql
-- Tabla real
CREATE TABLE usuario (
    id_usuario        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre            VARCHAR(100) NOT NULL,
    apellido          VARCHAR(100) NOT NULL,
    email             VARCHAR(254) NOT NULL UNIQUE,
    telefono          VARCHAR(30),
    rol               VARCHAR(20)  NOT NULL,   -- 'ADMIN', 'OPERADOR', 'REPARTIDOR', 'CLIENTE'
    password_hash     TEXT         NOT NULL,
    fecha_alta        TIMESTAMPTZ  NOT NULL,
    activo            BOOLEAN      NOT NULL,
    intentos_fallidos INTEGER      NOT NULL,
    bloqueado_hasta   TIMESTAMPTZ
);

-- Copia anonimizada (una fila por cada fila de usuario)
CREATE TABLE usuario_anon (
    id_anon   BIGINT PRIMARY KEY,   -- seudónimo, no coincide con id_usuario
    nombre    TEXT,                 -- sintético
    apellido  TEXT,                 -- sintético
    email     TEXT,                 -- sintético
    rol       VARCHAR(20) NOT NULL, -- copiado sin cambios de usuario.rol
    mes_alta  DATE NOT NULL,        -- date_trunc('month', fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
    activo    BOOLEAN               -- copiado sin cambios de usuario.activo
);
```

Especificación de la consulta de agregación sobre usuario_anon:
- Una fila por cada combinación (rol, mes de alta) que tenga al menos un usuario.
- Columnas, en este orden: `rol`, `mes_alta` (tipo date, primer día del mes), `cantidad_usuarios` (cantidad total de usuarios, activos e inactivos) y `cantidad_activos` (cuántos de ellos tienen activo = true).
- Ordenada por `mes_alta` y luego por `rol`.

Escribí esa consulta sobre usuario_anon y la consulta equivalente sobre la tabla real usuario, que debe devolver exactamente las mismas filas con los mismos valores y tipos.
