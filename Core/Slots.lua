--[[
Huecos
======

Lógica de qué hay en cada hueco, sin tocar todavía los atajos:

  Entry(n)          definición del hueco (la del jugador o la de por defecto)
  Resolve(entry)    qué se puede asignar ahora mismo con esa definición
  Snapshot(e, res)  la "foto" que se guarda para el plugin
  Set(n, entry)     cambiar un hueco desde la ventana

Una "resolución" es una tabla { kind, target, loaded, id, icon, available }:
  kind       "spell" | "item" | "macro"
  target     lo que se pasa a SetOverrideBinding* (nombre del hechizo/objeto/macro)
  loaded     (solo objetos) false si sus datos aún no han llegado: target es
             entonces "item:N", válido para asignar pero no para enseñar
  id         ID de hechizo u objeto (el plugin lo usa para descargar el icono)
  icon       ID del archivo de icono (lo usa la ventana)
  available  si el jugador lo tiene ahora mismo (hechizo aprendido, objeto en
             las bolsas). Lo que no tiene se pinta en gris y sale en rojo en /sdeck.
]]

local _, ns = ...
local Const, Util, Api, Defaults, Storage = ns.Const, ns.Util, ns.Api, ns.Defaults, ns.Storage

local Slots = {}
ns.Slots = Slots

--------------------------------------------------------------------------------
-- Construcción de resoluciones
--------------------------------------------------------------------------------

local function hasItem(id)
    return Api.ItemCount(id) > 0
end

-- Asignamos hechizos por nombre y no por ID: con el nombre sin rango WoW lanza
-- siempre el rango más alto que tengas, y la tecla sigue valiendo al subir.
-- (Sin verificar en Forever, que se basa en el cliente moderno.)
local function spellResolution(id)
    local name = Api.SpellName(id)
    return name and { kind = "spell", target = name, id = id, icon = Api.SpellIcon(id),
                      available = Api.IsSpellKnown(id) }
end

local function itemResolution(id)
    local name, loaded = Api.ItemName(id)
    return { kind = "item", target = name, loaded = loaded, id = id, icon = Api.ItemIcon(id),
             available = hasItem(id) }
end

--------------------------------------------------------------------------------
-- Resolutores por tipo de entrada
--------------------------------------------------------------------------------
-- Una función por cada forma de definir un hueco. Añadir un tipo nuevo es
-- añadir una entrada a estas tablas, sin tocar el resto.

-- Tipo de una entrada: las del jugador llevan "kind"; las de por defecto, la
-- lista que usan (spells, items o names).
local function entryType(e)
    return e.kind or (e.spells and "spells") or (e.items and "items") or (e.names and "names")
end

local resolvers = {
    -- Elegidos por el jugador: se asignan aunque aún no los tenga, para que la
    -- tecla funcione en cuanto lo aprenda o lo consiga; "available" indica si
    -- ya lo tiene.
    spell = function(e) return spellResolution(e.id) end,
    item  = function(e) return itemResolution(e.id) end,
    macro = function(e)
        local name, icon = Api.MacroInfo(e.name)
        return name and { kind = "macro", target = name, icon = icon, available = true }
    end,
    -- Valores por defecto: el primero disponible de la lista (si no hay
    -- ninguno, no se asigna nada).
    spells = function(e) return Util.FirstMatch(e.spells, Api.IsSpellKnown, spellResolution) end,
    items  = function(e) return Util.FirstMatch(e.items, hasItem, itemResolution) end,
    names  = function(e)
        for _, name in ipairs(e.names) do
            local id, found, icon = Api.FindSpellByName(name)
            if id then return { kind = "spell", target = found, id = id, icon = icon, available = true } end
        end
    end,
}

-- Si un hueco aún no está disponible, qué icono enseñar (en gris) para que la
-- Stream Deck no lo muestre vacío. De las listas, el más básico (el último).
local placeholders = {
    spell  = function(e) return "spell", e.id end,
    item   = function(e) return "item", e.id end,
    spells = function(e) return "spell", e.spells[#e.spells] end,
    items  = function(e) return "item", e.items[#e.items] end,
}

--------------------------------------------------------------------------------
-- API del módulo
--------------------------------------------------------------------------------

-- Definición del hueco n y si es personalizada. custom[n] tiene tres estados
-- (ver Storage.lua), por eso se compara con nil y no se usa "or".
function Slots.Entry(n)
    local custom = Storage.GetCustom(n)
    if custom ~= nil then return custom or nil, true end
    return Defaults.For(Api.PlayerClass(), n), false
end

-- Resolución de una entrada, o nil si ahora mismo no hay nada asignable.
function Slots.Resolve(entry)
    if not entry then return end
    local resolve = resolvers[entryType(entry)]
    return resolve and resolve(entry) or nil
end

-- Foto del hueco para el plugin. Casos: vacío, asignado (disponible o todavía
-- no) y sin nada asignable (con icono de reserva para pintarlo en gris).
function Slots.Snapshot(entry, res)
    if not entry then
        return { active = false, empty = true }
    end
    if res then
        -- Un objeto que aún no ha cargado se asigna como "item:N", pero ese
        -- texto no se enseña: sin nombre, el plugin pinta solo el icono.
        local name = res.loaded ~= false and res.target or nil
        return { active = res.available == true, kind = res.kind, id = res.id, icon = res.icon,
                 name = name, short = entry.short or name }
    end
    local placeholder = placeholders[entryType(entry)]
    local kind, id
    if placeholder then kind, id = placeholder(entry) end
    return { active = false, kind = kind, id = id, name = entry.short or entry.name, short = entry.short }
end

-- entry: tabla (asignar), false (vaciar) o nil (volver al valor por defecto).
function Slots.Set(n, entry)
    Storage.SetCustom(n, entry)
    Util.Fire(Const.MSG.SLOT_CHANGED, n)
end

Slots.IsCustom = Storage.IsCustom
Slots.Get = Storage.GetSnapshot
