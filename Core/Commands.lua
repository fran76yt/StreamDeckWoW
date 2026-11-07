--[[
Comandos de chat
================

  /sdeck           estado de todas las teclas (igual que /sdeck estado)
  /sdeck estado    estado de todas las teclas
  /sdeck config    abrir o cerrar la ventana de configuración
  /sdeck minimapa  ocultar o mostrar el botón del minimapa
  /sdeck aviso     apagar o encender el aviso del taunt de la mascota
  /sdeck municion  apagar o encender el aviso de munición baja
  /sdeck ayuda     versión y lista de comandos (también con cualquier otro texto)

Cada subcomando es una función en la tabla "commands": añadir uno nuevo es
añadir una entrada.
]]

local _, ns = ...
local Const, Util, Keys, Slots, Bindings = ns.Const, ns.Util, ns.Keys, ns.Slots, ns.Bindings

--------------------------------------------------------------------------------
-- Resumen al entrar
--------------------------------------------------------------------------------
-- La primera vez que se asignan los huecos tras entrar, un resumen en el chat.
-- "ready" cuenta los huecos asignados y disponibles.
local reported = false
Util.Listen(Const.MSG.SLOTS_UPDATED, function(ready)
    if reported then return end
    reported = true
    Util.Print("%d de %d teclas listas. /sdeck para ver el detalle, /sdeck config para cambiarlas.", ready, Const.NUM_SLOTS)
end)

--------------------------------------------------------------------------------
-- Subcomandos
--------------------------------------------------------------------------------

local function missing(label)
    return Util.Colorize(Const.COLOR.MISSING, label .. ": no lo tienes")
end

-- Texto legible de lo asignado: el nombre de la foto, o si es un objeto cuyos
-- datos aún no han llegado (se asignó como "item:N"), un aviso de que carga.
local function assignedLabel(target, snapshot)
    if snapshot and snapshot.name then return snapshot.name end
    local itemID = target:match("^item:(%d+)$")
    return itemID and ("objeto " .. itemID .. " (cargando datos)") or target
end

-- Línea de estado de un hueco: lo asignado, lo asignado que aún no tienes,
-- lo que falta o vacío.
local function statusLine(n)
    local target = Bindings.Target(n)
    local snapshot = Slots.Get(n)
    if target then
        local label = assignedLabel(target, snapshot)
        if snapshot and snapshot.active then return label end
        return missing(label)
    end
    local entry = Slots.Entry(n)
    if entry then return missing(entry.short or entry.name or "?") end
    return Util.Colorize(Const.COLOR.EMPTY, "vacío")
end

local commands = {}

function commands.estado()
    Bindings.Refresh()
    -- En combate el recálculo se aplaza: lo que se lista es lo último asignado.
    local note = Util.InCombat() and " (en combate: se actualizará al terminar)" or ""
    Util.Print("estado de las teclas%s:", note)
    for n = 1, Const.NUM_SLOTS do
        print(("  %s  ->  %s"):format(Keys.Label(n), statusLine(n)))
    end
end

function commands.config()
    ns.ConfigWindow.Toggle()
end

function commands.minimapa()
    local shown = ns.MinimapButton.ToggleShown()
    Util.Print(shown and "botón del minimapa visible." or "botón del minimapa oculto. /sdeck minimapa para recuperarlo.")
end

function commands.aviso()
    local on = ns.PetTaunt.Toggle()
    Util.Print(on and "aviso del taunt de la mascota encendido." or "aviso del taunt de la mascota apagado. /sdeck aviso para volver a encenderlo.")
end

function commands.municion()
    local on = ns.Ammo.Toggle()
    Util.Print(on and "aviso de munición baja encendido." or "aviso de munición baja apagado. /sdeck municion para volver a encenderlo.")
end

function commands.ayuda()
    Util.Print("versión %s. Comandos:", ns.Api.AddOnVersion())
    print("  /sdeck  -  estado de las teclas (también /sdeck estado)")
    print("  /sdeck config  -  configurar los huecos (también con clic en el botón del minimapa)")
    print("  /sdeck minimapa  -  ocultar o mostrar el botón del minimapa")
    print("  /sdeck aviso  -  apagar o encender el aviso del taunt de la mascota")
    print("  /sdeck municion  -  apagar o encender el aviso de munición baja")
    print("  /sdeck ayuda  -  esta ayuda")
end

-- Sin argumentos: el estado.
commands[""] = commands.estado

--------------------------------------------------------------------------------
-- Registro del comando
--------------------------------------------------------------------------------
-- Ejecuta el subcomando escrito tras /sdeck. Un subcomando desconocido
-- muestra la ayuda. Se publica en ns para que otras partes de la interfaz
-- (el botón del minimapa) lancen los mismos comandos sin repetir su código.
local Commands = {}
ns.Commands = Commands

function Commands.Run(msg)
    local name = (msg or ""):match("^%s*(%S*)"):lower()
    local run = commands[name] or commands.ayuda
    run()
end

-- WoW registra comandos con la convención SLASH_<NOMBRE>1 + SlashCmdList.<NOMBRE>.
SLASH_STREAMDECKWOW1 = "/sdeck"
SlashCmdList.STREAMDECKWOW = Commands.Run
