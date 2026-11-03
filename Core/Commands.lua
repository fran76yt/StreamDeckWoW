--[[
Comandos de chat
================

  /sdeck          estado de las 12 teclas
  /sdeck config   abrir o cerrar la ventana de configuración
  /sdeck ayuda    lista de comandos

Cada subcomando es una función en la tabla "commands": añadir uno nuevo es
añadir una entrada.
]]

local _, ns = ...
local Const, Util, Keys, Slots, Bindings = ns.Const, ns.Util, ns.Keys, ns.Slots, ns.Bindings

--------------------------------------------------------------------------------
-- Resumen al entrar
--------------------------------------------------------------------------------
-- La primera vez que se asignan los huecos tras entrar, un resumen en el chat.
local reported = false
Util.Listen(Const.MSG.SLOTS_UPDATED, function(ready)
    if reported then return end
    reported = true
    Util.Print("%d de %d teclas listas. /sdeck para ver el detalle, /sdeck config para cambiarlas.", ready, Const.NUM_SLOTS)
end)

--------------------------------------------------------------------------------
-- Subcomandos
--------------------------------------------------------------------------------

-- Línea de estado de un hueco: lo asignado, lo que falta o vacío.
local function statusLine(n)
    local target = Bindings.Target(n)
    if target then return target end
    local entry = Slots.Entry(n)
    if entry then
        return Util.Colorize(Const.CHAT_COLOR.MISSING, (entry.short or entry.name or "?") .. ": no lo tienes")
    end
    return Util.Colorize(Const.CHAT_COLOR.EMPTY, "vacío")
end

local commands = {}

function commands.estado()
    Bindings.Refresh()
    Util.Print("estado de las teclas:")
    for n = 1, Const.NUM_SLOTS do
        print(("  %s  ->  %s"):format(Keys.Label(n), statusLine(n)))
    end
end

function commands.config()
    ns.ConfigWindow.Toggle()
end

function commands.ayuda()
    Util.Print("versión %s. Comandos:", ns.Api.AddOnVersion())
    print("  /sdeck  -  estado de las teclas")
    print("  /sdeck config  -  configurar los huecos")
end

-- Sin argumentos: el estado.
commands[""] = commands.estado

--------------------------------------------------------------------------------
-- Registro del comando
--------------------------------------------------------------------------------
-- WoW registra comandos con la convención SLASH_<NOMBRE>1 + SlashCmdList.<NOMBRE>.
SLASH_STREAMDECKWOW1 = "/sdeck"
SlashCmdList.STREAMDECKWOW = function(msg)
    local name = (msg or ""):match("^%s*(%S*)"):lower()
    local run = commands[name] or commands.ayuda
    run()
end
