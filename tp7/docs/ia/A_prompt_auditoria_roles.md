# Parte A - Prompt enviado a la IA (auditoría de roles.sql)

Asistente: Claude (Anthropic), instancia separada sin acceso al repositorio ni a esta conversación, con la instrucción de responder solo a partir del texto recibido. Se le envió `roles.sql` sin los comentarios de cabecera y con el bloque de transferencia de propiedad resumido en un comentario, más la nota final sobre columnas de identidad.

## Prompt

Auditá el siguiente archivo roles.sql de una tienda online ("Food Store") sobre PostgreSQL 16 y proponé mejoras o correcciones concretas, con las sentencias SQL que aplicarías. Tené en cuenta que la aplicación web (app_web) tiene que poder funcionar: registrar clientes, pedidos y detalles, descontar stock, autenticar usuarios, y que soporte y reportes tienen que poder hacer su trabajo. Tablas: categoria, producto, cliente, pedido, detalle_pedido (borrado lógico con deleted_at), usuario (usuarios de la app, con password_hash) y auditoria_acceso. fn_autenticar y fn_resetear_password son SECURITY DEFINER.

(seguía el contenido de `sql/roles.sql`, secciones 0 a 5, en un bloque de código)

Las tablas usan columnas GENERATED ALWAYS AS IDENTITY para sus claves.
