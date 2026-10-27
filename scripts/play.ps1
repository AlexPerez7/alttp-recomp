# Construye (si hace falta) y abre A Link to the Past desde este repositorio.
#
#   powershell -File scripts\play.ps1 [-Rom roms\alttp_usa.sfc] [-Rebuild] [-NoLaunch] [-- OPCIONES_DEL_JUEGO]
#
# -Rebuild   borra la caché de esa ROM y lo construye de nuevo (úsalo si el cambio no se nota).
# -NoLaunch  solo construye.
# El motor es snes-port.exe de la raíz (se sube con el repositorio y se actualiza con scripts\update-engine.ps1) o, si está
# definido, $env:SNES_ENGINE (una carpeta con snes-port.exe). Para jugar sin consola basta el doble clic en snes-port.exe.
param(
    [string]$Rom = "roms\alttp_usa.sfc",
    [switch]$Rebuild,
    [switch]$NoLaunch,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GameArgs = @()
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$dir = $root
if ($env:SNES_ENGINE -and (Test-Path "$env:SNES_ENGINE\snes-port.exe")) { $dir = $env:SNES_ENGINE }
$exe = Join-Path $dir "snes-port.exe"
if (-not (Test-Path $exe)) { throw "no hay snes-port.exe en $dir (scripts\update-engine.ps1 lo trae del motor)" }

if (-not (Test-Path $Rom)) { throw "no hay ROM en $Rom (pásala con -Rom o ponla en roms\)" }

if ($Rebuild) { & $exe clean $Rom; if ($LASTEXITCODE -ne 0) { throw "snes-port clean fallo" } }

$args2 = @($Rom, "--game", "games\alttp_usa.toml")
if ($NoLaunch) { $args2 += "--no-launch" }
if ($GameArgs.Count -gt 0) { $args2 += "--"; $args2 += $GameArgs }
& $exe @args2
exit $LASTEXITCODE
