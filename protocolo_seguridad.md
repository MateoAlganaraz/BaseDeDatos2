# Protocolo de seguridad

Este material es exclusivo para laboratorio academico. No se debe ejecutar sobre produccion ni sobre una base con datos que no se puedan restaurar. No guardar contrasenas, cadenas de conexion ni otros secretos en este repositorio; PostgreSQL solicitara la contrasena de forma interactiva cuando corresponda.

## Preparacion en Windows

Abrir PowerShell en la raiz del proyecto, definir los parametros de la sesion y verificar que las herramientas esten disponibles:

```powershell
$PgHost = 'localhost'
$PgPort = '5432'
$PgUser = 'postgres'
$BaseTrabajo = 'food_store_tp2'
$BaseAdministrativa = 'postgres'
psql --version
pg_dump --version
pg_restore --version
New-Item -ItemType Directory -Force backups
```

Crear la base de trabajo y cargar el esquema. Ejecutar estos comandos solo si el rol indicado posee permisos:

```powershell
psql -h $PgHost -p $PgPort -U $PgUser -d $BaseAdministrativa -c "SELECT current_database(), inet_server_addr(), inet_server_port(), current_user;"
createdb -h $PgHost -p $PgPort -U $PgUser $BaseTrabajo
psql -h $PgHost -p $PgPort -U $PgUser -d $BaseTrabajo -c "SELECT current_database(), inet_server_addr(), inet_server_port(), current_user;"
psql -h $PgHost -p $PgPort -U $PgUser -d $BaseTrabajo -v ON_ERROR_STOP=1 -f schema.sql
```

Antes de cualquier operacion de escritura sobre la base de trabajo, ejecutar y comprobar explicitamente los cuatro valores: `current_database`, `inet_server_addr`, `inet_server_port` y `current_user`. Detenerse si alguno no corresponde al servidor, puerto, base o rol esperados.

```powershell
psql -h $PgHost -p $PgPort -U $PgUser -d $BaseTrabajo -c "SELECT current_database(), inet_server_addr(), inet_server_port(), current_user;"
```

Crear una plantilla reutilizable solo despues de revisar que `$BaseTrabajo` es la base recien cargada:

```powershell
$BasePlantilla = 'food_store_base'
createdb -h $PgHost -p $PgPort -U $PgUser -T $BaseTrabajo $BasePlantilla
```

Para reiniciar una practica, crear una nueva base desde la plantilla, nunca sobrescribir una existente:

```powershell
$BaseSesion = 'food_store_tp2_sesion'
createdb -h $PgHost -p $PgPort -U $PgUser -T $BasePlantilla $BaseSesion
```

## Respaldo y restauracion

Antes de cambios de estructura, generar un respaldo con marca de tiempo:

```powershell
$marca = Get-Date -Format 'yyyyMMdd-HHmmss'
pg_dump -h $PgHost -p $PgPort -U $PgUser -Fc -f "backups\$BaseTrabajo-$marca.backup" $BaseTrabajo
```

Restaurar un respaldo unicamente en una base nueva y vacia. El destino debe estar fresco, sin esquema ni objetos previos; `pg_restore --exit-on-error` detiene la restauracion ante el primer error.

```powershell
$BaseRestaurada = 'food_store_tp2_restaurada'
createdb -h $PgHost -p $PgPort -U $PgUser $BaseRestaurada
psql -h $PgHost -p $PgPort -U $PgUser -d $BaseRestaurada -c "SELECT current_database(), inet_server_addr(), inet_server_port(), current_user;"
pg_restore -h $PgHost -p $PgPort -U $PgUser --exit-on-error -d $BaseRestaurada "backups\ARCHIVO.backup"
```

## Protocolo de ejecucion

1. Antes de cada archivo que escriba datos, volver a ejecutar la consulta de verificacion de conexion anterior y comprobar sus cuatro columnas.
2. Revisar primero los `SELECT` de cada script y ejecutar cambios de estructura dentro de una transaccion manual.
3. Para revision o prueba temporal usar siempre `BEGIN;` y finalizar con `ROLLBACK;`. Usar `COMMIT;` solo tras revision explicita y respaldo verificado.
4. Las practicas de concurrencia requieren dos sesiones independientes de `psql`, ambas conectadas con `-h $PgHost -p $PgPort -U $PgUser -d $BaseTrabajo`; no cerrar ni mezclar sus transacciones hasta completar cada escenario.
