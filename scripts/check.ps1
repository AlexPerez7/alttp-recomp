# Comprueba que mantener R acelera los mensajes de A Link to the Past (gancho games/alttp_usa/dialog.c):
# genera el C con el motor, lo compila con el runtime sin vídeo y ejecuta el juego tres veces hasta el primer mensaje.
# El contador de caracteres ($1CD9 de la WRAM) a los 2040 fotogramas debe ser 5 sin R, al menos el doble (10) con R y 5 con R y
# --game-opt dialog_skip=0.
#
#   powershell -File scripts\check.ps1 [-Rom roms\alttp_usa.sfc] [-Engine ..\snes-recomp\target\release\snes-recomp.exe]
#
# Se omite con un aviso (código 0) si falta la ROM, el motor o un compilador de Visual Studio. Todo lo que genera va a
# out\ (ignorado por git): deriva de la ROM y no se sube.
param(
    [string]$Rom = "roms\alttp_usa.sfc",
    [string]$Engine = "..\snes-recomp\target\release\snes-recomp.exe",
    [string]$Vcvars = ""
)
$ErrorActionPreference = "Continue"   # los programas nativos escriben en stderr; se comprueba $LASTEXITCODE
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Skip($why) { Write-Warning "omitido: $why"; exit 0 }

if (-not (Test-Path $Rom)) { Skip "no hay ROM en $Rom" }
if (-not (Test-Path $Engine)) { Skip "no hay motor en $Engine (cargo build --release en snes-recomp)" }
if ($Vcvars -eq "") {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $inst = & $vswhere -latest -products * -property installationPath
        if ($inst) { $Vcvars = Join-Path $inst "VC\Auxiliary\Build\vcvars64.bat" }
    }
}
if ($Vcvars -eq "" -or -not (Test-Path $Vcvars)) { Skip "no se encuentra vcvars64.bat (Visual Studio Build Tools)" }

$out = Join-Path $root "out"
$gen = Join-Path $out "rom"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $gen | Out-Null

& $Engine codegen $Rom --all -o $gen --game games\alttp_usa.toml 2>$null
if ($LASTEXITCODE -ne 0) { throw "codegen fallo" }
if (-not (Test-Path "$gen\game\dialog.c")) { throw "el motor no copio el C del juego a out\rom\game" }

$bat = Join-Path $out "build.bat"
@"
call "$Vcvars" >nul 2>&1
cl /nologo /MP /TC /std:c11 /DSNES_RT_TICK /DSNES_RT_CHECKS /I"$gen" "$gen\*.c" "$gen\game\*.c" /Fe:"$out\headless.exe" /Fo:"$gen\\" >"$out\build.log" 2>&1
"@ | Set-Content -Encoding ascii $bat
cmd /c $bat
if ($LASTEXITCODE -ne 0) { Get-Content "$out\build.log" -Tail 30; throw "la compilacion fallo" }

# de la pantalla de título al primer mensaje del juego (fotograma 2028 en adelante)
$toMessage = @(
    "--press", "START@1100-1110", "--press", "A@1300-1305", "--press", "A@1500-1504", "--press", "DOWN@1540-1542",
    "--press", "DOWN@1560-1562", "--press", "DOWN@1580-1582", "--press", "RIGHT@1600-1602", "--press", "RIGHT@1620-1622",
    "--press", "A@1640-1643", "--press", "A@2000-2004"
)

function Chars($name, $extra) {
    $dump = Join-Path $out "dump_$name"
    New-Item -ItemType Directory -Force $dump | Out-Null
    & "$out\headless.exe" $Rom --frames 2040 --frame-blocks 20000 --dump $dump @toMessage @extra *>$null
    if ($LASTEXITCODE -ne 0) { throw "headless.exe termino con codigo $LASTEXITCODE ($name)" }
    $wram = [System.IO.File]::ReadAllBytes("$dump\wram.bin")
    if ($wram[0x10] -ne 0x0E) { throw "($name) el modulo de mensajes no esta en marcha: `$10 = $($wram[0x10])" }
    return [int]$wram[0x1CD9]
}

$plain = Chars "plain" @()
$fast = Chars "fast" @("--press", "R@2000-2300")
$off = Chars "off" @("--press", "R@2000-2300", "--game-opt", "dialog_skip=0")
Write-Host "caracteres a los 2040 fotogramas: sin R = $plain, con R = $fast, con R y dialog_skip=0 = $off"

$ok = $true
if ($plain -ne 5) { Write-Error "sin R deberian ser 5" -ErrorAction Continue; $ok = $false }
if ($fast -lt 2 * $plain) { Write-Error "con R deberian ser al menos el doble" -ErrorAction Continue; $ok = $false }
if ($off -ne $plain) { Write-Error "con dialog_skip=0, R no debe cambiar nada" -ErrorAction Continue; $ok = $false }
if (-not $ok) { exit 1 }
Write-Host "OK"
