--[[
Atajos de los huecos
====================

Traduce un número de hueco a su atajo, en el formato que entiende WoW y en el
que se le enseña al jugador. Todo el addon pasa por aquí para que el atajo se
defina una sola vez (ver Const.KEY_MODIFIERS).
]]

local _, ns = ...
local Const = ns.Const

local Keys = {}
ns.Keys = Keys

-- "ALT-CTRL-SHIFT-F3", para SetOverrideBinding*.
function Keys.For(n)
    return Const.KEY_MODIFIERS .. "F" .. n
end

-- "Ctrl+Alt+Mayús+F3", para mensajes y tooltips.
function Keys.Label(n)
    return Const.KEY_MODIFIERS_LABEL .. "F" .. n
end
