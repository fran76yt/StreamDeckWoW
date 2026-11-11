--[[
Utilidades genéricas
====================

Archivo compartido con StreamDeckWoW: se edita en FranTools y se copia con
tools/sync_shared.py.

Piezas que servirían igual en cualquier otro addon: eventos, mensajes entre módulos, agrupar llamadas, esperar a salir
de combate, buscar en listas y escribir en el chat.
]]

local _, ns = ...
local Const = ns.Const

local Util = {}
ns.Util = Util

--------------------------------------------------------------------------------
-- Eventos de WoW
--------------------------------------------------------------------------------
-- En WoW los eventos se reciben a través de un frame. En lugar de que cada
-- módulo cree el suyo, usamos uno solo y una tabla evento -> funciones. Así
-- cualquier módulo se suscribe con una línea: Util.On("PLAYER_LOGIN", fn).

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function Util.On(event, fn)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        eventFrame:RegisterEvent(event)   -- solo escuchamos lo que alguien usa
    end
    table.insert(eventHandlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(eventHandlers[event]) do fn(...) end
end)

--------------------------------------------------------------------------------
-- Mensajes internos
--------------------------------------------------------------------------------
-- El mismo patrón para avisos entre módulos del addon. Permite que, por
-- ejemplo, la ventana se entere de que los huecos han cambiado sin que el
-- núcleo tenga que conocer la ventana (y sin dependencias circulares).

local listeners = {}

function Util.Listen(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function Util.Fire(message, ...)
    for _, fn in ipairs(listeners[message] or {}) do fn(...) end
end

--------------------------------------------------------------------------------
-- Control de tiempo y de combate
--------------------------------------------------------------------------------

-- Ejecuta fn dentro de "delay" segundos.
function Util.After(delay, fn)
    C_Timer.After(delay, fn)
end

-- Devuelve una versión de fn que, por muchas veces que se llame seguidas,
-- solo se ejecuta una vez, "delay" segundos después de la primera llamada.
function Util.Debounce(delay, fn)
    local queued = false
    return function()
        if queued then return end
        queued = true
        Util.After(delay, function()
            queued = false
            fn()
        end)
    end
end

-- Durante el combate WoW bloquea los cambios de atajos y de acciones
-- protegidas. Esto ejecuta fn ya si se puede o, si no, al salir de combate.
-- Las peticiones se guardan por función, así que pedir lo mismo diez veces en
-- combate lo ejecuta una sola vez al terminar.
local deferred = {}

function Util.InCombat()
    return InCombatLockdown()
end

function Util.OutOfCombat(fn)
    if not Util.InCombat() then
        fn()
    else
        deferred[fn] = true
    end
end

-- Al salir de combate se ejecuta lo pendiente. Cada función va protegida: si
-- una falla, WoW muestra el error con su manejador habitual y las demás se
-- ejecutan igualmente.
Util.On("PLAYER_REGEN_ENABLED", function()
    for fn in pairs(deferred) do
        deferred[fn] = nil
        xpcall(fn, geterrorhandler())
    end
end)

--------------------------------------------------------------------------------
-- Listas y texto
--------------------------------------------------------------------------------

-- Devuelve build(v) del primer elemento de la lista que cumple test(v).
function Util.FirstMatch(list, test, build)
    for _, v in ipairs(list) do
        if test(v) then return build(v) end
    end
end

-- Parte una lista en trozos de "size" elementos (el último puede ser menor).
function Util.Chunk(list, size)
    local chunks = {}
    for i, v in ipairs(list) do
        local n = math.floor((i - 1) / size) + 1
        chunks[n] = chunks[n] or {}
        table.insert(chunks[n], v)
    end
    return chunks
end

-- Textura dentro de un texto (|T ruta:alto:ancho|t), como icono delante de
-- una etiqueta. Sirve con rutas y con IDs de archivo.
function Util.IconText(icon, size)
    return ("|T%s:%d:%d|t"):format(tostring(icon), size, size)
end

-- Guarda en t[key] un valor elegido por el jugador solo si difiere del valor
-- por defecto; si coincide, lo borra. Así el archivo solo lleva lo cambiado y
-- un cambio del valor por defecto en una versión nueva llega a quien no lo
-- había tocado. (No vale "t[key] = v ~= default and v or nil": con v = false
-- guardaría nil.)
function Util.SetOverride(t, key, value, default)
    if value == default then
        t[key] = nil
    else
        t[key] = value
    end
end

-- Invierte un indicador de una tabla y devuelve si queda activado. Guarda nil
-- en vez de false para que las SavedVariables solo lleven lo que se ha cambiado.
function Util.ToggleFlag(t, key)
    t[key] = not t[key] or nil
    return t[key] == true
end

-- Interruptor de una función opcional (avisos...), encendida por defecto. Se
-- guarda como settings().off para que el archivo solo lleve las que se han
-- apagado. onChange(on) se llama tras cada cambio, y se anuncia
-- SETTINGS_CHANGED para que la ventana ponga al día sus casillas aunque el
-- cambio venga de un comando. Devuelve { IsEnabled, SetEnabled, Toggle }.
function Util.Switch(settings, onChange)
    local switch = {}
    function switch.IsEnabled()
        return not settings().off
    end
    function switch.SetEnabled(on)
        settings().off = (not on) or nil
        onChange(on)
        Util.Fire(Const.MSG.SETTINGS_CHANGED)
    end
    -- Devuelve true si queda encendida.
    function switch.Toggle()
        switch.SetEnabled(not switch.IsEnabled())
        return switch.IsEnabled()
    end
    return switch
end

-- Texto en color para el chat.
function Util.Colorize(hex, text)
    return "|cff" .. hex .. text .. "|r"
end

-- Mensaje en el chat con el prefijo del addon. Acepta formato como string.format.
function Util.Print(fmt, ...)
    print(Const.CHAT_PREFIX .. ": " .. fmt:format(...))
end
