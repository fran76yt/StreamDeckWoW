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
             de leer desde fuera del juego. Es un contrato con el plugin
             (bin/lib/slotAction.js); campos:
               active  true si se puede usar ahora (lo tienes)
               empty   true si el hueco está vacío (entonces no hay más campos)
               kind    "spell" | "item" | "macro" (o nil si no hay nada asignable)
               id      ID de hechizo u objeto, para descargar su icono
               icon    ID del archivo de icono del juego (lo usa la ventana)
               name    nombre legible (nil si un objeto aún no ha cargado)
               short   texto corto para la tecla
  class      clase del personaje, informativa.
  updated    momento de la última actualización (segundos desde 1970).
  minimap    preferencias del botón del minimapa (el plugin no las lee):
               angle   posición alrededor del minimapa, en grados
                       (nil -> la de por defecto)
               hidden  true si el jugador lo ha ocultado con /sdeck minimapa
  petTaunt   preferencias del aviso del taunt de la mascota (tampoco las lee):
               off     true si el jugador lo ha apagado con /sdeck aviso
  ammo       preferencias del aviso de munición baja (tampoco las lee):
               off     true si el jugador lo ha apagado
               point   posición del recuadro: { punto, punto relativo, x, y }
                       (nil -> la de por defecto)
               thresholds  umbrales cambiados por el jugador, por tipo:
                       { arrow = { low = 300, critical = 80 }, bullet = {...} }
                       (los que no están usan los de Const.AMMO.TYPES)
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

-- Tabla de preferencias de una parte del addon, creada si no existe. Devuelve
-- la tabla misma (no una copia): quien la recibe la modifica y WoW la guardará
-- con el resto al escribir las SavedVariables.
local function section(key)
    local d = db()
    d[key] = d[key] or {}
    return d[key]
end

function Storage.GetMinimap()
    return section("minimap")
end

function Storage.GetPetTaunt()
    return section("petTaunt")
end

function Storage.GetAmmo()
    return section("ammo")
end
