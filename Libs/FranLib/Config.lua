--[[
FranLib: configuración
======================

FranLib es el código común de los addons de Fran (utilidades, acceso a la API
del juego, registro de errores, tooltips, casillas y botón del minimapa). Va
incrustada: cada addon lleva su copia en Libs\FranLib\ y la carga desde su
.toc, como se hace con Ace3 y el resto de librerías de WoW, para que cada
addon funcione solo, sin tener que instalar nada más. El original está en el
repositorio FranLib y se copia a los addons con su tools/sync.py.

Cada copia trabaja para su addon: escribe en el chat con su prefijo, apunta
sus errores en su variable y pone su botón en el minimapa. Por eso los
módulos se guardan en la tabla privada del addon (ns.Util, ns.Api...), no en
una global, y no hace falta un LibStub que elija una versión para todos.

Este archivo va el primero. Lee lo que el addon dice de sí mismo en
ns.FranLibConfig, que tiene que estar definido antes (en sus constantes):

  ns.FranLibConfig = {
      icon = "Interface\\Icons\\...",          -- icono del addon
      chatPrefix = "|cff33ff99MiAddon|r",       -- delante de cada mensaje del chat
      errorLog = {
          savedVar = "MiAddonLog",             -- variable de la cuenta (## SavedVariables)
          command = "/miaddon errores",        -- comando que enseña los errores
      },
      minimap = {
          buttonName = "MiAddonMinimapButton", -- nombre global del botón
          defaultAngle = 225,                  -- opcional: posición inicial, en grados
      },
  }

y lo junta con los valores fijos de la librería en ns.FranLib, que es lo que
leen los demás módulos. Si falta algo, da un error al cargar: es un fallo de
quien escribe el addon y conviene verlo enseguida, no a mitad de partida.
]]

local addonName, ns = ...

local VERSION = "1.0.0"

--------------------------------------------------------------------------------
-- Valores fijos de la librería
--------------------------------------------------------------------------------

local CONST = {
    -- Mensaje interno (Util.Fire / Util.Listen) cuando cambia una opción:
    -- lo lanzan los interruptores de Util y lo escuchan las ventanas.
    SETTINGS_CHANGED = "SETTINGS_CHANGED",

    -- Gris claro de las líneas de ayuda de los tooltips.
    TOOLTIP_HELP_COLOR = { 0.8, 0.8, 0.8 },

    -- Casillas de verificación (Checkbox.lua).
    CHECK = {
        SIZE = 24,
        LABEL_GAP = 2,         -- separación entre la casilla y su texto
        ICON_SIZE = 16,        -- icono delante del texto
    },

    -- Registro de errores (ErrorLog.lua).
    ERROR_LOG = {
        MAX_ENTRIES = 50,          -- errores distintos que se guardan como mucho
        MAX_STACK_CHARS = 2000,    -- tope de la pila de cada uno, para no inflar el archivo
        STACK_COLOR = "999999",    -- gris para la pila en el chat
    },

    -- Botón del minimapa (MinimapButton.lua). Las medidas y texturas son las
    -- del aro estándar que usan los botones de minimapa de casi todos los
    -- addons, para que no desentone. Las posiciones son píxeles desde la
    -- esquina superior izquierda del botón.
    MINIMAP = {
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
    },
}

--------------------------------------------------------------------------------
-- Lo que pone el addon
--------------------------------------------------------------------------------

-- Valor obligatorio de la configuración del addon, por su ruta ("errorLog.savedVar").
local function required(config, path)
    local value = config
    for key in path:gmatch("[^.]+") do
        value = type(value) == "table" and value[key] or nil
    end
    if value == nil then
        error(("FranLib (%s): falta ns.FranLibConfig.%s"):format(addonName, path), 3)
    end
    return value
end

-- Copia de una tabla con más campos encima (sin tocar la original, que es
-- la misma para todos los que la reciben).
local function with(base, extra)
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(extra) do t[k] = v end
    return t
end

local function build(config)
    local minimap = config.minimap or {}
    return {
        VERSION = VERSION,
        Const = CONST,
        addonName = addonName,
        icon = required(config, "icon"),
        chatPrefix = required(config, "chatPrefix"),
        errorLog = with(CONST.ERROR_LOG, {
            SAVED_VAR = required(config, "errorLog.savedVar"),
            COMMAND = required(config, "errorLog.command"),
        }),
        minimap = with(CONST.MINIMAP, {
            BUTTON_NAME = required(config, "minimap.buttonName"),
            DEFAULT_ANGLE = minimap.defaultAngle or CONST.MINIMAP.DEFAULT_ANGLE,
        }),
    }
end

ns.FranLib = build(ns.FranLibConfig or {})
