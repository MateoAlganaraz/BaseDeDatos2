<#
=====================================================================
Mateo Algañaraz - Base de Datos II - 2026
TP Unidad 6 - Simulacro de restauración para Windows (equivalente a restore_test.sh).

Restaura el último respaldo de backups\ en foodstore_restore_test, valida conteos y
restricciones lógicas y registra RTO y RPO observados en logs\restore_AAAAMMDD_HHMMSS.log.
Nunca toca foodstore. Sin contraseñas: %APPDATA%\postgresql\pgpass.conf o PGPASSWORD.

Uso:   powershell -ExecutionPolicy Bypass -File .\restore_test.ps1 [-Jobs 2] [-Dump ruta.dump]
=====================================================================
#>
param(
    [string]$PgHost = $(if ($env:PGHOST) { $env:PGHOST } else { 'localhost' }),
    [string]$PgPort = $(if ($env:PGPORT) { $env:PGPORT } else { '5432' }),
    [string]$PgUser = 'postgres',
    [string]$Dump   = '',
    [int]$Jobs      = 1
)

$ErrorActionPreference = 'Stop'
$env:PGHOST = $PgHost; $env:PGPORT = $PgPort; $env:PGUSER = $PgUser
$SourceDb  = 'foodstore'
$RestoreDb = 'foodstore_restore_test'
$logDir = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("restore_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Log([string]$m) {
    $l = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'), $m
    Write-Output $l; Add-Content -Path $log -Value $l -Encoding utf8
}
function Assert-ExitCode([string]$p) { if ($LASTEXITCODE -ne 0) { throw "$p terminó con código $LASTEXITCODE" } }
function Invoke-Escalar([string]$db, [string]$sql) {
    $r = & psql -X -w -q -A -t -v ON_ERROR_STOP=1 -d $db -c $sql; Assert-ExitCode 'psql'; return ($r | Out-String).Trim()
}

try {
    if ($RestoreDb -eq $SourceDb) { throw "el destino no puede ser $SourceDb" }
    if (-not $Dump) {
        $ultimo = Get-ChildItem -Path (Join-Path $PSScriptRoot 'backups') -Filter '*.dump' -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $ultimo) { throw 'no hay respaldos en backups\' }
        $Dump = $ultimo.FullName
    }
    $counts = [System.IO.Path]::ChangeExtension($Dump, '.counts.csv')
    if (-not (Test-Path $counts)) { throw "falta el conteo previo $counts" }

    $cabecera = & pg_restore --list $Dump | Select-String '^; Archive created at (.+)$'
    Assert-ExitCode 'pg_restore --list'
    $creadoTexto = $cabecera.Matches[0].Groups[1].Value
    # Formato de pg_dump: "2026-10-26 11:18:39 -03"
    $creado = [DateTimeOffset]::ParseExact($creadoTexto, 'yyyy-MM-dd HH:mm:ss zz', $null)
    Write-Log ("Respaldo a restaurar: {0} (creado {1})" -f (Split-Path $Dump -Leaf), $creadoTexto)
    Write-Log "Destino: $RestoreDb en ${PgHost}:$PgPort como $PgUser; pg_restore -j $Jobs"

    & dropdb -w --if-exists $RestoreDb; Assert-ExitCode 'dropdb'

    # ---------------- Cronómetro ----------------
    $inicio = [DateTimeOffset]::Now
    $reloj = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Log 'INICIO del simulacro (cronómetro en marcha)'
    & createdb -w $RestoreDb; Assert-ExitCode 'createdb'
    & pg_restore -w -d $RestoreDb --no-owner --no-privileges -j $Jobs $Dump; Assert-ExitCode 'pg_restore'
    Write-Log ("Restauración terminada en {0:N2} s" -f $reloj.Elapsed.TotalSeconds)

    $consulta = "SELECT 'categoria' AS tabla, count(*) AS filas FROM categoria " +
                "UNION ALL SELECT 'cliente', count(*) FROM cliente " +
                "UNION ALL SELECT 'producto', count(*) FROM producto " +
                "UNION ALL SELECT 'pedido', count(*) FROM pedido " +
                "UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido"
    $restaurado = (& psql -X -w -q -v ON_ERROR_STOP=1 -d $RestoreDb -A -F ',' -P footer=off -c $consulta) -join "`n"
    Assert-ExitCode 'psql'
    $previo = ((Get-Content $counts) -join "`n").Trim()
    if ($restaurado.Trim() -ne $previo) { throw "los conteos no coinciden. Previo: $previo / Restaurado: $restaurado" }
    Write-Log ("Conteos OK (iguales al respaldo): " + (($restaurado -split "`n" | Select-Object -Skip 1) -join ' '))

    $prodInv = Invoke-Escalar $RestoreDb 'SELECT count(*) FROM producto WHERE precio_lista < 0 OR stock < 0'
    $detInv  = Invoke-Escalar $RestoreDb 'SELECT count(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0'
    Write-Log "productos_invalidos=$prodInv detalles_invalidos=$detInv"
    if ($prodInv -ne '0' -or $detInv -ne '0') { throw 'hay filas inválidas' }

    $sqlCons = "SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace WHERE n.nspname = 'public'"
    $consOrig = Invoke-Escalar $SourceDb $sqlCons
    $consRest = Invoke-Escalar $RestoreDb $sqlCons
    Write-Log "restricciones: origen=$consOrig restaurada=$consRest"
    if ($consOrig -ne $consRest) { throw 'faltan restricciones en la base restaurada' }

    $reloj.Stop()
    # ---------------- Fin del cronómetro ----------------
    $rpo = $inicio - $creado
    Write-Log 'FIN del simulacro: validaciones OK'
    Write-Log ("RTO observado: {0:N2} s (createdb + pg_restore + validaciones)" -f $reloj.Elapsed.TotalSeconds)
    Write-Log ("RPO observado: {0:N0} s ({1}) = antigüedad del respaldo al iniciar el simulacro" -f $rpo.TotalSeconds, $rpo.ToString('hh\:mm\:ss'))
    exit 0
}
catch {
    Write-Log "FALLA $($_.Exception.Message)"
    exit 1
}
