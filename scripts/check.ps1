# Comprueba que mantener R acelera los mensajes de A Link to the Past (gancho games/alttp_usa/dialog.c):
# genera el C con el motor, lo compila con el runtime sin vídeo y ejecuta el juego tres veces hasta el primer mensaje.
# El contador de caracteres ($1CD9 de la WRAM) a los 2040 fotogramas debe ser 5 sin R, al menos el doble (10) con R y 5 con R y
# --game-opt dialog_skip=0. Después comprueba la pantalla ancha (games/alttp_usa/widefill.c): con --wide 32, en la casa de Link
# (interior) la captura mide 320 de ancho y las 32 columnas extra de cada lado son negras. Por último comprueba el texto de los
# mensajes (games/alttp_usa/text.c): el volcado tiene 397 mensajes, lang\es.txt igual al volcado da el mismo texto, cambiar una
# línea cambia solo ese mensaje y el primer cuadro de texto es idéntico con language=en y language=es.
# Por último comprueba las mejoras de games/alttp_usa/quality.c en una partida nueva (Link ya se maneja en su casa, fotograma 5200,
# y fuera de ella): max_yellow, low_hp_beep y dash_turn, mirando las escrituras en la WRAM.
#
#   powershell -File scripts\check.ps1 [-Rom roms\alttp_usa.sfc] [-Engine ruta\a\snes-recomp.exe]   (por defecto: el de play.bat)
#
# Se omite con un aviso (código 0) si falta la ROM, el motor o un compilador de Visual Studio. Todo lo que genera va a
# out\ (ignorado por git): deriva de la ROM y no se sube.
param(
    [string]$Rom = "roms\alttp_usa.sfc",
    [string]$Engine = "",
    [string]$Vcvars = ""
)
$ErrorActionPreference = "Continue"   # los programas nativos escriben en stderr; se comprueba $LASTEXITCODE
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Skip($why) { Write-Warning "omitido: $why"; exit 0 }

if (-not (Test-Path $Rom)) { Skip "no hay ROM en $Rom" }
if ($Engine -eq "") {
    # el mismo motor que usa play.bat: SNES_ENGINE, engine\ de este repositorio o, en su defecto, el compilado en ..\snes-recomp
    $cands = @()
    if ($env:SNES_ENGINE) { $cands += "$env:SNES_ENGINE\snes-recomp.exe" }
    $cands += "engine\snes-recomp.exe", "..\snes-recomp\target\release\snes-recomp.exe"
    $Engine = $cands | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Engine -or -not (Test-Path $Engine)) { Skip "no hay motor (ejecuta play.bat una vez para extraerlo a engine\, o define SNES_ENGINE)" }
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
New-Item -ItemType Directory -Force $gen, "$gen\fast" | Out-Null

& $Engine codegen $Rom --all -o $gen --game games\alttp_usa.toml 2>$null
if ($LASTEXITCODE -ne 0) { throw "codegen fallo" }
foreach ($f in "dialog.c", "widefill.c", "text.c", "menutext.c", "hud.c", "quality.c") {
    if (-not (Test-Path "$gen\game\$f")) { throw "el motor no copio $f a out\rom\game" }
}

# el segundo cl compila otro headless sin comprobaciones de anchura y optimizado, para las partidas largas de las mejoras de calidad
$bat = Join-Path $out "build.bat"
@"
call "$Vcvars" >nul 2>&1
cl /nologo /MP /TC /std:c11 /DSNES_RT_TICK /DSNES_RT_CHECKS /I"$gen" "$gen\*.c" "$gen\game\*.c" /Fe:"$out\headless.exe" /Fo:"$gen\\" >"$out\build.log" 2>&1
cl /nologo /MP /O2 /TC /std:c11 /DSNES_RT_TICK /I"$gen" "$gen\*.c" "$gen\game\*.c" /Fe:"$out\headless_fast.exe" /Fo:"$gen\fast\\" >"$out\build_fast.log" 2>&1
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

# pantalla ancha: interior (fotograma 2040, el primer mensaje transcurre dentro de la casa)
$shot = Join-Path $out "wide.png"
& "$out\headless.exe" $Rom --frames 2040 --frame-blocks 20000 --wide 32 --screenshot $shot @toMessage *>$null
if ($LASTEXITCODE -ne 0) { throw "headless.exe termino con codigo $LASTEXITCODE (wide)" }
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap $shot
$wideOk = ($bmp.Width -eq 320)
if ($wideOk) {
    foreach ($x in (0..31) + (288..319)) {
        foreach ($y in 40, 100, 160) {
            $px = $bmp.GetPixel($x, $y)
            if ($px.R -ne 0 -or $px.G -ne 0 -or $px.B -ne 0) { $wideOk = $false }
        }
    }
}
$bmp.Dispose()
Write-Host "pantalla ancha (interior, --wide 32): franjas negras = $wideOk"

