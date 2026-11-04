"""
Constantes del icono del proyecto: colores, medidas y archivos de salida.

El icono se dibuja una vez a tamaño grande (MASTER_SIZE) y se reduce a cada
tamaño de destino: reducir una imagen grande da bordes más suaves que dibujar
directamente a tamaño pequeño.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON_DIR = os.path.normpath(os.path.join(HERE, "..", ".."))
PLUGIN_DIR = os.path.join(ADDON_DIR, "StreamDeck", "com.fsegado.wowdeck.sdPlugin")

MASTER_SIZE = 512

# --- Paleta -----------------------------------------------------------------
BG_TOP = (31, 46, 84)          # azul arcano
BG_BOTTOM = (9, 14, 30)        # casi negro
GOLD_DARK = (150, 104, 30)
GOLD = (222, 172, 64)
GOLD_LIGHT = (255, 232, 160)
KEY_TOP = (52, 66, 98)
KEY_BOTTOM = (26, 34, 54)
KEY_EDGE = (84, 102, 140)
GLOW_GOLD = (255, 190, 60)
GLOW_GOLD_CORE = (255, 236, 150)
GLOW_ARCANE = (90, 190, 255)
GLOW_ARCANE_CORE = (200, 240, 255)
GLYPH = (80, 40, 8)
WHITE = (255, 255, 255)

# --- Medidas (sobre MASTER_SIZE) ---------------------------------------------
CORNER_RADIUS = 104
FRAME_WIDTH = 20
FRAME_HIGHLIGHT_WIDTH = 5
FRAME_HIGHLIGHT_ALPHA = 200     # opacidad del filo claro del marco (0-255)
GRID_COLUMNS, GRID_ROWS = 3, 2
KEY_SIZE = 104
KEY_GAP = 24
KEY_RADIUS = 20
GLOW_BLUR = 22

# Teclas encendidas: (columna, fila) -> (color del brillo, color del centro, ¿símbolo?)
LIT_KEYS = {
    (1, 0): (GLOW_GOLD, GLOW_GOLD_CORE, True),
    (0, 1): (GLOW_ARCANE, GLOW_ARCANE_CORE, False),
}

# --- Archivos de salida -----------------------------------------------------
# (ruta, tamaño, tipo) ; tipo: "color" (icono completo) o "mono" (silueta blanca,
# como pide Stream Deck para la lista de acciones y categorías).
OUTPUTS = [
    (os.path.join(ADDON_DIR, "Media", "Icon.tga"), 64, "color"),        # lista de addons y chat del juego
    (os.path.join(PLUGIN_DIR, "imgs", "plugin.png"), 256, "color"),     # icono del plugin
    (os.path.join(PLUGIN_DIR, "imgs", "plugin@2x.png"), 512, "color"),
    (os.path.join(PLUGIN_DIR, "imgs", "key.png"), 72, "color"),         # tecla antes de tener datos
    (os.path.join(PLUGIN_DIR, "imgs", "key@2x.png"), 144, "color"),
    (os.path.join(PLUGIN_DIR, "imgs", "action.png"), 20, "mono"),       # lista de acciones
    (os.path.join(PLUGIN_DIR, "imgs", "action@2x.png"), 40, "mono"),
    (os.path.join(PLUGIN_DIR, "imgs", "category.png"), 28, "mono"),     # categoría en la lista
    (os.path.join(PLUGIN_DIR, "imgs", "category@2x.png"), 56, "mono"),
]
