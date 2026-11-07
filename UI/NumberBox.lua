--[[
Caja numérica
=============

Componente reutilizable: una caja de texto que solo admite cifras, para
valores como umbrales. Igual que la casilla, no guarda nada: lee el valor con
get y lo entrega con set, y después vuelve a leerlo, así que si el módulo lo
ajusta (por ejemplo, porque se sale de rango) la caja muestra el valor real.

  local box = ns.NumberBox.Create(parent, {
      get = function() return valor end,
      set = function(numero) ... end,
      tooltip = { "Título", "Ayuda" },
      maxDigits = 4,   -- opcional; por defecto UI.NUMBER_MAX_DIGITS
  })

El valor se aplica al pulsar Intro o al salir de la caja (clic fuera, Tab).
Escape descarta lo escrito y deja el valor que había.
]]

local _, ns = ...
local UI = ns.Const.UI

local NumberBox = {}
ns.NumberBox = NumberBox

local methods = {}

-- Mientras el jugador escribe no se le cambia el texto bajo los dedos.
function methods:Update()
    if self:HasFocus() then return end
    self:SetText(tostring(self.opts.get()))
end

local function commit(self)
    local value = tonumber(self:GetText())
    if value then self.opts.set(value) end
    self:Update()
end

-- Intro y Escape solo sueltan el foco; aplicar o descartar lo hace
-- OnEditFocusLost, que también salta con clic fuera, así cada camino pasa
-- por el mismo sitio.
local function onEscape(self)
    self.discard = true
    self:ClearFocus()
end

local function onFocusLost(self)
    if self.discard then
        self.discard = nil
        self:Update()
    else
        commit(self)
    end
end

function NumberBox.Create(parent, opts)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(UI.NUMBER_BOX_WIDTH, UI.NUMBER_BOX_HEIGHT)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(opts.maxDigits or UI.NUMBER_MAX_DIGITS)
    box:SetJustifyH("CENTER")
    box.opts = opts
    for name, fn in pairs(methods) do box[name] = fn end
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", onEscape)
    box:SetScript("OnEditFocusLost", onFocusLost)
    ns.Tooltip.Attach(box, opts.tooltip)
    box:Update()
    return box
end
