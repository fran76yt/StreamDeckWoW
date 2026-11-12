--[[
Registro de errores
===================

Archivo compartido con StreamDeckWoW: se edita en FranTools y se copia con
tools/sync_shared.py.

Apunta los errores de Lua de este addon en una variable de la cuenta
(Const.ERROR_LOG.SAVED_VAR, declarada en el .toc como SavedVariables), para
poder verlos después con un comando aunque el juego tenga apagados los avisos
de error (lo normal) o hayan salido con otro personaje.

Se engancha al manejador de errores del juego, que recibe los de todos los
addons: apunta solo los que pasan por archivos de este y entrega todos al
manejador que había, que sigue haciendo lo de siempre (la ventana de error
de Blizzard, BugSack...). Los errores de los eventos llegan aquí gracias a
Util.SafeCall; los de clics, temporizadores y comandos, directamente.

Cada error distinto se guarda una vez, con cuántas veces ha salido y la fecha
de la primera y de la última: en combate el mismo puede repetirse cientos de
veces. Como mucho se guardan MAX_ENTRIES; al pasarse, se borra el más antiguo.

  ErrorLog.Entries()       errores apuntados, del más antiguo al más nuevo
  ErrorLog.Clear()
  ErrorLog.Command(texto)  lo que hace el comando de chat (C.COMMAND):
                           "" lista, "<n>" uno con su pila, "borrar" vacía

Con un addon que se adueñe del manejador de errores (BugSack lo hace) puede
que aquí no llegue nada: entonces los errores se ven en ese addon.
]]

local _, ns = ...
local Const, Util, Api = ns.Const, ns.Util, ns.Api
local C = Const.ERROR_LOG

local ErrorLog = {}
ns.ErrorLog = ErrorLog

-- Ruta de los archivos de este addon en mensajes y pilas
-- ("Interface/AddOns/<addon>/...", con / o \ según el cliente).
local OWN_PATH = "Interface[/\\]AddOns[/\\]" .. Const.ADDON_NAME .. "[/\\]"

local previousHandler   -- el manejador que había antes que el nuestro
local pending = {}      -- errores de antes de que el juego cargue la variable
local loaded = false
local notified = false  -- el aviso en el chat sale una vez por sesión

--------------------------------------------------------------------------------
-- Datos guardados
--------------------------------------------------------------------------------

-- Lista de errores guardada. Hasta ADDON_LOADED la variable no está cargada
-- (lo que se escribiera en ella se perdería), y mientras tanto se usa pending.
local function entries()
    if not loaded then return pending end
    local log = _G[C.SAVED_VAR] or {}
    _G[C.SAVED_VAR] = log
    log.entries = log.entries or {}
    return log.entries
end

local function findEntry(list, message)
    for _, entry in ipairs(list) do
        if entry.message == message then return entry end
    end
end

-- Apunta un error: si ya estaba, suma una vez más. Devuelve true si es nuevo.
local function store(list, err)
    local entry = findEntry(list, err.message)
    if entry then
        entry.count = entry.count + (err.count or 1)
        entry.last = err.last
        return false
    end
    list[#list + 1] = err
    while #list > C.MAX_ENTRIES do table.remove(list, 1) end
    return true
end

--------------------------------------------------------------------------------
-- Captura
--------------------------------------------------------------------------------

-- Las líneas del propio registro no dicen nada del error: fuera de la pila.
local function cleanStack(stack)
    local lines = {}
    for line in stack:gmatch("[^\n]+") do
        if not line:find("ErrorLog%.lua") then lines[#lines + 1] = line end
    end
    return table.concat(lines, "\n"):sub(1, C.MAX_STACK_CHARS)
end

local function isOwn(message, stack)
    return message:find(OWN_PATH) ~= nil or stack:find(OWN_PATH) ~= nil
end

local function notify()
    if notified then return end
    notified = true
    Util.Print("se ha producido un error de Lua y queda apuntado. %s para verlo.", C.COMMAND)
end

local function record(message, stack)
    if not isOwn(message, stack) then return end
    local now = Api.Now()
    local isNew = store(entries(), {
        message = message,
        stack = cleanStack(stack),
        count = 1,
        first = now,
        last = now,
        version = Api.AddOnVersion(),
    })
    if isNew then notify() end
end

-- Manejador que se pone delante del que había. La pila se toma aquí, antes
-- de nada, porque es la del momento del error. Apuntarlo va protegido: un
-- fallo del registro no puede impedir que el error siga su camino.
local function onError(err, ...)
    pcall(record, tostring(err), Api.Stack(2))
    if previousHandler then return previousHandler(err, ...) end
end

previousHandler = Api.ErrorHandler()
Api.SetErrorHandler(onError)

-- El juego carga las SavedVariables después de leer todos los archivos del
-- addon: entonces se pasa a ellas lo que se haya apuntado mientras.
Util.On("ADDON_LOADED", function(name)
    if name ~= Const.ADDON_NAME or loaded then return end
    loaded = true
    local list = entries()
    for _, err in ipairs(pending) do store(list, err) end
    pending = {}
end)

--------------------------------------------------------------------------------
-- Consultar
--------------------------------------------------------------------------------

function ErrorLog.Entries()
    return entries()
end

function ErrorLog.Clear()
    local list = entries()
    for i = #list, 1, -1 do list[i] = nil end
end

-- Sin la ruta hasta la carpeta del addon, que es igual en todos y no cabe.
local function shortPath(text)
    return (text:gsub(OWN_PATH, ""))
end

local function printList()
    local list = entries()
    if #list == 0 then
        Util.Print("no hay errores apuntados.")
        return
    end
    Util.Print("%d errores apuntados (del más antiguo al más nuevo):", #list)
    for i, entry in ipairs(list) do
        print(("  %d. [%s] x%d  %s"):format(i, entry.last, entry.count, shortPath(entry.message)))
    end
    print(("  %s <número> para ver uno con su pila, %s borrar para vaciar la lista."):format(C.COMMAND, C.COMMAND))
end

local function printEntry(i)
    local entry = entries()[i]
    if not entry then
        Util.Print("no hay ningún error con el número %d.", i)
        return
    end
    Util.Print("error %d, versión %s, %d veces (primera %s, última %s):", i, entry.version, entry.count, entry.first, entry.last)
    print(shortPath(entry.message))
    for line in entry.stack:gmatch("[^\n]+") do
        print(Util.Colorize(C.STACK_COLOR, "  " .. shortPath(line)))
    end
end

function ErrorLog.Command(arg)
    arg = (arg or ""):lower()
    if arg == "borrar" then
        ErrorLog.Clear()
        Util.Print("lista de errores vaciada.")
    elseif tonumber(arg) then
        printEntry(tonumber(arg))
    else
        printList()
    end
end
