# ---------------------------------------------------------------------------
# helper.ps1 - proceso auxiliar del plugin WoW Deck
#
# lib/helper.js lo arranca una vez y lo mantiene abierto. Se comunican por
# líneas de texto en UTF-8: una orden por línea en la entrada estándar y una
# respuesta por línea en la salida. Al arrancar escribe "READY"; después, una
# respuesta por orden: "OK <orden>" o "ERR <motivo>".
#
#   KEYS 17,18,16,112             Pulsa las teclas (códigos VK de Windows) en ese
#                                 orden y las suelta en orden inverso:
#                                 Ctrl+Alt+Mayús+F1. Los modificadores que el
#                                 jugador ya mantenga pulsados con la mano no se tocan.
#   DIM <entrada>|<salida>|<lado> Guarda una copia gris y oscurecida de una
#                                 imagen, de <lado> x <lado> píxeles (para huecos
#                                 que el personaje aún no tiene).
#
# Por qué PowerShell y no Node: simular teclado necesita llamar a user32.dll.
# Desde Node habría que usar un módulo nativo compilado para cada versión;
# PowerShell viene con Windows y puede compilar un poco de C# al vuelo.
# ---------------------------------------------------------------------------

# Cualquier error, también los "no terminantes" de los cmdlets, debe llegar al
# catch del bucle y responderse como ERR, nunca como un OK falso.
$ErrorActionPreference = 'Stop'

# Node escribe y lee en UTF-8. Windows PowerShell 5.1 usaría por defecto la
# página de códigos de la consola (850 en un Windows en español) y rompería las
# rutas con tildes (C:\Users\José\...).
$Utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::InputEncoding = $Utf8
[Console]::OutputEncoding = $Utf8

# --- Constantes -------------------------------------------------------------
$KeyHoldMs = 30                 # cuánto se mantiene pulsada la tecla
$DimFactor = 0.4                # brillo de los iconos atenuados
$Luminance = @(0.3, 0.6, 0.1)   # peso de R, G y B al pasar a gris

# --- Teclado ----------------------------------------------------------------
# La clase en C# que genera las pulsaciones está en native\WowDeckKeys.cs.
# Add-Type la compila en memoria al arrancar (tarda ~1 s, por eso el proceso
# se mantiene vivo en lugar de lanzarse en cada pulsación).
Add-Type -TypeDefinition (Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'native\WowDeckKeys.cs'))

function Invoke-Keys([string]$arg) {
    [WowDeckKeys]::Press([byte[]]($arg -split ','), $KeyHoldMs)
}

# --- Imágenes ---------------------------------------------------------------
Add-Type -AssemblyName System.Drawing

# Matriz de color que pasa a gris y oscurece: cada canal de salida es la misma
# mezcla ponderada de R, G y B, multiplicada por $DimFactor.
function New-DimMatrix {
    $m = New-Object System.Drawing.Imaging.ColorMatrix
    for ($row = 0; $row -lt 3; $row++) {
        for ($col = 0; $col -lt 3; $col++) { $m.Item($row, $col) = $Luminance[$row] * $DimFactor }
    }
    return $m
}

# Libera los objetos GDI que existan. Hay que hacerlo explícitamente: si no, el
# archivo de entrada queda bloqueado hasta que actúe el recolector de basura.
function Close-Graphics([object[]]$objects) {
    foreach ($o in $objects) { if ($o) { $o.Dispose() } }
}

function Invoke-Dim([string]$arg) {
    # Las rutas se separan con "|" porque pueden contener espacios.
    $in, $out, $size = $arg -split '\|'
    $size = [int]$size
    $src = $null; $bmp = $null; $g = $null; $attr = $null
    try {
        $src = [System.Drawing.Image]::FromFile($in)
        $bmp = New-Object System.Drawing.Bitmap $size, $size
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $attr = New-Object System.Drawing.Imaging.ImageAttributes
        $attr.SetColorMatrix((New-DimMatrix))
        $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $size, $size), 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $attr)
        Close-Graphics @($g, $src); $g = $null; $src = $null
        $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        Close-Graphics @($g, $src, $bmp, $attr)
    }
}

# --- Bucle de órdenes -------------------------------------------------------
# Tabla orden -> función. Añadir una orden nueva es añadir una línea.
$Commands = @{
    'KEYS' = ${function:Invoke-Keys}
    'DIM'  = ${function:Invoke-Dim}
}

function Invoke-Line([string]$line) {
    $name, $arg = $line -split ' ', 2
    $handler = $Commands[$name]
    if (-not $handler) { return "ERR orden desconocida" }
    # Out-Null descarta cualquier salida de la función: la única línea que debe
    # llegar al plugin es la respuesta.
    & $handler $arg | Out-Null
    return "OK $name"
}

# Señal para el plugin de que la compilación ha terminado y ya acepta órdenes.
[Console]::Out.WriteLine("READY")

# ReadLine devuelve $null cuando se cierra la entrada estándar, es decir,
# cuando el plugin termina: entonces salimos también.
while (($line = [Console]::In.ReadLine()) -ne $null) {
    try {
        [Console]::Out.WriteLine((Invoke-Line $line))
    } catch {
        # Siempre una respuesta por orden, también si falla, para que la cola
        # de respuestas del plugin no se desincronice. Sin saltos de línea: el
        # plugin lee línea a línea.
        [Console]::Out.WriteLine("ERR " + ($_.Exception.Message -replace '\s+', ' '))
    }
}
