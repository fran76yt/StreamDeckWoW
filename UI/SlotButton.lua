--[[
Botón de hueco
==============

Componente reutilizable: un cuadrado con el icono del hueco, su atajo encima y
su nombre debajo, que acepta hechizos, objetos y macros arrastrados. No sabe
dónde está colocado; eso lo decide quien lo crea (ConfigWindow.lua).

Interacción, igual que en una barra de acción del juego:
  * Arrastrar y soltar, o coger con un clic y dejar con otro.
  * Clic derecho: volver al valor por defecto.
  * Mayús + clic derecho: dejar el hueco vacío.
]]

local _, ns = ...
local Const, Util, Api, Keys, Slots = ns.Const, ns.Util, ns.Api, ns.Keys, ns.Slots
local UI = Const.UI

ns.SlotButton = {}

--------------------------------------------------------------------------------
-- Datos para pintar
--------------------------------------------------------------------------------

-- Iconos de reserva por tipo, cuando la foto del hueco no trae icono.
local iconLookups = {
    spell = Api.SpellIcon,
    item = Api.ItemIcon,
}

-- Icono a mostrar para la foto de un hueco.
local function iconFor(snapshot)
    if snapshot.icon then return snapshot.icon end
    local lookup = iconLookups[snapshot.kind]
    return (lookup and snapshot.id and lookup(snapshot.id)) or Const.ICON_UNKNOWN
end

local function nameColor(n)
    return unpack(Slots.IsCustom(n) and UI.NAME_COLOR_CUSTOM or UI.NAME_COLOR_DEFAULT)
end

--------------------------------------------------------------------------------
-- Comportamiento
--------------------------------------------------------------------------------

-- Soltar lo que lleva el cursor sobre el hueco.
local function onReceiveDrag(self)
    local entry = Api.CursorEntry()
    if entry then
        Slots.Set(self.slot, entry)
        Api.ClearCursor()   -- "suelta" el objeto del cursor, como hacen las barras
    end
end

local function onClick(self, button)
    if Api.HasCursorContent() then
        onReceiveDrag(self)
    elseif button == "RightButton" then
        Slots.Set(self.slot, IsShiftKeyDown() and false or nil)
    end
end

-- Primera parte del tooltip: la del propio juego para hechizos y objetos, que
-- ya trae toda la información.
local tooltipWriters = {
    spell = function(id) GameTooltip:SetSpellByID(id) end,
    item = function(id) GameTooltip:SetItemByID(id) end,
}

local function onEnter(self)
    local s = Slots.Get(self.slot)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local write = s and s.id and tooltipWriters[s.kind]
    if write then
        write(s.id)
    else
        GameTooltip:SetText((s and s.name) or "Vacío")
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Tecla de la Stream Deck: " .. Keys.Label(self.slot), unpack(UI.TOOLTIP_KEY_COLOR))
    if s and s.kind and not s.active then
        GameTooltip:AddLine("Todavía no lo tienes: la tecla no hará nada.", unpack(UI.TOOLTIP_WARNING_COLOR))
    end
    GameTooltip:AddLine("Arrastra aquí un hechizo, objeto o macro.", unpack(UI.TOOLTIP_HELP_COLOR))
    GameTooltip:AddLine("Clic derecho: valor por defecto.  Mayús+clic derecho: vaciar.", unpack(UI.TOOLTIP_HELP_COLOR))
    GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- Construcción
--------------------------------------------------------------------------------

-- Pinta el botón con la foto actual de su hueco.
local function update(self)
    local s = Slots.Get(self.slot)
    local empty = not s or s.empty
    self.icon:SetTexture(not empty and iconFor(s) or nil)
    self.icon:SetDesaturated(s and not s.active)          -- en gris lo que aún no tienes
    self.label:SetText(empty and Util.Colorize(Const.COLOR.EMPTY, "vacío") or (s.short or s.name or ""))
    self.label:SetTextColor(nameColor(self.slot))
end

-- Crea el botón del hueco n dentro de parent.
function ns.SlotButton.Create(parent, n)
    local b = CreateFrame("Button", nil, parent)
    b.slot = n
    b.Update = update
    b:SetSize(UI.SLOT_SIZE, UI.SLOT_SIZE)

    -- Capas de dibujo: BACKGROUND (fondo) < ARTWORK (icono) < OVERLAY (textos).
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, UI.SLOT_BACKGROUND_ALPHA)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b:SetHighlightTexture(UI.HIGHLIGHT_TEXTURE, "ADD")

    local key = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    key:SetPoint("BOTTOM", b, "TOP", 0, UI.KEY_LABEL_OFFSET)
    key:SetText("F" .. n)

    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, UI.NAME_OFFSET)
    b.label:SetWidth(UI.SLOT_SIZE + UI.SLOT_GAP)
    b.label:SetWordWrap(false)   -- los nombres largos se cortan con "..."

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnReceiveDrag", onReceiveDrag)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end
