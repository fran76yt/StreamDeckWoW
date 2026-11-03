--[[
Ventana de configuración (/sdeck config)
========================================

Una ventana con los 12 botones de hueco (SlotButton.lua) en dos filas, un
texto de ayuda y un botón para recargar la interfaz.

Se crea la primera vez que se abre: si el jugador nunca la usa, no consume nada.
Se redibuja sola cuando el núcleo avisa de que los huecos han cambiado.
]]

local _, ns = ...
local Const, Util = ns.Const, ns.Util
local UI = Const.UI

local ConfigWindow = {}
ns.ConfigWindow = ConfigWindow

local frame          -- la ventana (nil hasta que se abre)
local buttons = {}   -- buttons[n] = botón del hueco n

--------------------------------------------------------------------------------
-- Disposición
--------------------------------------------------------------------------------

local function windowWidth()
    return UI.COLUMNS * UI.SLOT_SIZE + (UI.COLUMNS - 1) * UI.SLOT_GAP + 2 * UI.PADDING
end

-- Posición (relativa a la esquina superior izquierda) del hueco n.
local function slotOffset(n)
    local col, row = (n - 1) % UI.COLUMNS, math.floor((n - 1) / UI.COLUMNS)
    return UI.PADDING + col * (UI.SLOT_SIZE + UI.SLOT_GAP),
           UI.SLOTS_TOP - row * (UI.SLOT_SIZE + UI.SLOT_ROW_GAP)
end

--------------------------------------------------------------------------------
-- Dibujado
--------------------------------------------------------------------------------

local function refresh()
    if not frame or not frame:IsShown() then return end
    for _, b in ipairs(buttons) do b:Update() end
end

--------------------------------------------------------------------------------
-- Construcción
--------------------------------------------------------------------------------

-- Marco de la ventana: plantilla de Blizzard con título y botón de cerrar,
-- arrastrable y que se cierra con Escape.
local function createFrame()
    local f = CreateFrame("Frame", UI.FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(windowWidth(), UI.HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnShow", refresh)
    -- Los frames de esta lista se cierran al pulsar Escape (por su nombre global).
    table.insert(UISpecialFrames, UI.FRAME_NAME)
    return f
end

-- Título con el icono del addon a la izquierda y la versión. La plantilla trae
-- TitleText en el cliente moderno; si no, creamos uno propio.
local function createTitle(f)
    local title = f.TitleText
    if not title then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText(("%s  |cff888888%s|r"):format(UI.TITLE, ns.Api.AddOnVersion()))
    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetSize(UI.TITLE_ICON_SIZE, UI.TITLE_ICON_SIZE)
    icon:SetPoint("RIGHT", title, "LEFT", -4, 0)
    icon:SetTexture(Const.ICON)
end

local function createSlots(f)
    for n = 1, Const.NUM_SLOTS do
        local b = ns.SlotButton.Create(f, n)
        b:SetPoint("TOPLEFT", slotOffset(n))
        buttons[n] = b
    end
end

local function createHelp(f)
    local help = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("BOTTOMLEFT", UI.PADDING, 44)
    help:SetPoint("BOTTOMRIGHT", -UI.PADDING, 44)
    help:SetText("Los cambios funcionan al momento. Para que la Stream Deck muestre los iconos nuevos hay que recargar la interfaz.")
end

-- ReloadUI hace que WoW escriba las SavedVariables a disco, que es lo que el
-- plugin vigila. Recargar corta lo que el jugador esté haciendo (pantalla de
-- carga de un par de segundos), así que lo decide él con un botón.
local function createReloadButton(f)
    local reload = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reload:SetSize(200, 24)
    reload:SetPoint("BOTTOM", 0, 14)
    reload:SetText("Actualizar Stream Deck")
    reload:SetScript("OnClick", ReloadUI)
end

local function create()
    frame = createFrame()
    createTitle(frame)
    createSlots(frame)
    createHelp(frame)
    createReloadButton(frame)
end

--------------------------------------------------------------------------------
-- API del módulo
--------------------------------------------------------------------------------

function ConfigWindow.Toggle()
    if not frame then create() end
    frame:SetShown(not frame:IsShown())
end

Util.Listen(Const.MSG.SLOTS_UPDATED, refresh)
