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

-- Número de huecos: uno por tecla F1..F12. También aparece en el plugin
-- (NUM_SLOTS en bin/lib/constants.js y en ui/slot.html, y como texto en el
-- Tooltip de manifest.json), en la descripción (## Notes) del .toc y en el
-- layout del perfil (StreamDeck/profile/layouts), que coloca los huecos 1 a 12.
Const.NUM_SLOTS = 12

-- Modificadores de los atajos. Nadie los teclea a mano (los pulsa la Stream
-- Deck), así que usamos los tres a la vez: prácticamente ningún programa ni el
-- propio juego usan esta combinación. Con Ctrl pulsado, Windows no trata Alt+F4
-- como "cerrar ventana", así que el hueco 4 es seguro.
-- Si se cambian, hay que cambiar también, en el plugin, MODIFIERS en
-- bin/lib/constants.js, el texto de ui/slot.html y el Tooltip de manifest.json,
-- y la descripción (## Notes) del .toc.
Const.KEY_MODIFIERS = "ALT-CTRL-SHIFT-"          -- formato de WoW (orden fijo: ALT-CTRL-SHIFT)
Const.KEY_MODIFIERS_LABEL = "Ctrl+Alt+Mayús+"    -- versión legible para el jugador

-- Eventos de WoW tras los que hay que recalcular los huecos, y el retardo con
-- el que se agrupan (llegan en ráfagas de decenas al lootear o aprender). La
-- actualización se ejecuta ese tiempo después del primer evento de la ráfaga.
Const.REFRESH_EVENTS = { "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "UPDATE_MACROS" }
Const.REFRESH_DELAY = 0.5

-- Llega cuando el servidor envía los datos de un objeto que el cliente no
-- tenía en caché (su nombre e icono). Se trata aparte: llega también por
-- cualquier objeto que cargue el cliente, y solo interesan los que pidió el addon.
Const.ITEM_INFO_EVENT = "GET_ITEM_INFO_RECEIVED"

-- Mensajes internos entre módulos (no son eventos de WoW).
Const.MSG = {
    SLOT_CHANGED = "SLOT_CHANGED",     -- el jugador cambió un hueco en la ventana
    SLOTS_UPDATED = "SLOTS_UPDATED",   -- se han recalculado y asignado los huecos
    SETTINGS_CHANGED = "SETTINGS_CHANGED",   -- ha cambiado una opción (aviso del taunt...)
}

-- Chat: prefijo de los mensajes (icono + nombre).
-- |T ruta:alto:ancho|t inserta una imagen en el texto del chat.
Const.CHAT_PREFIX = "|T" .. Const.ICON .. ":14:14|t |cff33ff99StreamDeck WoW|r"

-- Colores de texto (hexadecimal RRGGBB, para Util.Colorize), en el chat y en
-- la ventana.
Const.COLOR = {
    MISSING = "ff6060",   -- hueco que todavía no tienes
    EMPTY = "888888",     -- hueco vacío
    DIM = "888888",       -- texto secundario (versión en el título de la ventana)
}

-- Icono de interrogación del juego, para huecos sin icono conocido.
Const.ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Ventana de configuración.
Const.UI = {
    FRAME_NAME = "StreamDeckWoWConfig",   -- nombre global (necesario para cerrar con Escape)
    TITLE = "StreamDeck WoW",
    TITLE_ICON_SIZE = 16,
    TITLE_ICON_GAP = 4,     -- separación entre el icono y el texto del título
    HEIGHT = 230,
    PADDING = 20,
    SLOT_SIZE = 44,
    SLOT_GAP = 14,
    SLOT_ROW_GAP = 42,     -- espacio vertical extra para el nombre bajo cada hueco
    SLOTS_TOP = -48,
    COLUMNS = 6,
    -- Color del nombre del hueco (RGB 0-1): dorado si es personalizado y gris
    -- claro si es el valor por defecto.
    NAME_COLOR_CUSTOM = { 1, 0.82, 0 },
    NAME_COLOR_DEFAULT = { 0.85, 0.85, 0.85 },
    HIGHLIGHT_TEXTURE = "Interface\\Buttons\\ButtonHilight-Square",
    SLOT_BACKGROUND_ALPHA = 0.6,   -- fondo oscuro de cada hueco
    KEY_LABEL_OFFSET = 2,          -- separación del texto "Fn" sobre el hueco
    NAME_OFFSET = -3,              -- separación del nombre bajo el hueco
    HELP_BOTTOM = 44,              -- altura del texto de ayuda desde abajo
    -- Páginas de opciones (secciones de clase): filas de arriba abajo.
    PAGE_TOP = -36,                -- primera fila, bajo la barra de título
    ROW_HEIGHT = 26,
    CHECK_SIZE = 24,
    CHECK_LABEL_GAP = 2,           -- separación entre la casilla y su texto
    CHECK_COLUMN_WIDTH = 110,      -- ancho de cada casilla en las filas de varias
    CHECKS_PER_ROW = 3,
    CHECK_ICON_SIZE = 16,          -- icono delante del texto de una casilla
    -- Cajas numéricas, en columnas: x de la izquierda de cada columna.
    NUMBER_BOX_WIDTH = 44,
    NUMBER_BOX_HEIGHT = 20,
    NUMBER_MAX_DIGITS = 4,
    NUMBER_COLUMNS = { 190, 290 },
    RELOAD_BUTTON_WIDTH = 200,
    RELOAD_BUTTON_HEIGHT = 24,
    RELOAD_BUTTON_BOTTOM = 14,
    -- Barra lateral de navegación (UI/Sidebar.lua), a la izquierda de la
    -- ventana, bajo la barra de título. Colores RGBA 0-1: el dorado es el de
    -- los textos de Blizzard, para que la selección no desentone.
    NAV = {
        WIDTH = 112,
        LEFT = 3,                  -- separación del borde izquierdo de la ventana
        TOP = -24,                 -- bajo la barra de título
        BOTTOM = 3,
        FIRST_GAP = 8,             -- espacio sobre la primera entrada
        ENTRY_HEIGHT = 20,
        ENTRY_GAP = 2,
        HEADER_GAP = 10,           -- espacio sobre el título de un grupo
        TEXT_LEFT = 10,            -- sangría del texto de las entradas sueltas
        INDENT = 18,               -- sangría de las entradas de un grupo
        ACCENT_WIDTH = 2,          -- raya a la izquierda de la entrada elegida
        DIVIDER_WIDTH = 1,         -- línea entre la barra y el contenido
        BACKGROUND_COLOR = { 0, 0, 0, 0.35 },
        DIVIDER_COLOR = { 1, 0.82, 0, 0.25 },
        HOVER_COLOR = { 1, 1, 1, 0.08 },
        SELECTED_COLOR = { 1, 0.82, 0, 0.12 },
        ACCENT_COLOR = { 1, 0.82, 0, 1 },
        TEXT_COLOR = { 0.85, 0.85, 0.85 },
        SELECTED_TEXT_COLOR = { 1, 0.82, 0 },
    },
    -- Colores de las líneas del tooltip (RGB 0-1).
    TOOLTIP_KEY_COLOR = { 0.2, 1, 0.6 },
    TOOLTIP_WARNING_COLOR = { 1, 0.4, 0.4 },
    TOOLTIP_HELP_COLOR = { 0.8, 0.8, 0.8 },
}

-- Aviso del taunt de la mascota (Features/PetTaunt.lua). En mazmorras y bandas
-- tanquea el tanque: si la mascota provoca, le quita los enemigos. Fuera, en
-- solitario, interesa lo contrario: que la mascota los aguante.
Const.PET_TAUNT = {
    -- Bramido (Growl en inglés), rangos 1 a 7, según Wowhead Forever. La lista
    -- vale para cualquier taunt de mascota: añadir sus IDs basta (por ejemplo,
    -- Tormento del abisario del brujo).
    SPELLS = { 2649, 14916, 14917, 14918, 14919, 14920, 14921 },
    -- Tipos de instancia (Api.InstanceType) donde debe estar desactivado.
    OFF_IN = { party = true, raid = true },
    -- Espera tras cambiar de zona o de mascota antes de comprobar: al salir de
    -- una pantalla de carga la barra de la mascota tarda un momento en estar lista.
    CHECK_DELAY = 1,
    -- Repetir el aviso al entrar en combate si sigue mal (el primero se puede
    -- perder durante la pantalla de carga o con el chat lleno).
    REMIND_ON_COMBAT = true,
}

-- Aviso de munición baja (Features/Ammo.lua). Usa los números de clase y
-- subclase de objeto del juego, que no dependen del idioma.
Const.AMMO = {
    CLASSES = { HUNTER = true },   -- solo para quien depende de la munición
    -- Tipos de munición, por su subclase de objeto: 2 flechas, 3 balas. Cada
    -- uno con sus umbrales por defecto, que el jugador cambia en la ventana:
    -- por debajo de "low", recuadro ámbar; por debajo de "critical", rojo.
    -- "key" es el nombre con el que se guardan sus umbrales.
    TYPES = {
        [2] = { key = "arrow", label = "Arco/ballesta", low = 200, critical = 50,
                icon = "Interface\\Icons\\INV_Ammo_Arrow_02" },
        [3] = { key = "bullet", label = "Arma de fuego", low = 200, critical = 50,
                icon = "Interface\\Icons\\INV_Ammo_Bullet_02" },
    },
    TYPE_ORDER = { 2, 3 },         -- orden en la ventana
    MAX_THRESHOLD = 9999,          -- tope de los umbrales (cabe en UI.NUMBER_MAX_DIGITS)
    RANGED_SLOT = 18,              -- ranura del arma a distancia
    AMMO_SLOT = 0,                 -- ranura de la munición (en clientes que la tienen)
    WEAPON_CLASS = 2,              -- clase de objeto "arma"
    PROJECTILE_CLASS = 6,          -- clase de objeto "proyectil"
    -- Subclase del arma -> subclase de la munición que dispara: arco (2) y
    -- ballesta (18) usan flechas (2); armas de fuego (3), balas (3). Las
    -- arrojadizas y las varitas no gastan munición y no aparecen.
    WEAPON_AMMO = { [2] = 2, [18] = 2, [3] = 3 },
    CHECK_DELAY = 0.5,             -- agrupa las ráfagas de BAG_UPDATE al disparar o lootear
}

-- Aviso de aspecto (Features/Aspect.lua). IDs según Wowhead Forever; todos
-- los rangos de un aspecto se llaman igual, así que con el nombre del primero
-- se reconocen los demás. "label" es el nombre corto de la ventana y
-- "default" si cuenta como aspecto válido mientras el jugador no lo cambie:
-- los de combate sí; los de viaje y de grupo no, para que avise si entras en
-- combate con ellos (el guepardo y la manada te dejan aturdido al recibir golpes).
Const.ASPECT = {
    CLASSES = { HUNTER = true },
    LIST = {   -- en el orden de la ventana
        { key = "hawk", label = "Halcón", default = true,
          spells = { 13165, 14318, 14319, 14320, 14321, 14322, 25296 } },
        { key = "monkey", label = "Mono", default = true, spells = { 13163 } },
        { key = "wild", label = "Salvaje", default = false, spells = { 20043, 20190 } },
        { key = "cheetah", label = "Guepardo", default = false, spells = { 5118 } },
        { key = "pack", label = "Manada", default = false, spells = { 13159 } },
        { key = "beast", label = "Bestia", default = false, spells = { 13161 } },
    },
    -- En combate UNIT_AURA llega sin parar (cualquier beneficio o perjuicio):
    -- se agrupa para no repasar las auras con cada uno.
    CHECK_DELAY = 0.2,
}

-- Recuadro de aviso discreto (UI/NoticeBox.lua): un marco pequeño con icono y
-- texto, que el jugador puede mover. Colores del borde (RGB 0-1) por nivel.
Const.NOTICE = {
    WIDTH = 190,
    HEIGHT = 36,
    ICON_SIZE = 24,
    PADDING = 6,
    DEFAULT_POINT = { "CENTER", 0, -160 },   -- algo por debajo del centro de la pantalla
    BACKGROUND = "Interface\\Tooltips\\UI-Tooltip-Background",
    BORDER = "Interface\\Tooltips\\UI-Tooltip-Border",
    BORDER_SIZE = 12,
    INSET = 3,
    BACKGROUND_COLOR = { 0, 0, 0, 0.7 },
    LEVEL_COLOR = {
        warning = { 1, 0.75, 0 },
        critical = { 1, 0.25, 0.25 },
    },
}

-- Botón del minimapa. Las medidas y texturas son las del aro estándar que usan
-- los botones de minimapa de casi todos los addons, para que no desentone.
-- Las posiciones son píxeles desde la esquina superior izquierda del botón.
Const.MINIMAP = {
    BUTTON_NAME = "StreamDeckWoWMinimapButton",   -- nombre global (otros addons de minimapa lo reconocen)
    DEFAULT_ANGLE = 225,     -- grados desde la derecha, en sentido antihorario: abajo a la izquierda
    EDGE_OFFSET = 5,         -- cuánto sobresale el botón del borde del minimapa
    FRAME_LEVEL = 8,         -- por encima de los iconos del propio minimapa
    SIZE = 31,
    BORDER_SIZE = 53,
    BORDER_TEXTURE = "Interface\\Minimap\\MiniMap-TrackingBorder",
    BACKGROUND_SIZE = 20,
    BACKGROUND_OFFSET = { 7, -5 },
    BACKGROUND_TEXTURE = "Interface\\Minimap\\UI-Minimap-Background",
    ICON_SIZE = 17,
    ICON_OFFSET = { 7, -6 },
    -- Máscara circular para que el icono (cuadrado) encaje en el aro.
    ICON_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    HIGHLIGHT_TEXTURE = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
}
