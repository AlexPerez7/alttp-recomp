# Construye (si hace falta) y abre A Link to the Past desde este repositorio, sin tocar el del motor.
#
#   powershell -File scripts\play.ps1 [-Rom roms\alttp_usa.sfc] [-Rebuild] [-NoLaunch] [-EngineZip <zip>] [-- OPCIONES_DEL_JUEGO]
#
# -Rebuild   borra la caché de esa ROM y lo construye de nuevo (úsalo si el cambio no se nota).
# -NoLaunch  solo construye.
# El motor (snes-port.exe) se busca, por orden, en: $env:SNES_ENGINE (carpeta), engine\ de este repositorio (ignorado por
# git) y, si no hay ninguno, se extrae a engine\ el zip pasado con -EngineZip o el más reciente de
# ..\snes-recomp\out\release\ (lo genera scripts\release.ps1 del motor). Después ya no depende del otro repositorio.
param(
    [string]$Rom = "roms\alttp_usa.sfc",
    [switch]$Rebuild,
    [switch]$NoLaunch,
    [string]$EngineZip = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GameArgs = @()
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path $Rom)) { throw "no hay ROM en $Rom (pásala con -Rom o ponla en roms\)" }

$dir = $null
if ($env:SNES_ENGINE -and (Test-Path "$env:SNES_ENGINE\snes-port.exe")) { $dir = $env:SNES_ENGINE }
elseif (Test-Path "engine\snes-port.exe") { $dir = Join-Path $root "engine" }
else {
    if ($EngineZip -eq "") {
        $found = Get-ChildItem "..\snes-recomp\out\release\snes-port-*-win64.zip" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($found) { $EngineZip = $found.FullName }
    }
    if ($EngineZip -eq "" -or -not (Test-Path $EngineZip)) {
        throw "no hay motor: pon snes-port.exe en engine\, define SNES_ENGINE o pasa -EngineZip (zip de scripts\release.ps1 del motor)"
    }
    Write-Host "Extrayendo el motor de $EngineZip a engine\"
    $tmp = Join-Path $root "engine.tmp"
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    Expand-Archive -Path $EngineZip -DestinationPath $tmp
    $inner = Get-ChildItem $tmp -Directory | Where-Object { Test-Path "$($_.FullName)\snes-port.exe" } | Select-Object -First 1
    $src = if ($inner) { $inner.FullName } else { $tmp }
    if (-not (Test-Path "$src\snes-port.exe")) { Remove-Item -Recurse -Force $tmp; throw "el zip no trae snes-port.exe" }
    if (Test-Path "engine") { Remove-Item -Recurse -Force "engine" }
    Move-Item $src "engine"
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    $dir = Join-Path $root "engine"
}
$exe = Join-Path $dir "snes-port.exe"

if ($Rebuild) { & $exe clean $Rom; if ($LASTEXITCODE -ne 0) { throw "snes-port clean fallo" } }

$args2 = @($Rom, "--game", "games\alttp_usa.toml")
if ($NoLaunch) { $args2 += "--no-launch" }
if ($GameArgs.Count -gt 0) { $args2 += "--"; $args2 += $GameArgs }
& $exe @args2
exit $LASTEXITCODE
