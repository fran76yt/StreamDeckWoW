--[[
Ventana de configuración (/sdeck config)
========================================

Una ventana con un botón por hueco (SlotButton.lua), en filas, un
texto de ayuda, las opciones (casillas, Checkbox.lua) y un botón para
recargar la interfaz.

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
local checks = {}    -- casillas de opciones

--------------------------------------------------------------------------------
-- Disposición
--------------------------------------------------------------------------------

-- Opciones del addon. Cada una es una entrada de esta tabla: añadir otra es
-- añadir una línea; la ventana crece sola para que quepa. El estado lo guarda
-- su módulo; la casilla solo lo muestra y lo cambia a través de él.
local OPTIONS = {
    {
        label = "Avisar del taunt de la mascota (Bramido)",
        tooltip = {
            "Aviso del taunt de la mascota",
            "Avisa si el Bramido automático está activado en mazmorra o banda",
            "(le quita los enemigos al tanque) o desactivado fuera de ellas.",
            "También con /sdeck aviso.",
        },
        get = function() return ns.PetTaunt.IsEnabled() end,
        set = function(on) ns.PetTaunt.SetEnabled(on) end,
    },
    {
        label = "Avisar de munición baja",
        tooltip = {
            "Aviso de munición baja",
            ("Un recuadro discreto con menos de %d flechas o balas,"):format(Const.AMMO.LOW),
            ("en rojo con menos de %d. Se puede mover arrastrándolo."):format(Const.AMMO.CRITICAL),
            "También con /sdeck municion.",
        },
        get = function() return ns.Ammo.IsEnabled() end,
        set = function(on) ns.Ammo.SetEnabled(on) end,
    },
}

local function windowWidth()
    return UI.COLUMNS * UI.SLOT_SIZE + (UI.COLUMNS - 1) * UI.SLOT_GAP + 2 * UI.PADDING
end

-- Lo que ocupan las casillas, que van entre el botón de recargar y el texto
-- de ayuda. Todo lo de abajo se ancla al borde inferior y los huecos al
-- superior, así que basta con sumarlo al alto y subir el texto de ayuda.
local function optionsHeight()
    return #OPTIONS * UI.CHECK_SIZE + UI.OPTIONS_GAP
end

local function windowHeight()
    return UI.HEIGHT + optionsHeight()
end

local function helpBottom()
    return UI.HELP_BOTTOM + optionsHeight()
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

local function refreshChecks()
    for _, c in ipairs(checks) do c:Update() end
end

--------------------------------------------------------------------------------
-- Construcción
--------------------------------------------------------------------------------

-- Marco de la ventana: plantilla de Blizzard con título y botón de cerrar,
-- arrastrable y que se cierra con Escape.
local function createFrame()
    local f = CreateFrame("Frame", UI.FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(windowWidth(), windowHeight())
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnShow", function() refresh() refreshChecks() end)
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

local function createSlots(f)
    for n = 1, Const.NUM_SLOTS do
        local b = ns.SlotButton.Create(f, n)
        b:SetPoint("TOPLEFT", slotOffset(n))
        buttons[n] = b
    end
end

local function createHelp(f)
    local help = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("BOTTOMLEFT", UI.PADDING, helpBottom())
    help:SetPoint("BOTTOMRIGHT", -UI.PADDING, helpBottom())
    help:SetText("Los cambios funcionan al momento (en combate, al terminar). Para que la Stream Deck muestre los iconos nuevos hay que recargar la interfaz.")
end

local function createOptions(f)
    for i, opt in ipairs(OPTIONS) do
        local c = ns.Checkbox.Create(f, opt)
        c:SetPoint("BOTTOMLEFT", UI.PADDING, UI.CHECK_BOTTOM + (i - 1) * UI.CHECK_SIZE)
        checks[i] = c
    end
end

-- ReloadUI hace que WoW escriba las SavedVariables a disco, que es lo que el
-- plugin vigila. Recargar corta lo que el jugador esté haciendo (pantalla de
-- carga de un par de segundos), así que lo decide él con un botón.
local function createReloadButton(f)
    local reload = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reload:SetSize(UI.RELOAD_BUTTON_WIDTH, UI.RELOAD_BUTTON_HEIGHT)
    reload:SetPoint("BOTTOM", 0, UI.RELOAD_BUTTON_BOTTOM)
    reload:SetText("Actualizar Stream Deck")
    reload:SetScript("OnClick", ReloadUI)
end

local function create()
    frame = createFrame()
    createTitle(frame)
    createSlots(frame)
    createHelp(frame)
    createOptions(frame)
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
-- Si una opción cambia con un comando estando la ventana creada, la casilla
-- se pone al día (aunque esté cerrada: así ya está bien al abrirla).
Util.Listen(Const.MSG.SETTINGS_CHANGED, refreshChecks)
