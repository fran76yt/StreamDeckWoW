--[[
Capa de acceso a la API de WoW
==============================

El resto del addon no llama directamente a la API del juego para hechizos,
objetos, macros o el cursor: pasa por estas funciones. Motivos:

  * WoW Forever usa el cliente moderno, donde muchas funciones globales
    clásicas se movieron a espacios de nombres (C_Spell, C_Item, C_SpellBook).
    Si Blizzard vuelve a mover algo, solo hay que tocar este archivo.
  * Cada función prueba primero la API moderna y cae a la clásica si no existe.
  * Para probar el addon fuera del juego basta con simular estas funciones.
]]

local _, ns = ...

local Api = {}
ns.Api = Api

--------------------------------------------------------------------------------
-- Addon
--------------------------------------------------------------------------------

-- Un campo del .toc ("Version", "Title"...). La versión solo se escribe allí.
function Api.AddOnMetadata(field)
    local f = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return f and f(ns.Const.ADDON_NAME, field)
end

function Api.AddOnVersion()
    return Api.AddOnMetadata("Version") or "?"
end

--------------------------------------------------------------------------------
-- Jugador
--------------------------------------------------------------------------------

-- true cuando el personaje ya ha cargado (después de PLAYER_LOGIN).
function Api.IsLoggedIn()
    return IsLoggedIn()
end

-- Clase en inglés y mayúsculas ("HUNTER"), que no depende del idioma. UnitClass
-- devuelve primero el nombre traducido ("Cazador") y después este.
function Api.PlayerClass()
    return select(2, UnitClass("player"))
end

--------------------------------------------------------------------------------
-- Hechizos
--------------------------------------------------------------------------------

function Api.IsSpellKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then return true end
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return IsSpellKnown and IsSpellKnown(id) or false
end

function Api.SpellName(id)
    return C_Spell.GetSpellName(id)
end

-- ID del archivo de icono (un número, no una ruta).
function Api.SpellIcon(id)
    return C_Spell.GetSpellTexture(id)
end

-- Busca un hechizo por nombre. Solo encuentra los que están en tu libro de
-- hechizos, que es justo lo que queremos. Devuelve id, nombre e icono.
function Api.FindSpellByName(name)
    local info = C_Spell.GetSpellInfo(name)
    if info and info.name then
        return info.spellID, info.name, info.iconID
    end
end

--------------------------------------------------------------------------------
-- Objetos
--------------------------------------------------------------------------------

-- Unidades que lleva el jugador en las bolsas.
function Api.ItemCount(id)
    local f = (C_Item and C_Item.GetItemCount) or GetItemCount
    return f and f(id) or 0
end

-- Nombre del objeto. Si el cliente aún no lo tiene en caché el nombre llega
-- vacío; entonces usamos el "item string" (item:6948), que las funciones de
-- asignación también aceptan.
function Api.ItemName(id)
    return (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("item:" .. id)
end

function Api.ItemIcon(id)
    return C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
end

--------------------------------------------------------------------------------
-- Macros
--------------------------------------------------------------------------------

-- Acepta índice o nombre. Devuelve nombre e icono, o nil si no existe.
function Api.MacroInfo(indexOrName)
    local name, icon = GetMacroInfo(indexOrName)
    return name, icon
end

--------------------------------------------------------------------------------
-- Cursor
--------------------------------------------------------------------------------
-- Cuando el jugador "coge" algo con el ratón (un hechizo del libro, un objeto
-- de las bolsas, una macro), WoW guarda qué lleva en el cursor y GetCursorInfo
-- lo describe. Esto lo traduce a una entrada de hueco del addon:
--   { kind = "spell", id = ... } | { kind = "item", id = ... } | { kind = "macro", name = ... }
-- Las macros se guardan por nombre porque su índice cambia al borrar otras.

local cursorReaders = {
    spell = function(bookSlot, _, spellID)
        -- En el cliente moderno el ID llega directamente; si no, se obtiene a
        -- partir de la posición en el libro de hechizos.
        if not spellID and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
            local info = C_SpellBook.GetSpellBookItemInfo(bookSlot, Enum.SpellBookSpellBank.Player)
            spellID = info and info.spellID
        end
        return spellID and { kind = "spell", id = spellID }
    end,
    item = function(itemID)
        return { kind = "item", id = itemID }
    end,
    macro = function(index)
        local name = Api.MacroInfo(index)
        return name and { kind = "macro", name = name }
    end,
}

-- Devuelve la entrada de hueco de lo que lleva el cursor, o nil si no es algo
-- que se pueda asignar (monturas, acciones de mascota...).
function Api.CursorEntry()
    local kind, a, b, c = GetCursorInfo()
    local read = kind and cursorReaders[kind]
    return read and read(a, b, c) or nil
end

function Api.HasCursorItem()
    return GetCursorInfo() ~= nil
end

function Api.ClearCursor()
    ClearCursor()
end
