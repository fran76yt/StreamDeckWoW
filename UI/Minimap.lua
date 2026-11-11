--[[
Botón del minimapa de StreamDeckWoW
===================================

El botón compartido (UI/MinimapButton.lua) con lo propio de este addon:
  clic             abrir o cerrar la ventana de configuración
  clic derecho     estado de las teclas en el chat (como /sdeck)
  arrastrar        moverlo alrededor del minimapa
  /sdeck minimapa  ocultarlo o volver a mostrarlo
]]

local _, ns = ...

ns.Minimap = ns.MinimapButton.Create({
    settings = ns.Storage.GetMinimap,
    tooltip = {
        ns.Const.UI.TITLE,
        "Clic: configurar las teclas",
        "Clic derecho: estado de las teclas",
        "Arrastrar: mover este botón",
        "/sdeck minimapa: ocultarlo",
    },
    -- Los módulos se buscan en ns al hacer clic: la ventana y los comandos se
    -- cargan después.
    onClick = {
        LeftButton = function() ns.ConfigWindow.Toggle() end,
        RightButton = function() ns.Commands.Run("estado") end,
    },
})
