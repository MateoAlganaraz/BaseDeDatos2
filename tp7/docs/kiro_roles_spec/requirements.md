# Requirements Document

## Introduction

> Versión 2. La versión 1 se escribió antes de `roles.sql`; la versión 2 incorpora los cambios aceptados después de la auditoría con IA (registro A2 de `BITACORA.md`). Los cambios están marcados con *(v2)*.

Food Store necesita un esquema de identidades en PostgreSQL que aplique el principio de mínimo privilegio. Cada rol debe habilitar solo las operaciones que su función requiere, los permisos se otorgan a roles de grupo (nunca a usuarios de login directamente), y la política debe mantenerse para las tablas que se creen en el futuro. Esta especificación se escribe **antes** que `sql/roles.sql`: cada permiso que aparezca en el script debe poder rastrearse hasta un requisito de este documento.

Alcance: base de laboratorio `food_store_tp7_lab` (esquema `schema.sql` + carga de Unidades 1 a 4 + tabla `usuario` y funciones `fn_autenticar` / `fn_resetear_password` reconstruidas de las Clases 1 y 2).

## Glosario

- **Rol de grupo:** rol `NOLOGIN` que agrupa privilegios.
- **Rol de login:** rol `LOGIN` que solo recibe privilegios por membresía en roles de grupo.
- **Dato personal:** nombre, apellido, email, teléfono, hash de contraseña o cualquier dato que identifique a un usuario o cliente.
- **Tabla de catálogo/operación:** `categoria`, `producto`, `pedido`, `detalle_pedido`.

## Requirements

### Requirement 1 - Propiedad separada de los logins

**User Story:** Como administrador de datos, quiero que los objetos pertenezcan a un rol sin login, para que ninguna credencial expuesta herede automáticamente los derechos de dueño.

#### Acceptance Criteria

1. THE SYSTEM SHALL asignar la propiedad de todas las tablas, secuencias, tipos y funciones del esquema `public` al rol `food_store_owner`, creado `NOLOGIN`.
2. THE SYSTEM SHALL ejecutar las funciones `SECURITY DEFINER` con los privilegios de `food_store_owner` y nunca con los de un superusuario.
3. WHEN `admin_datos` necesite operar como dueño THE SYSTEM SHALL exigir un `SET ROLE food_store_owner` explícito (membresía sin herencia automática).

### Requirement 2 - Lectura de la aplicación (`rol_app_lectura`)

**User Story:** Como aplicación web, quiero leer catálogo, clientes y pedidos, para mostrar productos y el historial de compras.

#### Acceptance Criteria

1. THE SYSTEM SHALL otorgar `SELECT` sobre `categoria`, `producto`, `cliente`, `pedido` y `detalle_pedido`.
2. THE SYSTEM SHALL otorgar `SELECT` sobre `usuario` **solo** en las columnas `id_usuario`, `nombre`, `apellido`, `email`, `rol` y `activo` (permiso a nivel de columna).
3. THE SYSTEM SHALL NOT permitir leer `usuario.password_hash`, `telefono`, `intentos_fallidos`, `bloqueado_hasta` ni `fecha_alta`.

### Requirement 3 - Escritura de la aplicación (`rol_app_escritura`)

**User Story:** Como aplicación web, quiero registrar clientes y pedidos y descontar stock, para operar la tienda.

#### Acceptance Criteria

1. THE SYSTEM SHALL otorgar `INSERT` sobre `cliente`, `pedido` y `detalle_pedido`, y `UPDATE` solo en las columnas que la aplicación modifica: `cliente(nombre, apellido, email, telefono, deleted_at)`, `pedido(forma_pago, deleted_at)` y `detalle_pedido(cantidad, deleted_at)`. *(v2: antes era `UPDATE` sobre la tabla completa; ver BITACORA.md, A2.)*
2. THE SYSTEM SHALL otorgar `UPDATE` sobre `producto` solo en la columna `stock`.
3. THE SYSTEM SHALL otorgar `EXECUTE` sobre `fn_autenticar(text, text)`.
4. THE SYSTEM SHALL NOT otorgar `DELETE` ni `TRUNCATE`: las bajas se registran con borrado lógico (`deleted_at`).

### Requirement 4 - Soporte (`rol_soporte`)

