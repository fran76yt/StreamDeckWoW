--[[
Tooltips de ayuda
=================

Parte de FranLib (ver Config.lua): se edita en el repositorio FranLib y se
copia a cada addon con su tools/sync.py.

Los componentes de la interfaz (casillas, cajas, recuadros, botón del
minimapa) muestran el mismo tipo de tooltip: un título y unas líneas de ayuda
en gris. Esta función lo hace una vez para todos.

  ns.Tooltip.Attach(frame, { "Título", "Ayuda", ... }, "ANCHOR_RIGHT")
]]

local _, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

-- Color de las líneas de ayuda, para quien pinte un tooltip a su manera.
Tooltip.HELP_COLOR = ns.FranLib.Const.TOOLTIP_HELP_COLOR

function Tooltip.Show(owner, lines, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(lines[1])
    for i = 2, #lines do
        GameTooltip:AddLine(lines[i], unpack(Tooltip.HELP_COLOR))
    end
    GameTooltip:Show()
end

-- Muestra el tooltip al pasar el ratón por encima del marco y lo oculta al salir.
function Tooltip.Attach(frame, lines, anchor)
    if not lines then return end
    frame:SetScript("OnEnter", function(self) Tooltip.Show(self, lines, anchor) end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end