# texto de los mensajes (games/alttp_usa/text.c): el volcado se escribe junto a la ROM, así que se trabaja con una copia en out\
$textRom = Join-Path $out "rom.sfc"
Copy-Item $Rom $textRom
$textDir = Join-Path $out "text"
New-Item -ItemType Directory -Force "$textDir\lang" | Out-Null
function DumpText($extra) {
    & "$out\headless.exe" $textRom --frames 2040 --frame-blocks 20000 --game-opt dump_text=1 @extra *>$null
    if ($LASTEXITCODE -ne 0) { throw "headless.exe termino con codigo $LASTEXITCODE (volcado de mensajes)" }
}
DumpText @()
$en = "$out\alttp_messages_en.txt"
$messages = (Select-String -Path $en -Pattern '^@\d+$').Count
$enHash = (Get-FileHash $en -Algorithm SHA256).Hash
$textOk = ($messages -eq 397 -and $enHash -eq "E202ED47B0473CA3CD090A85054EF3F939E03FDD65B1A539FE183306DCA929A1")
Write-Host "volcado de mensajes: $messages mensajes, huella correcta = $textOk"
# ida y vuelta: con lang\es.txt igual al volcado, el juego produce exactamente el mismo texto
Copy-Item $en "$textDir\lang\es.txt"
DumpText @("--game-opt", "language=es", "--game-dir", $textDir)
$roundTrip = ((Get-FileHash "$out\alttp_messages_es.txt" -Algorithm SHA256).Hash -eq $enHash)
Write-Host "ida y vuelta de es.txt = volcado: idéntica = $roundTrip"
# cambiar una línea cambia solo ese mensaje
$edited = (Get-Content $en -Raw).Replace("Save And Continue{75}", "Guardar y continuar{75}")
[System.IO.File]::WriteAllText("$textDir\lang\es.txt", $edited)
DumpText @("--game-opt", "language=es", "--game-dir", $textDir)
$diff = Compare-Object (Get-Content $en) (Get-Content "$out\alttp_messages_es.txt")
$editOk = ($diff.Count -eq 2 -and ($diff | Where-Object { $_.SideIndicator -eq "=>" }).InputObject -like "*Guardar y continuar*")
Write-Host "un mensaje cambiado cambia solo ese mensaje = $editOk"
# el primer cuadro de texto es idéntico con language=en y con language=es (es.txt = volcado): la pantalla y la WRAM
Copy-Item $en "$textDir\lang\es.txt"
function FirstBox($name, $extra) {
    $d = Join-Path $out "text_$name"
    New-Item -ItemType Directory -Force $d | Out-Null
    & "$out\headless.exe" $textRom --frames 2040 --frame-blocks 20000 --dump $d --screenshot "$d\shot.png" @toMessage @extra *>$null
    if ($LASTEXITCODE -ne 0) { throw "headless.exe termino con codigo $LASTEXITCODE ($name)" }
    return @((Get-FileHash "$d\shot.png").Hash, (Get-FileHash "$d\wram.bin").Hash)
}
$boxEn = FirstBox "en" @()
$boxEs = FirstBox "es" @("--game-opt", "language=es", "--game-opt", "hud_text=0", "--game-dir", $textDir)
$boxOk = (($boxEn -join ",") -eq ($boxEs -join ","))
Write-Host "primer cuadro de texto idéntico con language=en y language=es = $boxOk"

