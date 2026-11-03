--[[
Almacenamiento (SavedVariables)
===============================

Único módulo que toca la variable guardada StreamDeckWoWChar (declarada en el
.toc como SavedVariablesPerCharacter). WoW la carga desde disco antes de
PLAYER_LOGIN y la escribe al hacer /reload, al cerrar sesión o al salir.

Estructura:
  custom[n]  lo que el jugador ha puesto en el hueco n:
               nil   -> no lo ha tocado (se usa el valor por defecto)
               false -> lo vació a propósito
               tabla -> entrada elegida ({ kind = "spell", id = ... }, etc.)
  slots[n]   "foto" de cada hueco ya resuelto, para el plugin de Stream Deck.
             Solo tipos simples (texto, número, booleano) para que sea fácil
             de leer desde fuera del juego.
  class      clase del personaje, informativa.
  updated    momento de la última actualización (segundos desde 1970).
]]

local _, ns = ...

local Storage = {}
ns.Storage = Storage

-- La primera vez que se usa el addon la variable no existe: la creamos.
local function db()
    StreamDeckWoWChar = StreamDeckWoWChar or {}
    StreamDeckWoWChar.custom = StreamDeckWoWChar.custom or {}
    return StreamDeckWoWChar
end

function Storage.GetCustom(n)
    return db().custom[n]
end

function Storage.SetCustom(n, entry)
    db().custom[n] = entry
end

function Storage.IsCustom(n)
    return db().custom[n] ~= nil
end

function Storage.SaveSnapshot(slots, class)
    local d = db()
    d.slots, d.class, d.updated = slots, class, time()
end

function Storage.GetSnapshot(n)
    local slots = db().slots
    return slots and slots[n]
end
