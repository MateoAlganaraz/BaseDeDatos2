[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Database,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_]+$')]
    [string]$Lote,
    [switch]$PrepararDatos,
    [string]$Psql = 'psql'
)

$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$marca = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidencia = Join-Path $raiz (Join-Path 'evidencia' $marca)
New-Item -ItemType Directory -Path $evidencia -Force | Out-Null

if (-not (Get-Command $Psql -ErrorAction SilentlyContinue)) {
    throw "No se encontro psql. Instala PostgreSQL o pasa -Psql con la ruta de psql.exe. No se ejecuto ningun SQL."
}

function Invoke-Tp3Sql {
    param([string]$Archivo, [string]$Salida, [string[]]$Variables = @())
    $ruta = Join-Path $raiz $Archivo
    $destino = Join-Path $evidencia $Salida
    $argumentos = @('-X', '--set=ON_ERROR_STOP=1', "--set=tp3_lote=$Lote") + $Variables + @('--dbname', $Database, '--file', $ruta)
    & $Psql @argumentos 2>&1 | Tee-Object -FilePath $destino
    if ($LASTEXITCODE -ne 0) { throw "Fallo $Archivo. Revisar $destino; no continuar con mediciones." }
}

Invoke-Tp3Sql '00_preflight.sql' '00_preflight.txt'
if ($PrepararDatos) {
    Invoke-Tp3Sql '01_carga_masiva.sql' '01_carga_masiva.txt'
}
Invoke-Tp3Sql '02_consultas_candidatas.sql' '02_planes_antes.txt' @('--set=tp3_fase=antes')
Invoke-Tp3Sql '03_indices_aceptados.sql' '03_indices_aceptados.txt'
Invoke-Tp3Sql '02_consultas_candidatas.sql' '04_planes_despues.txt' @('--set=tp3_fase=despues')
Invoke-Tp3Sql '04_parte4_consultas.sql' '05_parte4_consultas_y_except.txt'
Invoke-Tp3Sql '05_validacion.sql' '06_validacion.txt'

Write-Host "Evidencia real guardada en: $evidencia"
