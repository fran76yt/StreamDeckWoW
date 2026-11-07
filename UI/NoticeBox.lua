--[[
Recuadro de aviso
=================

Componente reutilizable para avisos discretos: un marco pequeño con un icono y
una línea de texto, con el borde del color del nivel del aviso ("warning"
ámbar, "critical" rojo). No hace ruido ni ocupa el centro de la pantalla: está
ahí mientras dure el problema y desaparece solo.

El jugador lo puede arrastrar a donde le moleste menos; la posición se guarda
en la tabla de preferencias que pasa quien lo crea.

  local box = ns.NoticeBox.Create({
      name = "NombreGlobal",                 -- opcional
      settings = function() return tabla end, -- donde guardar la posición (campo point)
      tooltip = { "Título", "Ayuda", ... },
  })
  box:ShowNotice(icono, "texto", "warning")
  box:ShowIf(icono, textoONil, nivel)   -- muestra si hay texto; si no, oculta
  box:Hide()

Crearlo no toca la interfaz, así que se puede hacer al cargar el archivo.

El marco se crea al mostrar el primer aviso: si nunca hay nada que avisar, no
consume nada.
]]

local _, ns = ...
local Const = ns.Const
local N = Const.NOTICE

local NoticeBox = {}
ns.NoticeBox = NoticeBox

--------------------------------------------------------------------------------
-- Posición
--------------------------------------------------------------------------------

local function restorePoint(f, settings)
    local p = settings.point
    f:ClearAllPoints()
    if p then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        f:SetPoint(N.DEFAULT_POINT[1], UIParent, N.DEFAULT_POINT[1], N.DEFAULT_POINT[2], N.DEFAULT_POINT[3])
    end
end

-- StopMovingOrSizing deja el marco anclado donde se soltó; se guarda ese
-- anclaje (sin el marco relativo, que siempre es UIParent).
local function savePoint(f, settings)
    local point, _, relPoint, x, y = f:GetPoint()
    settings.point = { point, relPoint, x, y }
end

--------------------------------------------------------------------------------
-- Construcción
--------------------------------------------------------------------------------

-- En el cliente moderno los fondos con borde (SetBackdrop) solo existen si el
-- marco hereda de BackdropTemplate; en los antiguos venían de serie.
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local function applyBackdrop(f)
    if not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile = N.BACKGROUND,
        edgeFile = N.BORDER,
        edgeSize = N.BORDER_SIZE,
        insets = { left = N.INSET, right = N.INSET, top = N.INSET, bottom = N.INSET },
    })
    f:SetBackdropColor(unpack(N.BACKGROUND_COLOR))
end

local function makeMovable(f, opts)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePoint(self, opts.settings())
    end)
end

local function createContent(f)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(N.ICON_SIZE, N.ICON_SIZE)
    f.icon:SetPoint("LEFT", N.PADDING, 0)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("LEFT", f.icon, "RIGHT", N.PADDING, 0)
    f.text:SetPoint("RIGHT", -N.PADDING, 0)
    f.text:SetJustifyH("LEFT")
end

local function build(box)
    local opts = box.opts
    local f = CreateFrame("Frame", opts.name, UIParent, BACKDROP_TEMPLATE)
    f:SetSize(N.WIDTH, N.HEIGHT)
    f:SetFrameStrata("MEDIUM")
    f.opts = opts
    applyBackdrop(f)
    createContent(f)
    makeMovable(f, opts)
    ns.Tooltip.Attach(f, opts.tooltip, "ANCHOR_TOP")
    restorePoint(f, opts.settings())
    f:Hide()
    return f
end

--------------------------------------------------------------------------------
-- API del componente
--------------------------------------------------------------------------------

local methods = {}

function methods:ShowNotice(icon, text, level)
    self.frame = self.frame or build(self)
    local f = self.frame
    f.icon:SetTexture(icon)
    f.text:SetText(text)
    local color = N.LEVEL_COLOR[level] or N.LEVEL_COLOR.warning
    if f.SetBackdropBorderColor then f:SetBackdropBorderColor(unpack(color)) end
    f.text:SetTextColor(unpack(color))
    f:Show()
end

-- Muestra el aviso si hay texto y, si no, lo oculta: así quien lo usa no
-- repite el "si hay aviso, mostrar; si no, ocultar".
function methods:ShowIf(icon, text, level)
    if text then
        self:ShowNotice(icon, text, level)
    else
        self:Hide()
    end
end

function methods:Hide()
    if self.frame then self.frame:Hide() end
end

function methods:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

function NoticeBox.Create(opts)
    local box = { opts = opts }
    for name, fn in pairs(methods) do box[name] = fn end
    return box
end