# texto de la selección de partida y del registro de nombre (games/alttp_usa/menutext.c)
function DumpMenu($extra) {
    & "$out\headless.exe" $textRom --frames 300 --frame-blocks 20000 --game-opt dump_menu=1 @extra *>$null
    if ($LASTEXITCODE -ne 0) { throw "headless.exe termino con codigo $LASTEXITCODE (volcado de menus)" }
}
DumpMenu @()
$menuEn = "$out\alttp_menu_en.txt"
$menuKeys = (Select-String -Path $menuEn -Pattern '^[a-z_.0-9]+ = ').Count
$menuOk = ($menuKeys -eq 23)
Write-Host "claves del volcado de menús: $menuKeys (23) = $menuOk"
$menuTxt = (Get-Content $menuEn -Raw)
[System.IO.File]::WriteAllText("$textDir\lang\es_menu.txt", $menuTxt)
DumpMenu @("--game-opt", "language=es", "--game-dir", $textDir)
$menuRound = ((Get-FileHash "$out\alttp_menu_es.txt" -Algorithm SHA256).Hash -eq (Get-FileHash $menuEn -Algorithm SHA256).Hash)
Write-Host "ida y vuelta de es_menu.txt = volcado: idéntica = $menuRound"
# capturas de las dos pantallas (selección de partida en el fotograma 1300, registro de nombre en el 1530)
$toMenus = @("--press", "START@1100-1110", "--press", "A@1300-1305", "--press", "A@1500-1504")
function MenuShot($name, $frames, $extra) {
    $d = Join-Path $out "menu_$name"
    New-Item -ItemType Directory -Force $d | Out-Null
    & "$out\headless.exe" $textRom --frames $frames --frame-blocks 20000 --dump $d --screenshot "$d\shot.png" @toMenus @extra *>$null
    if ($LASTEXITCODE -ne 0) { throw "headless.exe termino con codigo $LASTEXITCODE (menu $name)" }
    return $d
}
$es = @("--game-opt", "language=es", "--game-dir", $textDir)
$menuSame = $true
foreach ($s in @(@("sel", 1300), @("name", 1530))) {
    $a = MenuShot "$($s[0])_en" $s[1] @()
    $b = MenuShot "$($s[0])_es" $s[1] $es
    if ((Get-FileHash "$a\shot.png").Hash -ne (Get-FileHash "$b\shot.png").Hash) { $menuSame = $false }
}
Write-Host "pantallas de menú idénticas con language=en y language=es (es_menu.txt = volcado) = $menuSame"
# cambiar una cadena cambia solo su sitio: unos pocos bytes del mapa de BG3 (VRAM $C000-$CFFF)
[System.IO.File]::WriteAllText("$textDir\lang\es_menu.txt", $menuTxt.Replace("select.copy = COPY  PLAYER", "select.copy = COPIAR"))
$a = MenuShot "sel_en" 1300 @()
$b = MenuShot "sel_edit" 1300 $es
$va = [System.IO.File]::ReadAllBytes("$a\vram.bin"); $vb = [System.IO.File]::ReadAllBytes("$b\vram.bin")
$changed = @(0..($va.Length - 1) | Where-Object { $va[$_] -ne $vb[$_] })
$menuEdit = ($changed.Count -gt 0 -and $changed.Count -le 48 -and @($changed | Where-Object { $_ -lt 0xC000 -or $_ -ge 0xD000 }).Count -eq 0)
Write-Host "cambiar select.copy cambia $($changed.Count) bytes del mapa de BG3 (1 a 48) = $menuEdit"
# traducido todo, la partida es la misma: la WRAM (que lleva el nombre) a los 2040 fotogramas no cambia
$tr = $menuTxt.Replace("select.title = PLAYER  SELECT", "select.title = ELEGIR PARTIDA").Replace("name.title =  REGISTER  YOUR  NAME", "name.title = REGISTRA TU NOMBRE").Replace("name.end = END", "name.end = FIN")
[System.IO.File]::WriteAllText("$textDir\lang\es_menu.txt", $tr)
$a = Join-Path $out "menu_game_en"; $b = Join-Path $out "menu_game_es"
New-Item -ItemType Directory -Force $a, $b | Out-Null
& "$out\headless.exe" $textRom --frames 2040 --frame-blocks 20000 --dump $a @toMessage *>$null
& "$out\headless.exe" $textRom --frames 2040 --frame-blocks 20000 --dump $b @toMessage @es *>$null
$menuGame = ((Get-FileHash "$a\wram.bin").Hash -eq (Get-FileHash "$b\wram.bin").Hash)
Write-Host "la WRAM del juego no cambia con los menús traducidos = $menuGame"

# mejoras de calidad (games/alttp_usa/quality.c): partida nueva hasta que Link se maneja en su casa (fotograma 5200) y, con las
# escrituras en la WRAM, comprobar cada opción. Con --trace-frames y --watch el motor lista cada cambio de una dirección.
$toControl = @($toMessage)
for ($f = 2100; $f -lt 5200; $f += 50) { $toControl += @("--press", "A@$f-$($f+3)") }
function Play($name, $frames, $extra) {
    $d = Join-Path $out "q_$name"
    New-Item -ItemType Directory -Force $d | Out-Null
    $log = & "$out\headless_fast.exe" $textRom --frames $frames --frame-blocks 20000 --dump $d @toControl @extra 2>&1
    if ($LASTEXITCODE -ne 0) { throw "headless.exe termino con codigo $LASTEXITCODE ($name)" }
    return @{ wram = [System.IO.File]::ReadAllBytes("$d\wram.bin"); log = $log }
}
function Writes($log) {
    foreach ($l in $log) {
        if ("$l" -match 'frame (\d+) block \S+ wram ([0-9A-F]+): ([0-9A-F]{2}) -> ([0-9A-F]{2})') {
            [pscustomobject]@{ Frame = [int]$Matches[1]; Addr = [Convert]::ToInt32($Matches[2], 16); Old = $Matches[3]; New = $Matches[4] }
        }
    }
}

