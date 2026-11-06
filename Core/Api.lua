--[[
Capa de acceso a la API de WoW
==============================

El resto del addon no llama directamente a la API del juego para hechizos,
objetos, macros o el cursor: pasa por estas funciones. Motivos:

  * WoW Forever usa el cliente moderno, donde muchas funciones globales
    clásicas se movieron a espacios de nombres (C_Spell, C_Item, C_SpellBook).
    Si Blizzard vuelve a mover algo, solo hay que tocar este archivo.
  * Se usa la API moderna. Donde existe una equivalente clásica (hechizo
    conocido, número de objetos, metadatos del addon) se usa como respaldo; el
    resto de funciones de los espacios C_* devuelve nil si no existe, en lugar
    de dar un error de Lua. Las de macros, cursor, jugador y mascota
    (GetMacroInfo, GetCursorInfo, UnitClass, GetPetActionInfo...) existen en
    todos los clientes y se usan tal cual.
  * Para probar el addon fuera del juego basta con simular estas funciones.
]]

local _, ns = ...

local Api = {}
ns.Api = Api

-- Función de un espacio de nombres de la API (C_Spell, C_Item...), o nil si el
-- espacio o la función no existen en este cliente.
local function apiFunction(namespace, name)
    return namespace and namespace[name]
end

-- Llama a una función de la API si existe; si no, devuelve nil.
local function call(namespace, name, ...)
    local f = apiFunction(namespace, name)
    if f then return f(...) end
end

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

-- Tipo de sitio en el que está: "party" (mazmorra), "raid" (banda), "pvp",
-- "arena", "scenario"... o "none" en el mundo abierto. IsInInstance devuelve
-- primero si está en una instancia y después el tipo.
function Api.InstanceType()
    local inInstance, kind = IsInInstance()
    return inInstance and kind or "none"
end

--------------------------------------------------------------------------------
-- Mascota
--------------------------------------------------------------------------------

function Api.HasPet()
    return UnitExists("pet") and true or false
end

-- Habilidades de la barra de la mascota: { name, spellID, autoCast }.
-- autoCast es el lanzamiento automático (el borde dorado que gira, que se
-- cambia con clic derecho en la barra). El ID del hechizo solo llega en el
-- cliente moderno; en otros es nil y hay que fiarse del nombre.
function Api.PetActions()
    local actions = {}
    for i = 1, NUM_PET_ACTION_SLOTS or 10 do
        local name, _, _, _, _, autoCastEnabled, spellID = GetPetActionInfo(i)
        if name then
            actions[#actions + 1] = { name = name, spellID = spellID, autoCast = autoCastEnabled and true or false }
        end
    end
    return actions
end

--------------------------------------------------------------------------------
-- Avisos
--------------------------------------------------------------------------------

-- Texto grande en el centro de la pantalla, como los avisos de banda. Solo se
-- ve el jugador: no se envía a nadie.
function Api.ShowCenterWarning(text)
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
    end
end

function Api.PlayWarningSound()
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        PlaySound(SOUNDKIT.RAID_WARNING)
    end
end

--------------------------------------------------------------------------------
-- Hechizos
--------------------------------------------------------------------------------

function Api.IsSpellKnown(id)
    if call(C_SpellBook, "IsSpellKnown", id) then return true end
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return IsSpellKnown and IsSpellKnown(id) or false
end

function Api.SpellName(id)
    return call(C_Spell, "GetSpellName", id)
end

-- ID del archivo de icono (un número, no una ruta).
function Api.SpellIcon(id)
    return call(C_Spell, "GetSpellTexture", id)
end

-- Busca un hechizo por nombre. Devuelve id, nombre e icono. Sin verificar en
-- Forever: en el cliente moderno la búsqueda por nombre solo encuentra los
-- hechizos de tu libro, que es justo lo que queremos.
function Api.FindSpellByName(name)
    local info = call(C_Spell, "GetSpellInfo", name)
    if info and info.name then
        return info.spellID, info.name, info.iconID
    end
end

--------------------------------------------------------------------------------
-- Objetos
--------------------------------------------------------------------------------

-- Unidades que lleva el jugador en las bolsas.
function Api.ItemCount(id)
    local f = apiFunction(C_Item, "GetItemCount") or GetItemCount
    return f and f(id) or 0
end

-- Objetos cuyos datos se han pedido al servidor y aún no han llegado.
local pendingItems = {}

-- Nombre del objeto y si ya está cargado. Si el cliente aún no lo tiene en
-- caché, GetItemNameByID devuelve nil: se pide al servidor (la respuesta llega
-- con GET_ITEM_INFO_RECEIVED) y mientras tanto se devuelve el "item string"
-- (item:6948), que sirve para asignar el atajo pero no para enseñarlo.
-- Sin verificar: que SetOverrideBindingItem acepte "item:N" en Forever.
function Api.ItemName(id)
    local name = call(C_Item, "GetItemNameByID", id)
    if name then return name, true end
    pendingItems[id] = true
    call(C_Item, "RequestLoadItemDataByID", id)
    return "item:" .. id, false
end

-- true si los datos de este objeto los había pedido el addon (y deja de
-- esperarlos). Sirve para reaccionar solo a las respuestas propias: el evento
-- llega también por cualquier objeto que cargue el cliente (tooltips, chat...).
function Api.TakePendingItem(id)
    if not pendingItems[id] then return false end
    pendingItems[id] = nil
    return true
end

function Api.ItemIcon(id)
    return call(C_Item, "GetItemIconByID", id)
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
    spell = function(bookSlot, bank, spellID)
        -- En el cliente moderno el ID llega directamente; si no, se obtiene a
        -- partir de la posición en el libro (del jugador o de la mascota, según
        -- el banco que indique el cursor).
        if not spellID then
            local book = (type(bank) == "number" and bank) or (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player)
            local info = call(C_SpellBook, "GetSpellBookItemInfo", bookSlot, book)
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

-- true si el jugador lleva algo en el cursor, sea lo que sea.
function Api.HasCursorContent()
    return GetCursorInfo() ~= nil
end

function Api.ClearCursor()
    ClearCursor()
end
