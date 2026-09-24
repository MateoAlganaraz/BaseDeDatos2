param(
    [string]$Database = 'food_store_tpi_verificacion',
    [string]$User = 'postgres',
    [string]$LaboratorioId = 'TPI_CONC_20260923'
)

$ErrorActionPreference = 'Stop'
$Psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'

function Invoke-Pg([string]$Sql) {
    & $Psql -X -v ON_ERROR_STOP=1 -U $User -d $Database -Atqc $Sql
    if ($LASTEXITCODE -ne 0) { throw "psql fallo con codigo $LASTEXITCODE" }
}

function Start-PgSession([string]$Sql) {
    Start-Job -ArgumentList $Psql, $User, $Database, $Sql -ScriptBlock {
        param($Executable, $DbUser, $DbName, $Command)
        & $Executable -X -v ON_ERROR_STOP=1 -U $DbUser -d $DbName -Atqc $Command 2>&1
        if ($LASTEXITCODE -ne 0) { throw "psql fallo con codigo $LASTEXITCODE" }
    }
}

$literal = $LaboratorioId.Replace("'", "''")
$cleanup = @"
DELETE FROM detalle_pedido WHERE id_producto IN (SELECT p.id_producto FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria WHERE c.descripcion = 'Semilla TPI: $literal');
DELETE FROM producto p USING categoria c WHERE p.id_categoria = c.id_categoria AND c.descripcion = 'Semilla TPI: $literal';
DELETE FROM categoria WHERE descripcion = 'Semilla TPI: $literal';
"@

Invoke-Pg "$cleanup INSERT INTO categoria(nombre, descripcion) VALUES ('$literal', 'Semilla TPI: $literal'); INSERT INTO producto(nombre, precio_lista, stock, activo, id_categoria) SELECT '${literal}_PRECIO', 10, 10, TRUE, id_categoria FROM categoria WHERE descripcion = 'Semilla TPI: $literal'; INSERT INTO producto(nombre, precio_lista, stock, activo, id_categoria) SELECT '${literal}_BLOQUEO', 15, 10, TRUE, id_categoria FROM categoria WHERE descripcion = 'Semilla TPI: $literal';"

Write-Output "POSTGRESQL|$(Invoke-Pg 'SHOW server_version;')"
Write-Output 'ESCENARIO_1_LECTURA_NO_REPETIBLE'
$a = Start-PgSession "BEGIN ISOLATION LEVEL READ COMMITTED; SELECT 'RC_ANTES|' || precio_lista FROM producto WHERE nombre='${literal}_PRECIO'; SELECT pg_sleep(2); SELECT 'RC_DESPUES|' || precio_lista FROM producto WHERE nombre='${literal}_PRECIO'; COMMIT;"
Start-Sleep -Milliseconds 400
$b = Start-PgSession "BEGIN; UPDATE producto SET precio_lista=20 WHERE nombre='${literal}_PRECIO'; SELECT 'B_RC_ACTUALIZO|' || precio_lista FROM producto WHERE nombre='${literal}_PRECIO'; COMMIT;"
Receive-Job -Wait -AutoRemoveJob $b
Receive-Job -Wait -AutoRemoveJob $a

Invoke-Pg "UPDATE producto SET precio_lista=10 WHERE nombre='${literal}_PRECIO';"
Write-Output 'ESCENARIO_1B_REPEATABLE_READ'
$a = Start-PgSession "BEGIN ISOLATION LEVEL REPEATABLE READ; SELECT 'RR_ANTES|' || precio_lista FROM producto WHERE nombre='${literal}_PRECIO'; SELECT pg_sleep(2); SELECT 'RR_DESPUES|' || precio_lista FROM producto WHERE nombre='${literal}_PRECIO'; COMMIT;"
Start-Sleep -Milliseconds 400
$b = Start-PgSession "BEGIN; UPDATE producto SET precio_lista=30 WHERE nombre='${literal}_PRECIO'; SELECT 'B_RR_ACTUALIZO|' || precio_lista FROM producto WHERE nombre='${literal}_PRECIO'; COMMIT;"
Receive-Job -Wait -AutoRemoveJob $b
Receive-Job -Wait -AutoRemoveJob $a

Write-Output 'ESCENARIO_2_FANTASMA_READ_COMMITTED'
$a = Start-PgSession "BEGIN ISOLATION LEVEL READ COMMITTED; SELECT 'RC_CONTEO_ANTES|' || count(*) FROM producto WHERE activo AND id_categoria=(SELECT id_categoria FROM categoria WHERE nombre='$literal'); SELECT pg_sleep(2); SELECT 'RC_CONTEO_DESPUES|' || count(*) FROM producto WHERE activo AND id_categoria=(SELECT id_categoria FROM categoria WHERE nombre='$literal'); COMMIT;"
Start-Sleep -Milliseconds 400
$b = Start-PgSession "BEGIN; INSERT INTO producto(nombre, precio_lista, stock, activo, id_categoria) SELECT '${literal}_FANTASMA', 5, 1, TRUE, id_categoria FROM categoria WHERE nombre='$literal'; SELECT 'B_RC_INSERTO|1'; COMMIT;"
Receive-Job -Wait -AutoRemoveJob $b
Receive-Job -Wait -AutoRemoveJob $a

Invoke-Pg "DELETE FROM producto WHERE nombre='${literal}_FANTASMA';"
Write-Output 'ESCENARIO_2B_FANTASMA_REPEATABLE_READ'
$a = Start-PgSession "BEGIN ISOLATION LEVEL REPEATABLE READ; SELECT 'RR_CONTEO_ANTES|' || count(*) FROM producto WHERE activo AND id_categoria=(SELECT id_categoria FROM categoria WHERE nombre='$literal'); SELECT pg_sleep(2); SELECT 'RR_CONTEO_DESPUES|' || count(*) FROM producto WHERE activo AND id_categoria=(SELECT id_categoria FROM categoria WHERE nombre='$literal'); COMMIT;"
Start-Sleep -Milliseconds 400
$b = Start-PgSession "BEGIN; INSERT INTO producto(nombre, precio_lista, stock, activo, id_categoria) SELECT '${literal}_FANTASMA', 5, 1, TRUE, id_categoria FROM categoria WHERE nombre='$literal'; SELECT 'B_RR_INSERTO|1'; COMMIT;"
Receive-Job -Wait -AutoRemoveJob $b
Receive-Job -Wait -AutoRemoveJob $a

Write-Output 'ESCENARIO_3_BLOQUEO_DE_FILA'
$a = Start-PgSession "BEGIN; SELECT 'A_BLOQUEO|' || id_producto FROM producto WHERE nombre='${literal}_BLOQUEO' FOR UPDATE; SELECT pg_sleep(5); COMMIT; SELECT 'A_LIBERO|' || clock_timestamp();"
# El proceso psql de A se inicia antes de B; cinco segundos de retencion dejan margen
# para que la segunda sesion entre en espera. La salida conserva ambas marcas de tiempo.
Start-Sleep -Seconds 2
$b = Start-PgSession "BEGIN; SET LOCAL lock_timeout='5s'; SELECT 'B_INICIO|' || clock_timestamp(); SELECT 'B_FILA_BLOQUEADA|' || id_producto FROM producto WHERE nombre='${literal}_BLOQUEO' FOR UPDATE; SELECT 'B_ADQUIRIO|' || clock_timestamp(); COMMIT;"
Receive-Job -Wait -AutoRemoveJob $b
Receive-Job -Wait -AutoRemoveJob $a

Invoke-Pg $cleanup
Write-Output 'LIMPIEZA_TPI_CONCURRENCIA|OK'