# max_yellow: los dígitos de un contador al máximo pasan de la paleta 1 a la 5 (bits 10-12 de la baldosa del marcador, en $C750...)
function Pal($w, $from, $n) { @(0..($n - 1) | ForEach-Object { ($w[$from + 2 * $_ + 1] -band 0x1C) -shr 2 }) -join "," }
function Counters($w) { @((Pal $w 0xC750 3), (Pal $w 0xC758 2), (Pal $w 0xC75E 2)) -join " " }
$allMax = @("--poke", "0F360=E703E703@5250", "--poke", "0F343=0A@5250", "--poke", "0F377=1E@5250")
$someMax = @("--poke", "0F360=F401F401@5250", "--poke", "0F343=0A@5250", "--poke", "0F377=1E@5250")
$yOff = Counters (Play "y_off" 5400 ($allMax + @("--game-opt", "max_yellow=0"))).wram
$yOn = Counters (Play "y_on" 5400 ($allMax + @("--game-opt", "max_yellow=1"))).wram
$yPart = Counters (Play "y_part" 5400 ($someMax + @("--game-opt", "max_yellow=1"))).wram
$yellowOk = ($yOff -eq "1,1,1 1,1 1,1" -and $yOn -eq "5,5,5 5,5 5,5" -and $yPart -eq "1,1,1 5,5 5,5")
Write-Host "max_yellow: paletas (rupias bombas flechas) apagado = $yOff, activo = $yOn, con 500 rupias = $yPart -> $yellowOk"

# low_hp_beep: con un corazón ($F36D = 8) el juego escribe el efecto $2B en $012E cada 32 fotogramas. Con la opción en 1 queda
# hasta el fotograma siguiente (el motor de sonido lo consume); en 0 se borra en el mismo fotograma. Con la vida llena, nada.
function Beep($name, $beep, $low) {
    $extra = @("--watch", "012E", "--trace-frames", "5260-5400", "--game-opt", "low_hp_beep=$beep")
    if ($low) { $extra += @("--poke", "0F36D=08@5250") }
    return @(Writes (Play $name 5400 $extra).log | Where-Object { $_.Addr -eq 0x12E })
}
$bOn = Beep "b_on" 1 $true
$bOff = Beep "b_off" 0 $true
$bFull = Beep "b_full" 1 $false
$setOn = @($bOn | Where-Object { $_.New -eq "2B" }); $clrOn = @($bOn | Where-Object { $_.Old -eq "2B" })
$setOff = @($bOff | Where-Object { $_.New -eq "2B" }); $clrOff = @($bOff | Where-Object { $_.Old -eq "2B" })
$beepOn = ($setOn.Count -ge 4 -and $setOn.Count -eq $clrOn.Count -and @(0..($setOn.Count - 1) | Where-Object { $clrOn[$_].Frame -le $setOn[$_].Frame }).Count -eq 0)
$beepOff = ($setOff.Count -eq $setOn.Count -and $clrOff.Count -eq $setOff.Count -and @(0..($setOff.Count - 1) | Where-Object { $clrOff[$_].Frame -ne $setOff[$_].Frame }).Count -eq 0)
$beepFull = ($bFull.Count -eq 0)
$beepOthers = (@($bOn | Where-Object { $_.New -ne "2B" -and $_.Old -ne "2B" }).Count -eq @($bOff | Where-Object { $_.New -ne "2B" -and $_.Old -ne "2B" }).Count)
Write-Host "low_hp_beep: con poca vida el `$2B se pide $($setOn.Count) veces y dura un fotograma = $beepOn; con la opción en 0 se borra en el mismo fotograma = $beepOff; con la vida llena no hay nada = $beepFull; los demás efectos no cambian = $beepOthers"

