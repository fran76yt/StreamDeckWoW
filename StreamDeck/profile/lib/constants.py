"""
Constantes del formato de perfiles de Stream Deck y de las imágenes.
"""
import json
import os

# El manifest.json del plugin es la única fuente de su nombre, UUID y versión.
_PLUGIN_MANIFEST = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "..", "com.fsegado.wowdeck.sdPlugin", "manifest.json")
with open(_PLUGIN_MANIFEST, encoding="utf-8") as _fh:
    _plugin = json.load(_fh)

# --- Equipo -----------------------------------------------------------------
# Perfiles de la aplicación de Stream Deck (formato V3, desde Stream Deck 7.6).
# Se usan para detectar el dispositivo y los perfiles de destino, y es donde se
# instala el perfil generado.
STREAMDECK_PROFILES_DIR = os.path.join(os.environ.get("APPDATA", ""), "Elgato", "StreamDeck", "ProfilesV3")

# Dónde buscar WoW: mismas unidades y carpetas que el plugin (lib/constants.js).
WOW_DRIVES = "CDEFGH"
WOW_INSTALL_BASES = ["Program Files (x86)", "Program Files", "Juegos", "Games", ""]

# Tamaño de imagen de tecla a doble resolución.
IMAGE_SIZE = 144

# Distribución de la Stream Deck +: 4 columnas x 2 filas de teclas y 4 diales.
KEY_COLUMNS = 4
DIAL_COUNT = 4

# Versión del formato del manifiesto raíz (V3: Stream Deck 7.6 o posterior).
PROFILE_VERSION = "3.0"

# --- Códigos de tecla -------------------------------------------------------
# La acción "Hotkey" de Elgato guarda cada atajo con dos numeraciones:
#   VK  código de tecla virtual de Windows (VK_*)
#   Qt  el mismo código en la numeración de Qt (la aplicación está hecha con
#       Qt). Para letras y números coincide con el VK; para las especiales no.
VK = {
    "TAB": 9, "PAGE_UP": 33, "PAGE_DOWN": 34,
    "0": 48, "1": 49, "2": 50, "3": 51, "8": 56, "9": 57,
    "B": 66, "F": 70, "M": 77, "X": 88,
}
QT = {
    "TAB": 0x01000001, "PAGE_UP": 0x01000016, "PAGE_DOWN": 0x01000017,
}

# Máscara de modificadores: 1 = Mayús, 2 = Ctrl (3 = ambos).
MOD_SHIFT = 1
MOD_CTRL = 2

# Atajo vacío (relleno). Una acción Hotkey siempre tiene 4: en una tecla solo
# se usa el primero; en un dial son girar izquierda, girar derecha, pulsar y tocar.
HOTKEY_SLOTS = 4
EMPTY_HOTKEY = {"KeyCmd": False, "KeyCtrl": False, "KeyModifiers": 0, "KeyOption": False,
                "KeyShift": False, "NativeCode": 146, "QTKeyCode": 33554431, "VKeyCode": -1}

# --- Acciones ---------------------------------------------------------------
HOTKEY_PLUGIN = {"Name": "Activate a Key Command", "UUID": "com.elgato.streamdeck.system.hotkey", "Version": "1.0"}
PAGES_PLUGIN = {"Name": "Pages", "UUID": "com.elgato.streamdeck.page", "Version": "1.0"}
PROFILE_PLUGIN = {"Name": "Switch Profile", "UUID": "com.elgato.streamdeck.profile.rotate", "Version": "1.0"}
WOWDECK_PLUGIN = {"Name": _plugin["Name"], "UUID": _plugin["UUID"], "Version": _plugin["Version"]}
WOWDECK_SLOT_ACTION = _plugin["Actions"][0]["UUID"]

# Estilo de los títulos.
TITLE_STYLE = {"FontFamily": "", "FontStyle": "Bold", "FontUnderline": False, "OutlineThickness": 2,
               "ShowTitle": True, "TitleAlignment": "bottom", "TitleColor": "#ffffff"}
# Tamaños en la escala del formato V3 (al migrar desde V2, la aplicación
# multiplica por 4/3: 9 -> 12 en teclas y 12 -> 16 en diales).
KEY_FONT_SIZE = 12
DIAL_FONT_SIZE = 16

# --- Colores de las imágenes generadas --------------------------------------
REST_BACKGROUND = (28, 28, 34)
REST_FOREGROUND = (235, 235, 240)
ARROW_BACKGROUND = (20, 20, 20)
ARROW_FOREGROUND = (235, 235, 235)
FONTS = ("segoeuib.ttf", "arialbd.ttf")
