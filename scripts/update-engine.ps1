# Pone en la raíz de este repositorio el motor (snes-port.exe, snes-recomp.exe, sdl2\, toolchain\ con TinyCC): son los ficheros que
# se suben, para que el juego no dependa del repositorio del motor. snes-port.exe junto a games\ abre el lanzador con doble clic.
#
#   powershell -File scripts\update-engine.ps1 [-Zip <zip del motor>]
#
# Sin -Zip usa el más reciente de ..\snes-recomp\out\release\ (lo genera scripts\release.ps1 del motor). El README y la licencia del
# motor quedan como README-engine.md y LICENSE-engine, como en el paquete. Después: scan, commit y push como cualquier cambio.
param([string]$Zip = "")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if ($Zip -eq "") {
    $found = Get-ChildItem "..\snes-recomp\out\release\snes-port-*-win64.zip" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($found) { $Zip = $found.FullName }
}
if ($Zip -eq "" -or -not (Test-Path $Zip)) { throw "no hay zip del motor: pasa -Zip o genera uno con scripts\release.ps1 del motor" }

$tmp = Join-Path $root "engine.tmp"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
Expand-Archive -Path $Zip -DestinationPath $tmp
$inner = Get-ChildItem $tmp -Directory | Where-Object { Test-Path "$($_.FullName)\snes-port.exe" } | Select-Object -First 1
$src = if ($inner) { $inner.FullName } else { $tmp }
if (-not (Test-Path "$src\snes-port.exe")) { Remove-Item -Recurse -Force $tmp; throw "el zip no trae snes-port.exe" }
if (-not (Test-Path "$src\toolchain\tcc\tcc.exe")) { Remove-Item -Recurse -Force $tmp; throw "el zip no trae toolchain\tcc\tcc.exe (¿se hizo con -NoTcc?)" }

foreach ($old in "sdl2", "toolchain") { if (Test-Path $old) { Remove-Item -Recurse -Force $old } }
Copy-Item "$src\snes-port.exe", "$src\snes-recomp.exe" $root -Force
Copy-Item "$src\sdl2", "$src\toolchain" $root -Recurse -Force
if (Test-Path "$src\README.md") { Copy-Item "$src\README.md" "$root\README-engine.md" -Force }
if (Test-Path "$src\LICENSE") { Copy-Item "$src\LICENSE" "$root\LICENSE-engine" -Force }
Remove-Item -Recurse -Force $tmp
Write-Host "motor actualizado desde $Zip"