**User Story:** Como operador de soporte, quiero consultar el estado de una cuenta, habilitarla o deshabilitarla y resetear su contraseña, para atender reclamos de acceso.

#### Acceptance Criteria

1. THE SYSTEM SHALL otorgar `SELECT` sobre `usuario` en todas las columnas excepto `password_hash`.
2. THE SYSTEM SHALL otorgar `UPDATE` sobre `usuario` solo en la columna `activo`.
3. THE SYSTEM SHALL otorgar `EXECUTE` sobre `fn_resetear_password(bigint, text)`.
4. THE SYSTEM SHALL NOT otorgar acceso a pedidos, clientes ni a la tabla de auditoría.

### Requirement 5 - Reportes (`rol_reportes`)

**User Story:** Como analista, quiero consultar ventas y catálogo, para producir reportes agregados sin ver datos personales.

#### Acceptance Criteria

1. THE SYSTEM SHALL otorgar `SELECT` sobre `categoria`, `producto`, `pedido` y `detalle_pedido`.
2. THE SYSTEM SHALL otorgar `SELECT` sobre `usuario_anon` (Parte D) y NOT sobre `usuario` ni `cliente`.

### Requirement 6 - Auditoría (`rol_auditor`, rol adicional)

**User Story:** Como responsable de seguridad, quiero leer el registro de accesos sin poder modificarlo, para investigar incidentes sin que el registro dependa de los roles que se investigan.

#### Acceptance Criteria

1. THE SYSTEM SHALL otorgar `SELECT` sobre `auditoria_acceso` únicamente a `rol_auditor`.
2. THE SYSTEM SHALL NOT otorgar `INSERT`, `UPDATE` ni `DELETE` sobre `auditoria_acceso` a ningún rol de grupo; solo las funciones `SECURITY DEFINER` escriben en ella.

### Requirement 7 - Roles de login

#### Acceptance Criteria

1. THE SYSTEM SHALL crear `app_web` (`LOGIN`, `CONNECTION LIMIT 50`) como miembro de `rol_app_lectura` y `rol_app_escritura`, sin `CREATEDB`, `CREATEROLE`, `REPLICATION` ni `BYPASSRLS`.
2. THE SYSTEM SHALL crear `admin_datos` (`LOGIN`) como miembro de `food_store_owner` con `INHERIT FALSE` y `SET TRUE`, sin atributo `SUPERUSER` ni `CREATEROLE`.
3. THE SYSTEM SHALL NOT asignar contraseñas dentro de `roles.sql`; se configuran fuera del repositorio.
4. THE SYSTEM SHALL fijar en `app_web` `search_path = public`, `statement_timeout = 10s` e `idle_in_transaction_session_timeout = 30s`. *(v2)*

### Requirement 8 - Superficie pública y tablas futuras

#### Acceptance Criteria

1. THE SYSTEM SHALL revocar a `PUBLIC` el permiso `CONNECT` sobre la base y otorgarlo a los roles de login y a los roles de grupo de personas (`rol_soporte`, `rol_reportes`, `rol_auditor`), para que sus futuros logins se conecten por membresía. *(v2)*
2. THE SYSTEM SHALL revocar a `PUBLIC` todo privilegio sobre los esquemas `public` y `extensiones`, y `EXECUTE` sobre las rutinas (funciones y procedimientos) de ambos esquemas.
3. WHEN `food_store_owner` cree una tabla o secuencia nueva THE SYSTEM SHALL dejarla sin privilegios para otros roles hasta que se otorguen explícitamente (`ALTER DEFAULT PRIVILEGES ... REVOKE ALL ... FROM PUBLIC`). *(v2: la v1 otorgaba `SELECT` automático a `rol_app_lectura`; se descartó en la revisión A2.)*
4. WHEN `food_store_owner` cree una función o procedimiento nuevo THE SYSTEM SHALL NOT otorgarle `EXECUTE` a `PUBLIC`.

### Requirement 9 - Verificación

#### Acceptance Criteria

1. THE SYSTEM SHALL permitir comprobar con `\du` los atributos de cada rol.
2. THE SYSTEM SHALL permitir comprobar con `information_schema.role_table_grants` (y `column_privileges` / `routine_privileges` para columnas y funciones) que los privilegios reales coinciden exactamente con los de esta especificación: la diferencia en ambos sentidos debe ser vacía.
