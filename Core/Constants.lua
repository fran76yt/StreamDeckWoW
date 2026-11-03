--[[
Constantes
==========

Todos los valores fijos del addon en un único sitio. Si algo puede cambiar
(número de huecos, atajos, tiempos, colores, medidas de la ventana), se cambia
aquí y el resto del código lo recoge.

Sobre "local _, ns = ...":
WoW ejecuta cada archivo del addon pasándole dos valores: el nombre del addon
y una tabla privada que comparten todos sus archivos. Usamos esa tabla (ns,
"namespace") para repartir el código en módulos sin crear variables globales,
que podrían chocar con otros addons.
]]

local addonName, ns = ...

-- Exponemos el namespace como global solo para poder inspeccionarlo en el
-- juego mientras se desarrolla: /dump StreamDeckWoW.Const
_G.StreamDeckWoW = ns

local Const = {}
ns.Const = Const

-- Nombre del addon (el de su carpeta) e icono propio (Media\Icon.tga, sin extensión).
Const.ADDON_NAME = addonName
Const.ICON = "Interface\\AddOns\\" .. addonName .. "\\Media\\Icon"

-- Número de huecos: uno por tecla F1..F12.
Const.NUM_SLOTS = 12

-- Modificadores de los atajos. Nadie los teclea a mano (los pulsa la Stream
-- Deck), así que usamos los tres a la vez: prácticamente ningún programa ni el
-- propio juego usan esta combinación. Con Ctrl pulsado, Windows no trata Alt+F4
-- como "cerrar ventana", así que el hueco 4 es seguro.
-- Si se cambian, hay que cambiar también MODIFIERS en el plugin (constants.js).
Const.KEY_MODIFIERS = "ALT-CTRL-SHIFT-"          -- formato de WoW (orden fijo: ALT-CTRL-SHIFT)
Const.KEY_MODIFIERS_LABEL = "Ctrl+Alt+Mayús+"    -- versión legible para el jugador

-- Eventos de WoW tras los que hay que recalcular los huecos, y el retardo con
-- el que se agrupan (llegan en ráfagas de decenas al lootear o aprender).
Const.REFRESH_EVENTS = { "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "UPDATE_MACROS" }
Const.REFRESH_DELAY = 0.5

-- Mensajes internos entre módulos (no son eventos de WoW).
Const.MSG = {
    SLOT_CHANGED = "SLOT_CHANGED",     -- el jugador cambió un hueco en la ventana
    SLOTS_UPDATED = "SLOTS_UPDATED",   -- se han recalculado y asignado los huecos
}

-- Chat: prefijo de los mensajes (icono + nombre) y colores (hexadecimal RRGGBB).
-- |T ruta:alto:ancho|t inserta una imagen en el texto del chat.
Const.CHAT_PREFIX = "|T" .. Const.ICON .. ":14:14|t |cff33ff99StreamDeck WoW|r"
Const.CHAT_COLOR = {
    MISSING = "ff6060",   -- hueco que todavía no tienes
    EMPTY = "888888",     -- hueco vacío
}

-- Icono de interrogación del juego, para huecos sin icono conocido.
Const.ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Ventana de configuración.
Const.UI = {
    FRAME_NAME = "StreamDeckWoWConfig",   -- nombre global (necesario para cerrar con Escape)
    TITLE = "StreamDeck WoW",
    TITLE_ICON_SIZE = 16,
    HEIGHT = 230,
    PADDING = 20,
    SLOT_SIZE = 44,
    SLOT_GAP = 14,
    SLOT_ROW_GAP = 42,     -- espacio vertical extra para el nombre bajo cada hueco
    SLOTS_TOP = -48,
    COLUMNS = 6,
    -- Color del nombre del hueco (RGB 0-1): dorado si es personalizado.
    NAME_COLOR_CUSTOM = { 1, 0.82, 0 },
    NAME_COLOR_DEFAULT = { 0.85, 0.85, 0.85 },
    HIGHLIGHT_TEXTURE = "Interface\\Buttons\\ButtonHilight-Square",
}
