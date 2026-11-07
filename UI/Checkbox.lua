--[[
Casilla de verificación
=======================

Componente reutilizable: una casilla con texto a la derecha y tooltip, que
lee su estado de una función y lo escribe en otra. No guarda nada por sí
misma; así la verdad está siempre en el módulo que la usa y la casilla solo
la refleja.

  local check = ns.Checkbox.Create(parent, {
      label = "Texto",
      tooltip = { "Título", "Línea de ayuda", ... },
      get = function() return valor end,
      set = function(valor) ... end,
  })
  check:Update()   -- vuelve a leer el estado (por ejemplo, al abrir la ventana)
]]

local _, ns = ...
local Const = ns.Const
local UI = Const.UI

local Checkbox = {}
ns.Checkbox = Checkbox

-- Métodos que se copian en cada casilla.
local methods = {}

function methods:Update()
    self:SetChecked(self.opts.get() and true or false)
end

local function onClick(self)
    self.opts.set(self:GetChecked() and true or false)
    -- Se vuelve a leer: si el módulo no aceptó el cambio, la casilla no miente.
    self:Update()
end

local function showTooltip(self)
    local lines = self.opts.tooltip
    if not lines then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(lines[1])
    for i = 2, #lines do
        GameTooltip:AddLine(lines[i], unpack(UI.TOOLTIP_HELP_COLOR))
    end
    GameTooltip:Show()
end

-- La plantilla de Blizzard trae su propio texto (.Text) en el cliente moderno;
-- si no, se crea uno al lado de la casilla.
local function setLabel(cb, text)
    local label = cb.Text
    if not label then
        label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", cb, "RIGHT", UI.CHECK_LABEL_GAP, 0)
    end
    label:SetText(text)
end

function Checkbox.Create(parent, opts)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(UI.CHECK_SIZE, UI.CHECK_SIZE)
    cb.opts = opts
    for name, fn in pairs(methods) do cb[name] = fn end
    setLabel(cb, opts.label)
    cb:SetScript("OnClick", onClick)
    cb:SetScript("OnEnter", showTooltip)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    cb:Update()
    return cb
end
