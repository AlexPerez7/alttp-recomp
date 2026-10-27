# Arma out\release\alttp-recomp-<version>-win64.zip: el paquete del motor (snes-port.exe, snes-recomp.exe, SDL2, README y
# licencia) más games\ de este repositorio. El usuario descomprime, arrastra su ROM sobre snes-port.exe y juega.
# No lleva ROMs, partidas guardadas ni C generado: si algo así acaba en la carpeta, el script falla y no crea el zip.
#
#   powershell -File scripts\release.ps1 -Engine <zip o carpeta de snes-port del motor> [-Version 0.1.0] [-NoTcc]
#
# El paquete debe llevar el compilador del motor (toolchain\tcc\tcc.exe) para que quien solo quiere jugar no tenga que
# instalar ni descargar nada; si el zip del motor no lo trae, el script falla (salvo con -NoTcc).
# El zip del motor sale de `powershell -File scripts\release.ps1` en el repositorio snes-recomp.
param(
    [Parameter(Mandatory = $true)][string]$Engine,
    [string]$Version = "0.1.0",
    [switch]$NoTcc
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$name = "alttp-recomp-$Version-win64"
$stage = Join-Path $root "out\release\$name"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null

# el motor: un zip (se descomprime) o la carpeta ya armada
if ((Get-Item $Engine).PSIsContainer) {
    Copy-Item "$Engine\*" $stage -Recurse
} else {
    $tmp = Join-Path $root "out\release\engine-tmp"
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    Expand-Archive -Path $Engine -DestinationPath $tmp
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    $src = if ($inner -and (Test-Path "$($inner.FullName)\snes-port.exe")) { $inner.FullName } else { $tmp }
    Copy-Item "$src\*" $stage -Recurse
    Remove-Item -Recurse -Force $tmp
}
if (-not (Test-Path "$stage\snes-port.exe")) { Remove-Item -Recurse -Force $stage; throw "el motor no trae snes-port.exe" }

# quien solo quiere jugar no tiene compilador: el paquete lleva el del motor
if (-not $NoTcc -and -not (Test-Path "$stage\toolchain\tcc\tcc.exe")) {
    Remove-Item -Recurse -Force $stage
    throw "el motor no trae toolchain\tcc\tcc.exe: usa un zip del motor con TinyCC (release.ps1 del motor, sin -NoTcc) o pasa -NoTcc para armar un paquete que pide descargarlo"
}

# el juego: su README sustituye al del motor, y su licencia va junto a la del motor
if (Test-Path "$stage\README.md") { Move-Item "$stage\README.md" "$stage\README-engine.md" -Force }
if (Test-Path "$stage\LICENSE") { Move-Item "$stage\LICENSE" "$stage\LICENSE-engine" -Force }
Copy-Item README.md, LICENSE $stage
Copy-Item games $stage -Recurse

# la guarda: nada de ROMs, partidas guardadas ni C generado
$bad = Get-ChildItem $stage -Recurse -File | Where-Object {
    $_.Extension -in ".sfc", ".smc", ".srm", ".sst", ".fig", ".swc" -or
    $_.Name -like "rom_*.c" -or $_.Name -in "snes_entry.c", "snes_funcs.h", "snes_headless.c", "snes_play.c"
}
if ($bad) {
    $bad | ForEach-Object { Write-Error "prohibido en el paquete: $($_.FullName)" -ErrorAction Continue }
    Remove-Item -Recurse -Force $stage
    throw "el paquete llevaria ficheros de ROM o C generado: no se crea el zip"
}

$zip = Join-Path $root "out\release\$name.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $stage -DestinationPath $zip
Write-Host "creado $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MiB)"
