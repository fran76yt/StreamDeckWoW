--[[
Botón del minimapa
==================

Un botón redondo pegado al borde del minimapa, con el icono del addon:
  clic             abrir o cerrar la ventana de configuración
  clic derecho     estado de las teclas en el chat (como /sdeck)
  arrastrar        moverlo alrededor del minimapa
  /sdeck minimapa  ocultarlo o volver a mostrarlo

Está hecho a mano, sin LibDBIcon: es poco código y así el addon no depende de
librerías externas que haya que incluir y mantener al día.

La posición se guarda como un ángulo alrededor del centro del minimapa, no
como coordenadas: así sigue en su sitio aunque el minimapa cambie de tamaño o
de escala. Se guarda por personaje, junto al resto de datos del addon.
]]

local _, ns = ...
local Const, Util, Storage = ns.Const, ns.Util, ns.Storage
local M = Const.MINIMAP

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local button   -- el botón (nil hasta que se crea al entrar)

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

local function savedAngle()
    return Storage.GetMinimap().angle or M.DEFAULT_ANGLE
end

local function place(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", edgeOffset(angle))
end

local function applyVisibility()
    button:SetShown(not Storage.GetMinimap().hidden)
end

--------------------------------------------------------------------------------
-- Interacción
--------------------------------------------------------------------------------

-- Mientras se arrastra, el botón sigue al ratón en cada fotograma (OnUpdate).
-- La posición se guarda solo al soltar.
local function followCursor()
    place(cursorAngle())
end

local function onDragStart(self)
    GameTooltip_Hide()
    self:SetScript("OnUpdate", followCursor)
end

local function onDragStop(self)
    self:SetScript("OnUpdate", nil)
    Storage.GetMinimap().angle = cursorAngle()
    place(savedAngle())
end

-- Qué hace cada botón del ratón. Los módulos se buscan en ns al hacer clic,
-- no al cargar: Commands se carga después que este archivo.
local clickActions = {
    LeftButton = function() ns.ConfigWindow.Toggle() end,
    RightButton = function() ns.Commands.Run("estado") end,
}

local function onClick(_, mouseButton)
    local action = clickActions[mouseButton]
    if action then action() end
end

local TOOLTIP_HELP = {
    "Clic: configurar las teclas",
    "Clic derecho: estado de las teclas",
    "Arrastrar: mover este botón",
    "/sdeck minimapa: ocultarlo",
}

local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(Const.UI.TITLE)
    for _, line in ipairs(TOOLTIP_HELP) do
        GameTooltip:AddLine(line, unpack(Const.UI.TOOLTIP_HELP_COLOR))
    end
    GameTooltip:Show()
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

local function createScripts(b)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnDragStart", onDragStart)
    b:SetScript("OnDragStop", onDragStop)
    b:SetScript("OnEnter", showTooltip)
    b:SetScript("OnLeave", GameTooltip_Hide)
end

local function create()
    local b = CreateFrame("Button", M.BUTTON_NAME, Minimap)
    b:SetSize(M.SIZE, M.SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(M.FRAME_LEVEL)
    createTextures(b)
    createScripts(b)
    return b
end

-- Se crea al entrar, cuando ya están cargadas las SavedVariables con su
-- posición. PLAYER_LOGIN puede llegar más de una vez en las pruebas: solo se
-- crea la primera.
Util.On("PLAYER_LOGIN", function()
    if button then return end
    button = create()
    place(savedAngle())
    applyVisibility()
end)

--------------------------------------------------------------------------------
-- API del módulo
--------------------------------------------------------------------------------

-- Oculta o muestra el botón y lo recuerda. Devuelve true si queda visible.
function MinimapButton.ToggleShown()
    local hidden = Util.ToggleFlag(Storage.GetMinimap(), "hidden")
    if button then applyVisibility() end
    return not hidden
end