# dash_turn: con las botas ($F355 y la habilidad $F379) se corre con A. Mientras se corre a la derecha se pulsa arriba (fotograma
# 6031): sin la opción la carrera termina ($5D deja de valer $11) en ese fotograma; con ella Link gira ($2F pasa a 0, arriba) y la
# carrera sigue hasta chocar con la pared unos fotogramas después.
function Dash($opt) {
    $extra = @("--poke", "0F355=01@5250", "--poke", "0F379=FF@5250", "--watch", "05D", "--watch", "02F", "--trace-frames", "5950-6150",
        "--press", "A@5900-5904", "--press", "A+RIGHT@6000-6030", "--press", "A+UP@6031-6062", "--game-opt", "dash_turn=$opt")
    return @(Writes (Play "dash$opt" 6150 $extra).log)
}
$d0 = Dash 0
$d1 = Dash 1
$run0 = $d0 | Where-Object { $_.Addr -eq 0x5D -and $_.New -eq "11" } | Select-Object -First 1
$end0 = $d0 | Where-Object { $_.Addr -eq 0x5D -and $_.Old -eq "11" } | Select-Object -First 1
$end1 = $d1 | Where-Object { $_.Addr -eq 0x5D -and $_.Old -eq "11" } | Select-Object -First 1
$turn1 = $d1 | Where-Object { $_.Addr -eq 0x2F } | Select-Object -First 1
$dashOk = ($null -ne $run0 -and $null -ne $end0 -and $null -ne $end1 -and $null -ne $turn1 -and $end0.Frame -le 6033 -and $turn1.New -eq "00" -and $turn1.Frame -le 6033 -and $end1.Frame -ge $turn1.Frame + 3)
Write-Host "dash_turn: la carrera empieza en el fotograma $($run0.Frame); sin la opción acaba en el $($end0.Frame); con ella Link gira en el $($turn1.Frame) y la carrera acaba en el $($end1.Frame) -> $dashOk"

$ok = $true
if (-not $textOk) { Write-Error "el volcado debe tener 397 mensajes y la huella de siempre" -ErrorAction Continue; $ok = $false }
if (-not $roundTrip) { Write-Error "con es.txt igual al volcado, el texto debe salir idéntico" -ErrorAction Continue; $ok = $false }
if (-not $editOk) { Write-Error "cambiar una línea de es.txt debe cambiar solo ese mensaje" -ErrorAction Continue; $ok = $false }
if (-not $boxOk) { Write-Error "el primer cuadro de texto debe ser idéntico con language=en y language=es" -ErrorAction Continue; $ok = $false }
if (-not $menuOk) { Write-Error "el volcado de menús debe tener 15 claves" -ErrorAction Continue; $ok = $false }
if (-not $menuRound) { Write-Error "con es_menu.txt igual al volcado, el texto de los menús debe salir idéntico" -ErrorAction Continue; $ok = $false }
if (-not $menuSame) { Write-Error "las pantallas de menú deben ser idénticas con language=en y language=es (es_menu.txt = volcado)" -ErrorAction Continue; $ok = $false }
if (-not $menuEdit) { Write-Error "cambiar una cadena de menú debe cambiar solo su sitio en el mapa de BG3" -ErrorAction Continue; $ok = $false }
if (-not $menuGame) { Write-Error "traducir los menús no debe cambiar el estado de la partida" -ErrorAction Continue; $ok = $false }
if (-not $wideOk) { Write-Error "con --wide 32 en un interior las columnas extra deben ser negras (320 de ancho)" -ErrorAction Continue; $ok = $false }
if ($plain -ne 5) { Write-Error "sin R deberian ser 5" -ErrorAction Continue; $ok = $false }
if ($fast -lt 2 * $plain) { Write-Error "con R deberian ser al menos el doble" -ErrorAction Continue; $ok = $false }
if ($off -ne $plain) { Write-Error "con dialog_skip=0, R no debe cambiar nada" -ErrorAction Continue; $ok = $false }
if (-not $yellowOk) { Write-Error "max_yellow=1 debe pasar a la paleta 5 solo los contadores al máximo, y =0 no debe cambiar nada" -ErrorAction Continue; $ok = $false }
if (-not $beepOn) { Write-Error "con poca vida y low_hp_beep=1 el efecto `$2B debe pedirse y quedar un fotograma (como siempre)" -ErrorAction Continue; $ok = $false }
if (-not $beepOff) { Write-Error "con low_hp_beep=0 el efecto `$2B debe borrarse en el mismo fotograma en que se pide" -ErrorAction Continue; $ok = $false }
if (-not $beepFull) { Write-Error "con la vida llena no debe haber ningún `$2B" -ErrorAction Continue; $ok = $false }
if (-not $beepOthers) { Write-Error "low_hp_beep no debe tocar los demás efectos de sonido" -ErrorAction Continue; $ok = $false }
if (-not $dashOk) { Write-Error "con dash_turn=1 pulsar otra dirección en plena carrera debe girar a Link sin cortarla (y sin la opción la corta)" -ErrorAction Continue; $ok = $false }
if (-not $ok) { exit 1 }
Write-Host "OK"
