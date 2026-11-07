--[[
Barra lateral de navegación
===========================

Una columna a la izquierda de una ventana con una entrada por página, como
las listas de categorías de las opciones del juego. Las entradas seguidas con
el mismo "group" se agrupan bajo un título con ese nombre (y su color, si lo
trae), con sangría. La entrada elegida se marca con fondo y raya dorados.

  local nav = ns.Sidebar.Create(window, {
      { title = "Teclas" },
      { title = "Mascota", group = "Cazador", groupColor = { r, g, b } },
      { title = "Munición", group = "Cazador", groupColor = { r, g, b } },
  }, function(i) ... end)   -- se llama al elegir la entrada i
  nav:Select(1)

Todo se dibuja con texturas de color liso, sin plantillas de Blizzard, que
cambian de nombre y de aspecto según el cliente.
]]

local _, ns = ...
local NAV = ns.Const.UI.NAV

local Sidebar = {}
ns.Sidebar = Sidebar

--------------------------------------------------------------------------------
-- Piezas
--------------------------------------------------------------------------------

-- Textura de color liso. Sin puntos de anclaje ocupa todo el marco.
local function colorTexture(parent, layer, color)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(unpack(color))
    return t
end

-- Fondo oscuro y una línea fina a la derecha que separa del contenido.
local function createBackground(bar)
    colorTexture(bar, "BACKGROUND", NAV.BACKGROUND_COLOR):SetAllPoints()
    local line = colorTexture(bar, "BORDER", NAV.DIVIDER_COLOR)
    line:SetWidth(NAV.DIVIDER_WIDTH)
    line:SetPoint("TOPRIGHT")
    line:SetPoint("BOTTOMRIGHT")
end

-- Título de un grupo. Devuelve la altura (y) por la que sigue la lista.
local function createHeader(bar, entry, y)
    y = y - NAV.HEADER_GAP
    local header = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("LEFT", bar, "TOPLEFT", NAV.TEXT_LEFT, y - NAV.ENTRY_HEIGHT / 2)
    header:SetText(entry.group)
    if entry.groupColor then header:SetTextColor(unpack(entry.groupColor)) end
    return y - NAV.ENTRY_HEIGHT - NAV.ENTRY_GAP
end

-- Con nombre global si la ventana lo tiene (<Ventana>Nav1, Nav2...): así lo
-- encuentran otros addons y las pruebas.
local function entryName(bar, index)
    local parentName = bar:GetParent():GetName()
    return parentName and (parentName .. "Nav" .. index) or nil
end

-- Entrada pulsable: fondo al pasar el ratón (capa HIGHLIGHT, que el juego
-- muestra sola) y fondo y raya que se encienden al elegirla.
local function createEntry(bar, entry, index, y)
    local b = CreateFrame("Button", entryName(bar, index), bar)
    b:SetHeight(NAV.ENTRY_HEIGHT)
    b:SetPoint("TOPLEFT", 0, y)
    b:SetPoint("TOPRIGHT", -NAV.DIVIDER_WIDTH, y)
    colorTexture(b, "HIGHLIGHT", NAV.HOVER_COLOR):SetAllPoints()
    b.selection = colorTexture(b, "BACKGROUND", NAV.SELECTED_COLOR)
    b.selection:SetAllPoints()
    b.accent = colorTexture(b, "ARTWORK", NAV.ACCENT_COLOR)
    b.accent:SetWidth(NAV.ACCENT_WIDTH)
    b.accent:SetPoint("TOPLEFT")
    b.accent:SetPoint("BOTTOMLEFT")
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", entry.group and NAV.INDENT or NAV.TEXT_LEFT, 0)
    b.label:SetText(entry.title)
    b:SetScript("OnClick", function() bar:Select(index) end)
    return b
end

local function setSelected(b, on)
    b.selection:SetShown(on)
    b.accent:SetShown(on)
    b.label:SetTextColor(unpack(on and NAV.SELECTED_TEXT_COLOR or NAV.TEXT_COLOR))
end

--------------------------------------------------------------------------------
-- API del componente
--------------------------------------------------------------------------------

local methods = {}

function methods:Select(index)
    for i, b in ipairs(self.entries) do setSelected(b, i == index) end
    self.selected = index
    self.onSelect(index)
end

-- Ancho total que ocupa la barra desde el borde de la ventana.
function Sidebar.Width()
    return NAV.LEFT + NAV.WIDTH
end

function Sidebar.Create(parent, entries, onSelect)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(NAV.WIDTH)
    bar:SetPoint("TOPLEFT", NAV.LEFT, NAV.TOP)
    bar:SetPoint("BOTTOMLEFT", NAV.LEFT, NAV.BOTTOM)
    for name, fn in pairs(methods) do bar[name] = fn end
    bar.entries, bar.onSelect = {}, onSelect
    createBackground(bar)

    local y, group = -NAV.FIRST_GAP, nil
    for i, entry in ipairs(entries) do
        if entry.group and entry.group ~= group then y = createHeader(bar, entry, y) end
        group = entry.group
        bar.entries[i] = createEntry(bar, entry, i, y)
        y = y - NAV.ENTRY_HEIGHT - NAV.ENTRY_GAP
    end
    return bar
end
