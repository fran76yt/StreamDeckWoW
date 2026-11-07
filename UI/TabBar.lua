--[[
Pestañas
========

Una fila de botones colgando bajo el borde inferior de una ventana, como las
pestañas de las ventanas de Blizzard. Al pulsar uno se llama a onSelect(i).
La pestaña activa queda deshabilitada (no se puede volver a pulsar), que es
como la distingue el jugador.

  local tabs = ns.TabBar.Create(window, { "Teclas", "Cazador" }, function(i) ... end)
  tabs:Select(1)

Se usa UIPanelButtonTemplate y no las plantillas de pestaña de Blizzard
porque estas cambian de nombre según el cliente; un botón normal existe en
todos.
]]

local _, ns = ...
local UI = ns.Const.UI

local TabBar = {}
ns.TabBar = TabBar

local methods = {}

function methods:Select(index)
    for i, b in ipairs(self.buttons) do
        b:SetEnabled(i ~= index)
    end
    self.selected = index
    self.onSelect(index)
end

-- Con nombre global si la ventana lo tiene (<Ventana>Tab1, Tab2...): así lo
-- encuentran otros addons y las pruebas.
local function createButton(bar, parent, i, title)
    local name = parent:GetName() and (parent:GetName() .. "Tab" .. i) or nil
    local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    b:SetSize(UI.TAB_WIDTH, UI.TAB_HEIGHT)
    b:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", UI.PADDING + (i - 1) * (UI.TAB_WIDTH + UI.TAB_GAP), 0)
    b:SetText(title)
    b:SetScript("OnClick", function() bar:Select(i) end)
    return b
end

function TabBar.Create(parent, titles, onSelect)
    local bar = { buttons = {}, onSelect = onSelect }
    for name, fn in pairs(methods) do bar[name] = fn end
    for i, title in ipairs(titles) do
        bar.buttons[i] = createButton(bar, parent, i, title)
    end
    return bar
end
