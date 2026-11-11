--[[
Botón del minimapa
==================

Componente compartido con StreamDeckWoW (ver tools/sync_shared.py en
FranTools): se edita allí y se copia a los dos addons.

Un botón redondo pegado al borde del minimapa, con el icono del addon. Cada
addon dice qué hace cada clic y qué pone su tooltip:

  local button = ns.MinimapButton.Create({
      settings = Storage.GetMinimap,          -- tabla donde guardar angle y hidden
      tooltip = { "Título", "Clic: ...", ... },
      onClick = { LeftButton = fn, RightButton = fn },
  })
  button:ToggleShown()   -- oculta o muestra el botón; true si queda visible

Arrastrándolo se mueve alrededor del minimapa. Usa Const.MINIMAP (medidas,
texturas y nombre global) y Const.ICON del addon.

Está hecho a mano, sin LibDBIcon: es poco código y así el addon no depende de
librerías externas que haya que incluir y mantener al día.

La posición se guarda como un ángulo alrededor del centro del minimapa, no
como coordenadas: así sigue en su sitio aunque el minimapa cambie de tamaño o
de escala. Se guarda por personaje, junto al resto de datos del addon.
]]

local _, ns = ...
local Const, Util = ns.Const, ns.Util
local M = Const.MINIMAP

local MinimapButton = {}
ns.MinimapButton = MinimapButton

-- Lua 5.1 (el de WoW) trae math.atan2; en versiones posteriores es math.atan
-- con dos argumentos. Así funciona en el juego y en las pruebas fuera de él.
local atan2 = math.atan2 or math.atan

--------------------------------------------------------------------------------
-- Geometría
--------------------------------------------------------------------------------

-- GetMinimapShape no es de Blizzard: la definen los addons que cambian la
-- forma del minimapa. Si no existe, el minimapa es el redondo de siempre.
local function isSquareMinimap()
    return GetMinimapShape ~= nil and GetMinimapShape() == "SQUARE"
end

-- En un minimapa cuadrado el botón debe recorrer los lados, no un círculo:
-- se estira el círculo hasta las esquinas (por √2) y se recorta a cada lado.
local function toSquare(v)
    return math.max(-1, math.min(1, v * math.sqrt(2)))
end

-- Desplazamiento (x, y) desde el centro del minimapa para un ángulo en grados.
local function edgeOffset(angle)
    local radius = Minimap:GetWidth() / 2 + M.EDGE_OFFSET
    local x, y = math.cos(math.rad(angle)), math.sin(math.rad(angle))
    if isSquareMinimap() then x, y = toSquare(x), toSquare(y) end
    return x * radius, y * radius
end

-- Ángulo del ratón respecto al centro del minimapa. GetCursorPosition da
-- píxeles de pantalla y GetCenter unidades de la interfaz: se pasa de unas a
-- otras dividiendo por la escala efectiva del minimapa.
local function cursorAngle()
    local cx, cy = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    return math.deg(atan2(py / scale - cy, px / scale - cx))
end

--------------------------------------------------------------------------------
-- Posición y visibilidad
--------------------------------------------------------------------------------

local function savedAngle(settings)
    return settings().angle or M.DEFAULT_ANGLE
end

local function place(b, angle)
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", edgeOffset(angle))
end

local function applyVisibility(b, settings)
    b:SetShown(not settings().hidden)
end

--------------------------------------------------------------------------------
-- Construcción
--------------------------------------------------------------------------------

-- Añade una textura al botón con tamaño y, si se indica, desplazamiento desde
-- la esquina superior izquierda (sin desplazamiento, pegada a ella).
local function addTexture(b, layer, path, size, offset)
    local t = b:CreateTexture(nil, layer)
    t:SetTexture(path)
    t:SetSize(size, size)
    t:SetPoint("TOPLEFT", offset and offset[1] or 0, offset and offset[2] or 0)
    return t
end

-- Capas, de abajo arriba: fondo oscuro, icono y el aro dorado encima, que
-- tapa los bordes del icono.
local function createTextures(b)
    addTexture(b, "BACKGROUND", M.BACKGROUND_TEXTURE, M.BACKGROUND_SIZE, M.BACKGROUND_OFFSET)
    local icon = addTexture(b, "ARTWORK", Const.ICON, M.ICON_SIZE, M.ICON_OFFSET)
    -- SetMask no existe en clientes antiguos; sin él el icono queda cuadrado.
    if icon.SetMask then icon:SetMask(M.ICON_MASK) end
    addTexture(b, "OVERLAY", M.BORDER_TEXTURE, M.BORDER_SIZE)
    b:SetHighlightTexture(M.HIGHLIGHT_TEXTURE)
end

-- Mientras se arrastra, el botón sigue al ratón en cada fotograma (OnUpdate).
-- La posición se guarda solo al soltar.
local function createScripts(b, opts)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(_, mouseButton)
        local action = opts.onClick[mouseButton]
        if action then action() end
    end)
    b:SetScript("OnDragStart", function(self)
        GameTooltip_Hide()
        self:SetScript("OnUpdate", function() place(self, cursorAngle()) end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        opts.settings().angle = cursorAngle()
        place(self, savedAngle(opts.settings))
    end)
    ns.Tooltip.Attach(b, opts.tooltip, "ANCHOR_LEFT")
end

local function build(opts)
    local b = CreateFrame("Button", M.BUTTON_NAME, Minimap)
    b:SetSize(M.SIZE, M.SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(M.FRAME_LEVEL)
    createTextures(b)
    createScripts(b, opts)
    place(b, savedAngle(opts.settings))
    applyVisibility(b, opts.settings)
    return b
end

--------------------------------------------------------------------------------
-- API del componente
--------------------------------------------------------------------------------

local methods = {}

-- Oculta o muestra el botón y lo recuerda. Devuelve true si queda visible.
function methods:ToggleShown()
    local hidden = Util.ToggleFlag(self.opts.settings(), "hidden")
    if self.frame then applyVisibility(self.frame, self.opts.settings) end
    return not hidden
end

-- El marco se crea al entrar, cuando ya están cargadas las SavedVariables con
-- su posición. PLAYER_LOGIN puede llegar más de una vez en las pruebas: solo
-- se crea la primera.
function MinimapButton.Create(opts)
    local button = { opts = opts }
    for name, fn in pairs(methods) do button[name] = fn end
    Util.On("PLAYER_LOGIN", function()
        button.frame = button.frame or build(opts)
    end)
    return button
end
