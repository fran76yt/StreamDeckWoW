--[[
Ventana de configuración (/sdeck config)
========================================

Un botón por hueco (SlotButton.lua), en filas, un texto de ayuda y un botón
para recargar la interfaz. Las opciones de los avisos y demás funciones que
no son de las teclas están en el addon FranTools (/fran).

Se crea la primera vez que se abre: si el jugador nunca la usa, no consume nada.
Se redibuja sola cuando el núcleo avisa de que los huecos han cambiado.
]]

local _, ns = ...
local Const, Util, Api = ns.Const, ns.Util, ns.Api
local UI = Const.UI

local ConfigWindow = {}
ns.ConfigWindow = ConfigWindow

local frame          -- la ventana (nil hasta que se abre)
local buttons        -- un botón por hueco

--------------------------------------------------------------------------------
-- Disposición
--------------------------------------------------------------------------------

-- Ancho de la ventana: el de las filas de huecos.
local function frameWidth()
    return UI.COLUMNS * UI.SLOT_SIZE + (UI.COLUMNS - 1) * UI.SLOT_GAP + 2 * UI.PADDING
end

-- Posición (relativa a la esquina superior izquierda) del hueco n.
local function slotOffset(n)
    local col, row = (n - 1) % UI.COLUMNS, math.floor((n - 1) / UI.COLUMNS)
    return UI.PADDING + col * (UI.SLOT_SIZE + UI.SLOT_GAP),
           UI.SLOTS_TOP - row * (UI.SLOT_SIZE + UI.SLOT_ROW_GAP)
end

--------------------------------------------------------------------------------
-- Contenido
--------------------------------------------------------------------------------

local function createSlots(page)
    local list = {}
    for n = 1, Const.NUM_SLOTS do
        local b = ns.SlotButton.Create(page, n)
        b:SetPoint("TOPLEFT", slotOffset(n))
        list[n] = b
    end
    return list
end

local function createHelp(page)
    local help = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("BOTTOMLEFT", UI.PADDING, UI.HELP_BOTTOM)
    help:SetPoint("BOTTOMRIGHT", -UI.PADDING, UI.HELP_BOTTOM)
    help:SetText("Los cambios funcionan al momento (en combate, al terminar). Para que la Stream Deck muestre los iconos nuevos hay que recargar la interfaz.")
end

-- ReloadUI hace que WoW escriba las SavedVariables a disco, que es lo que el
-- plugin vigila. Recargar corta lo que el jugador esté haciendo (pantalla de
-- carga de un par de segundos), así que lo decide él con un botón.
local function createReloadButton(page)
    local reload = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    reload:SetSize(UI.RELOAD_BUTTON_WIDTH, UI.RELOAD_BUTTON_HEIGHT)
    reload:SetPoint("BOTTOM", 0, UI.RELOAD_BUTTON_BOTTOM)
    reload:SetText("Actualizar Stream Deck")
    reload:SetScript("OnClick", ReloadUI)
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
local function createFrame(width)
    local f = CreateFrame("Frame", UI.FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(width, UI.HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnShow", refresh)
    -- Los frames de esta lista se cierran al pulsar Escape (por su nombre global).
    table.insert(UISpecialFrames, UI.FRAME_NAME)
    -- CreateFrame devuelve el frame ya visible. Lo ocultamos para que quien lo
    -- crea decida cuándo mostrarlo (y para que OnShow salte al hacerlo).
    f:Hide()
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
    title:SetText(("%s  %s"):format(UI.TITLE, Util.Colorize(Const.COLOR.DIM, Api.AddOnVersion())))
    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetSize(UI.TITLE_ICON_SIZE, UI.TITLE_ICON_SIZE)
    icon:SetPoint("RIGHT", title, "LEFT", -UI.TITLE_ICON_GAP, 0)
    icon:SetTexture(Const.ICON)
end

local function create()
    frame = createFrame(frameWidth())
    createTitle(frame)
    buttons = createSlots(frame)
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
