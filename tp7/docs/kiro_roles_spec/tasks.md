# Implementation Plan

- [x] 1. Reconstruir `usuario`, `auditoria_acceso`, `fn_autenticar` y `fn_resetear_password` (`sql/00_base_usuarios.sql`). _Requisitos: R1, R3.3, R4.3, R6_
- [x] 2. Crear `food_store_owner` y transferirle la propiedad de los objetos de `public`. _R1_
- [x] 3. Crear los roles de grupo y otorgar los privilegios de la matriz del diseño, incluidos los de columna. _R2 a R6_
- [x] 4. Crear `app_web` y `admin_datos` con sus membresías y sin contraseña. _R7_
- [x] 5. Revocar la superficie pública y fijar `ALTER DEFAULT PRIVILEGES`. _R8_
- [x] 6. Verificar con `\du`, `role_table_grants`, `column_privileges` y `routine_privileges`, y con pruebas funcionales. _R9_ → `docs/verificacion_permisos.txt`
- [x] 7. Pedir a la IA una auditoría de `roles.sql` y registrar en `BITACORA.md` qué se aceptó y qué no.
