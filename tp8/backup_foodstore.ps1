<#
=====================================================================
Mateo Algañaraz - Base de Datos II - 2026
TP Unidad 6 - Respaldo lógico de foodstore para Windows (equivalente a backup_foodstore.sh).

Genera backups\foodstore_AAAAMMDD_HHMMSS.dump (formato custom), un .counts.csv con las filas
por tabla tomadas antes del respaldo y logs\backup_AAAAMMDD_HHMMSS.log. Si algo falla, borra
los archivos parciales y termina con código 1.

Sin contraseñas: la autenticación sale de %APPDATA%\postgresql\pgpass.conf o de la variable
PGPASSWORD de la sesión. Requiere pg_dump, pg_restore y psql en el PATH.

Uso:   powershell -ExecutionPolicy Bypass -File .\backup_foodstore.ps1
       .\backup_foodstore.ps1 -DbName foodstore -PgPort 5432
Programación sugerida (Programador de tareas, diaria 03:00):
       schtasks /Create /SC DAILY /ST 03:00 /TN "Respaldo foodstore" ^
         /TR "powershell -ExecutionPolicy Bypass -File C:\ruta\tp8\backup_foodstore.ps1"
=====================================================================
#>
param(
    [string]$PgHost    = $(if ($env:PGHOST) { $env:PGHOST } else { 'localhost' }),
    [string]$PgPort    = $(if ($env:PGPORT) { $env:PGPORT } else { '5432' }),
    [string]$PgUser    = $(if ($env:PGUSER) { $env:PGUSER } else { 'foodstore_backup' }),
    [string]$DbName    = 'foodstore',
    [string]$BackupDir = (Join-Path $PSScriptRoot 'backups'),
    [string]$LogDir    = (Join-Path $PSScriptRoot 'logs')
)

$ErrorActionPreference = 'Stop'
$env:PGHOST = $PgHost; $env:PGPORT = $PgPort; $env:PGUSER = $PgUser

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
New-Item -ItemType Directory -Force -Path $BackupDir, $LogDir | Out-Null
$dump    = Join-Path $BackupDir "${DbName}_$stamp.dump"
$partial = "$dump.partial"
$counts  = Join-Path $BackupDir "${DbName}_$stamp.counts.csv"
$log     = Join-Path $LogDir "backup_$stamp.log"

function Write-Log([string]$mensaje) {
    $linea = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'), $mensaje
    Write-Output $linea
    Add-Content -Path $log -Value $linea -Encoding utf8
}

function Assert-ExitCode([string]$programa) {
    if ($LASTEXITCODE -ne 0) { throw "$programa terminó con código $LASTEXITCODE" }
}

try {
    Write-Log "INICIO respaldo de $DbName en ${PgHost}:$PgPort como $PgUser"
    Write-Log ("pg_dump: " + (& pg_dump --version))

    $consulta = "SELECT 'categoria' AS tabla, count(*) AS filas FROM categoria " +
                "UNION ALL SELECT 'cliente', count(*) FROM cliente " +
                "UNION ALL SELECT 'producto', count(*) FROM producto " +
                "UNION ALL SELECT 'pedido', count(*) FROM pedido " +
                "UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido"
    $filas = & psql -X -q -w -v ON_ERROR_STOP=1 -d $DbName -A -F ',' -P footer=off -c $consulta
    Assert-ExitCode 'psql'
    $filas | Set-Content -Path $counts -Encoding utf8
    Write-Log ("Conteo previo guardado en {0}: {1}" -f (Split-Path $counts -Leaf), (($filas | Select-Object -Skip 1) -join ' '))

    $reloj = [System.Diagnostics.Stopwatch]::StartNew()
    & pg_dump -w -d $DbName -Fc -f $partial
    Assert-ExitCode 'pg_dump'
    $reloj.Stop()

    if (-not (Test-Path $partial) -or (Get-Item $partial).Length -eq 0) { throw 'El respaldo quedó vacío' }
    $objetos = (& pg_restore --list $partial | Where-Object { $_ -notmatch '^;' }).Count
    Assert-ExitCode 'pg_restore --list'
    Move-Item -Path $partial -Destination $dump

    $tamano = (Get-Item $dump).Length
    Write-Log ("Archivo: " + (Split-Path $dump -Leaf))
    Write-Log ("Tamaño: {0} bytes ({1:N1} MB)" -f $tamano, ($tamano / 1MB))
    Write-Log ("SHA-256: " + (Get-FileHash -Algorithm SHA256 -Path $dump).Hash.ToLower())
    Write-Log "Entradas en el índice (pg_restore --list): $objetos"
    Write-Log ("Duración de pg_dump: {0:N2} s" -f $reloj.Elapsed.TotalSeconds)
    Write-Log "OK respaldo de $DbName terminado"
    exit 0
}
catch {
    Remove-Item -Path $partial, $counts -ErrorAction SilentlyContinue
    Write-Log "ERROR respaldo de $DbName fallido: $($_.Exception.Message). Archivos parciales eliminados."
    exit 1
}
