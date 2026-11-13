--[[
Capa de acceso a la API de WoW
==============================

Archivo compartido con StreamDeckWoW: se edita en FranTools y se copia con
tools/sync_shared.py.

El resto del addon no llama directamente a la API del juego para hechizos,
objetos, macros, el cursor o los vendedores: pasa por estas funciones. Motivos:

  * WoW Forever usa el cliente moderno, donde muchas funciones globales
    clásicas se movieron a espacios de nombres (C_Spell, C_Item, C_SpellBook).
    Si Blizzard vuelve a mover algo, solo hay que tocar este archivo.
  * Se usa la API moderna. Donde existe una equivalente clásica (hechizo
    conocido, número de objetos, metadatos del addon) se usa como respaldo; el
    resto de funciones de los espacios C_* devuelve nil si no existe, en lugar
    de dar un error de Lua. Las de macros, cursor, jugador, mascota y
    vendedor (GetMacroInfo, GetCursorInfo, UnitClass, GetPetActionInfo,
    RepairAllItems...) existen en todos los clientes y se usan tal cual; la
    de amenaza se comprueba antes, por si el cliente no la tuviera.
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
-- Errores de Lua y hora
--------------------------------------------------------------------------------

-- Manejador al que el juego entrega los errores de Lua de todos los addons.
function Api.ErrorHandler()
    return geterrorhandler()
end

function Api.SetErrorHandler(fn)
    seterrorhandler(fn)
end

-- Pila de llamadas como texto, empezando "level" niveles por encima de quien
-- llama a esta función (1 = quien llama). Dentro de un manejador de errores
-- es la pila del momento del error.
function Api.Stack(level)
    return debugstack and debugstack(level + 1) or ""
end

-- Fecha y hora local, para apuntar cuándo pasó algo.
function Api.Now()
    return date("%Y-%m-%d %H:%M")
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

-- Color de la clase (RGB 0-1), el mismo de los nombres en el chat y los
-- marcos de grupo, o nil si el cliente no lo tiene.
function Api.ClassColor(class)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and { c.r, c.g, c.b } or nil
end

function Api.IsDead()
    return UnitIsDeadOrGhost("player") and true or false
end

-- Tipo de sitio en el que está: "party" (mazmorra), "raid" (banda), "pvp",
-- "arena", "scenario"... o "none" en el mundo abierto. IsInInstance devuelve
-- primero si está en una instancia y después el tipo.
function Api.InstanceType()
    local inInstance, kind = IsInInstance()
    return inInstance and kind or "none"
end

-- En grupo o en banda.
function Api.IsInGroup()
    return IsInGroup and IsInGroup() and true or false
end

-- Rol del jugador en el grupo ("TANK", "HEALER", "DAMAGER"), o nil si no lo
-- tiene puesto o si el cliente no tiene roles (el buscador de grupo).
function Api.GroupRole()
    if not UnitGroupRolesAssigned then return nil end
    local role = UnitGroupRolesAssigned("player")
    if role == "NONE" then return nil end
    return role
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
-- Amenaza (agro) y barras de nombre
--------------------------------------------------------------------------------

-- Amenaza de "who" ("player", "pet") sobre unit: { tanking, status, percent },
-- o nil si no está en su lista de amenaza (o si no existe). tanking: va a por
-- él. status, de UnitThreatSituation: 0 poca, 1 más que quien tanquea (está
-- a punto de quitarle el agro), 2 y 3 tanqueando. percent es el escalado: a
-- 100 le quita el agro a quien lo tiene.
function Api.Threat(who, unit)
    if not UnitDetailedThreatSituation or not UnitExists(who) then return nil end
    local tanking, status, percent = UnitDetailedThreatSituation(who, unit)
    if status == nil then return nil end
    return { tanking = tanking and true or false, status = status, percent = percent or 0 }
end

function Api.CanAttack(unit)
    return UnitCanAttack("player", unit) and true or false
end

-- Barra de nombre de una unidad, o nil si no tiene o si el juego la protege
-- (en el cliente moderno, las de aliados dentro de mazmorras: tocarlas da error).
function Api.NamePlateFor(unit)
    local plate = call(C_NamePlate, "GetNamePlateForUnit", unit)
    if plate and not (plate.IsForbidden and plate:IsForbidden()) then return plate end
end

-- Unidad de una barra de nombre ("nameplate1"...). Según la versión del
-- cliente la guarda el marco base o su UnitFrame: se miran los dos.
local function namePlateUnit(plate)
    local frame = plate.UnitFrame
    return plate.namePlateUnitToken or (type(frame) == "table" and frame.unit) or nil
end

-- Unidades con barra de nombre a la vista ("nameplate1", "nameplate2"...).
function Api.NamePlateUnits()
    local units = {}
    for _, plate in ipairs(call(C_NamePlate, "GetNamePlates") or {}) do
        local unit = namePlateUnit(plate)
        if unit then units[#units + 1] = unit end
    end
    return units
end

-- Barra de vida de una barra de nombre de Blizzard, o nil si su diseño no la
-- tiene donde se espera (otro addon que las sustituye). En los clientes
-- clásicos cuelga del UnitFrame; en los modernos, de su HealthBarsContainer.
function Api.NamePlateHealthBar(plate)
    local frame = plate.UnitFrame
    if type(frame) ~= "table" then return nil end
    local container = frame.HealthBarsContainer
    return frame.healthBar or (type(container) == "table" and container.healthBar) or nil
end

-- Si el cliente da la amenaza a los addons (sin ella no hay agro que pintar).
function Api.HasThreat()
    return UnitDetailedThreatSituation ~= nil
end

function Api.UnitName(unit)
    return UnitName(unit)
end

--------------------------------------------------------------------------------
-- Auras
--------------------------------------------------------------------------------

-- Máximo de beneficios que puede llevar un personaje.
local MAX_BUFFS = 40

-- Nombre e ID de hechizo del beneficio i del jugador, o nil al acabar la
-- lista. El cliente moderno los da en una tabla (C_UnitAuras); los antiguos,
-- con UnitBuff, donde el ID es el décimo valor.
local function playerBuff(i)
    local data = call(C_UnitAuras, "GetBuffDataByIndex", "player", i)
    if data then return data.name, data.spellId end
    if UnitBuff then
        local name, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        return name, spellID
    end
end

-- Beneficios que lleva el jugador: lista de { name, spellID }.
function Api.PlayerBuffs()
    local buffs = {}
    for i = 1, MAX_BUFFS do
        local name, spellID = playerBuff(i)
        if not name then break end
        buffs[#buffs + 1] = { name = name, spellID = spellID }
    end
    return buffs
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

-- Clase y subclase del objeto (números, no dependen del idioma): por ejemplo
-- 2/2 es un arco y 6/2 flechas. GetItemInfoInstant no necesita que el objeto
-- esté en caché, así que responde siempre al momento.
function Api.ItemClass(id)
    local f = apiFunction(C_Item, "GetItemInfoInstant") or GetItemInfoInstant
    if not f then return nil end
    local _, _, _, _, _, classID, subclassID = f(id)
    return classID, subclassID
end

--------------------------------------------------------------------------------
-- Equipo y bolsas
--------------------------------------------------------------------------------

-- ID del objeto equipado en una ranura del personaje (nil si está vacía o si
-- la ranura no existe en este cliente).
function Api.EquippedItem(slot)
    return GetInventoryItemID("player", slot)
end

-- Llama a fn(bolsa, hueco, info) por cada hueco ocupado de las bolsas (la
-- mochila es la 0; carcajes y bolsas de munición cuentan como bolsas). info es
-- la tabla de C_Container.GetContainerItemInfo (itemID, stackCount, quality,
-- isLocked, hasNoValue...). Sin C_Container no recorre nada.
local function eachBagSlot(fn)
    local numSlots = apiFunction(C_Container, "GetContainerNumSlots") or GetContainerNumSlots
    local slotInfo = apiFunction(C_Container, "GetContainerItemInfo")
    if not numSlots or not slotInfo then return end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, numSlots(bag) or 0 do
            local info = slotInfo(bag, slot)
            if info and info.itemID then fn(bag, slot, info) end
        end
    end
end

-- Todo lo que hay en las bolsas: lista de { id, count }.
function Api.BagItems()
    local items = {}
    eachBagSlot(function(_, _, info)
        items[#items + 1] = { id = info.itemID, count = info.stackCount or 1 }
    end)
    return items
end

-- Cada hueco ocupado con su posición: lista de { bag, slot, id, count,
-- quality, locked, noValue }. locked es que el juego lo está moviendo o
-- vendiendo; noValue, que ningún vendedor lo compra.
function Api.BagSlots()
    local slots = {}
    eachBagSlot(function(bag, slot, info)
        slots[#slots + 1] = {
            bag = bag, slot = slot, id = info.itemID, count = info.stackCount or 1,
            quality = info.quality, locked = info.isLocked, noValue = info.hasNoValue,
        }
    end)
    return slots
end

-- Precio al que lo compra un vendedor, por unidad, en cobre (0 si no se sabe:
-- objeto aún sin cargar). Es el undécimo valor de GetItemInfo.
function Api.SellPrice(id)
    local getInfo = apiFunction(C_Item, "GetItemInfo") or GetItemInfo
    return (getInfo and select(11, getInfo(id))) or 0
end

--------------------------------------------------------------------------------
-- Vendedor y dinero
--------------------------------------------------------------------------------

function Api.Money()
    return GetMoney()
end

-- Dinero en texto sin iconos, sin las monedas a cero salvo que no haya nada:
-- "1o 5c", "20p", "0c".
local function plainMoney(copper)
    local parts = {}
    local amounts = { { math.floor(copper / 10000), "o" }, { math.floor(copper / 100) % 100, "p" }, { copper % 100, "c" } }
    for _, a in ipairs(amounts) do
        if a[1] > 0 then parts[#parts + 1] = a[1] .. a[2] end
    end
    return #parts > 0 and table.concat(parts, " ") or "0c"
end

-- Cantidad de dinero legible con los iconos de oro, plata y cobre del juego,
-- o en texto si el cliente no tiene la función.
function Api.MoneyText(copper)
    local coins = apiFunction(C_CurrencyInfo, "GetCoinTextureString") or GetCoinTextureString
    if coins then return coins(copper) end
    return plainMoney(copper)
end

-- Si el vendedor abierto repara. Los clientes antiguos devuelven 1 o nil.
function Api.MerchantCanRepair()
    local can = CanMerchantRepair()
    return can == true or can == 1
end

-- Lo que cuesta reparar todo el equipo (0 si no hay nada roto).
function Api.RepairCost()
    return GetRepairAllCost() or 0
end

-- Repara todo con el dinero del personaje (no con el del banco de hermandad).
function Api.RepairAll()
    RepairAllItems()
end

-- Con el vendedor abierto, "usar" un objeto de las bolsas es vendérselo.
function Api.SellBagItem(bag, slot)
    local use = apiFunction(C_Container, "UseContainerItem") or UseContainerItem
    use(bag, slot)
end

-- Mayúsculas pulsadas: para saltarse lo automático al abrir el vendedor.
function Api.IsShiftDown()
    return IsShiftKeyDown()
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
