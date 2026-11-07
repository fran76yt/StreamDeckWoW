--[[
Ventana de configuración (/sdeck config)
========================================

Una ventana con pestañas:
  Teclas     un botón por hueco (SlotButton.lua), en filas, un texto de ayuda
             y un botón para recargar la interfaz.
  <Clase>    opciones propias de la clase del personaje (UI/ClassTabs), si su
             clase tiene pestaña. Con una sola pestaña no se muestran botones.

Se crea la primera vez que se abre: si el jugador nunca la usa, no consume nada.
Se redibuja sola cuando el núcleo avisa de que los huecos o las opciones han
cambiado.
]]

local _, ns = ...
local Const, Util = ns.Const, ns.Util
local UI = Const.UI

local ConfigWindow = {}
ns.ConfigWindow = ConfigWindow

local frame          -- la ventana (nil hasta que se abre)
local pages = {}     -- pages[i] = { frame, update } de la pestaña i

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
-- Pestaña "Teclas"
--------------------------------------------------------------------------------

local function createSlots(page)
    local buttons = {}
    for n = 1, Const.NUM_SLOTS do
        local b = ns.SlotButton.Create(page, n)
        b:SetPoint("TOPLEFT", slotOffset(n))
        buttons[n] = b
    end
    return buttons
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

-- Cada pestaña es { title, build(page) -> update }: build dibuja su contenido
-- en la página y devuelve la función que lo vuelve a leer.
local slotsTab = {
    title = "Teclas",
    build = function(page)
        local buttons = createSlots(page)
        createHelp(page)
        createReloadButton(page)
        return function()
            for _, b in ipairs(buttons) do b:Update() end
        end
    end,
}

-- Pestaña de la clase del personaje, descrita como filas (UI/OptionsPage.lua).
local function classTab()
    local tab = ns.ClassTabs.For(ns.Api.PlayerClass())
    if not tab then return nil end
    return {
        title = tab.title,
        build = function(page) return ns.OptionsPage.Build(page, tab.rows) end,
    }
end

local function tabList()
    local tabs = { slotsTab }
    tabs[#tabs + 1] = classTab()
    return tabs
end

--------------------------------------------------------------------------------
-- Dibujado
--------------------------------------------------------------------------------

-- Vuelve a leer las páginas visibles. Las ocultas se leen al mostrarlas.
local function refresh()
    if not frame or not frame:IsShown() then return end
    for _, p in ipairs(pages) do
        if p.frame:IsShown() then p.update() end
    end
end

local function showPage(index)
    for i, p in ipairs(pages) do p.frame:SetShown(i == index) end
    refresh()
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
    title:SetText(("%s  %s"):format(UI.TITLE, Util.Colorize(Const.COLOR.DIM, ns.Api.AddOnVersion())))
    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetSize(UI.TITLE_ICON_SIZE, UI.TITLE_ICON_SIZE)
    icon:SetPoint("RIGHT", title, "LEFT", -UI.TITLE_ICON_GAP, 0)
    icon:SetTexture(Const.ICON)
end

-- Una página (marco que ocupa toda la ventana) por pestaña.
local function createPages(f, tabs)
    for i, tab in ipairs(tabs) do
        local page = CreateFrame("Frame", nil, f)
        page:SetAllPoints()
        pages[i] = { frame = page, update = tab.build(page) }
    end
end

local function createTabs(f, tabs)
    if #tabs < 2 then return end
    local titles = {}
    for i, tab in ipairs(tabs) do titles[i] = tab.title end
    ns.TabBar.Create(f, titles, showPage):Select(1)
end

local function create()
    frame = createFrame()
    createTitle(frame)
    local tabs = tabList()
    createPages(frame, tabs)
    showPage(1)
    createTabs(frame, tabs)
end

--------------------------------------------------------------------------------
-- API del módulo
--------------------------------------------------------------------------------

function ConfigWindow.Toggle()
    if not frame then create() end
    frame:SetShown(not frame:IsShown())
end

Util.Listen(Const.MSG.SLOTS_UPDATED, refresh)
-- Una opción cambiada con un comando (/sdeck aviso...) se ve en su casilla.
Util.Listen(Const.MSG.SETTINGS_CHANGED, refresh)
