--[[
Capa de acceso a la API de WoW
==============================

Parte de FranLib (ver Config.lua): se edita en el repositorio FranLib y se
copia a cada addon con su tools/sync.py.

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
    return f and f(ns.FranLib.addonName, field)
end

function Api.AddOnVersion()
    return Api.AddOnMetadata("Version") or "?"
end

--------------------------------------------------------------------------------
-- Valores secretos
--------------------------------------------------------------------------------
-- El cliente moderno (y Forever con él) oculta a los addons algunos datos en
-- combate: la amenaza, las auras... Llegan como "valores secretos", que se
-- pueden pasar de un sitio a otro pero no comparar ni usar en un "if": eso
-- da un error de Lua. Hay que preguntar antes si lo son.

function Api.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

local function anySecret(...)
    for i = 1, select("#", ...) do
        if Api.IsSecret((select(i, ...))) then return true end
    end
    return false
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

-- Registro de combate a archivo (lo mismo que /combatlog). LoggingCombat()
-- sin argumentos dice si está encendido; con true o false lo cambia. Va con
-- pcall por si algún cliente la protege: entonces no se puede y se devuelve
-- false en vez de cortar el addon con un error.
function Api.IsLoggingCombat()
    if not LoggingCombat then return false end
    local ok, on = pcall(LoggingCombat)
    return ok and on and true or false
end

-- Devuelve true si el registro queda como se ha pedido.
function Api.SetLoggingCombat(on)
    if not LoggingCombat then return false end
    pcall(LoggingCombat, on and true or false)
    return Api.IsLoggingCombat() == (on and true or false)
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
-- Si el cliente la oculta (valor secreto, en combate) devuelve { secret =
-- true, tanking, status, percent } con los valores tal cual: el addon no
-- puede mirarlos (ni compararlos ni usarlos en un "if"), pero sí pasarlos a
-- la interfaz para que los pinte (UI/ThreatBadge.lua).
function Api.Threat(who, unit)
    if not UnitDetailedThreatSituation or not UnitExists(who) then return nil end
    local tanking, status, percent = UnitDetailedThreatSituation(who, unit)
    if anySecret(tanking, status, percent) then
        return { secret = true, tanking = tanking, status = status, percent = percent }
    end
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

-- Color para pintar con las funciones que aceptan valores secretos
-- (Region:SetVertexColorFromBoolean y demás), que piden un ColorMixin.
function Api.Color(rgb)
    return CreateColor(rgb[1], rgb[2], rgb[3], rgb[4] or 1)
end

-- De dos colores, el primero si value es cierto. value puede ser secreto: el
-- juego lo decide sin que el addon lo vea, y el color que devuelve también
-- es secreto (solo sirve para pasárselo a la interfaz).
function Api.ColorFromBoolean(value, ifTrue, ifFalse)
    return C_CurveUtil.EvaluateColorFromBoolean(value, ifTrue, ifFalse)
end

-- Si el cliente tiene la función de amenaza (aunque luego la oculte en
-- combate: eso lo dice Api.Threat).
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

local function readPlayerBuffs()
    local buffs = {}
    for i = 1, MAX_BUFFS do
        local name, spellID = playerBuff(i)
        if anySecret(name, spellID) then return nil end
        if not name then break end
        buffs[#buffs + 1] = { name = name, spellID = spellID }
    end
    return buffs
end

-- Beneficios que lleva el jugador: lista de { name, spellID }, o nil si el
-- cliente no deja leerlos ahora (en combate los oculta: pedirlos da un error,
-- que aquí se recoge sin que llegue al manejador).
function Api.PlayerBuffs()
    local ok, buffs = pcall(readPlayerBuffs)
    return ok and buffs or nil
end

-- Si el jugador lleva el aura de un hechizo concreto: true, false, o nil si
-- no se puede saber. Es otra forma de preguntar que el cliente moderno puede
-- permitir aunque oculte la lista completa.
function Api.HasPlayerAura(spellID)
    local get = apiFunction(C_UnitAuras, "GetPlayerAuraBySpellID")
    if not get then return nil end
    local ok, data = pcall(get, spellID)
    if not ok or Api.IsSecret(data) then return nil end
    return data ~= nil
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

-- De una lista de rangos de un hechizo, de menor a mayor, el más alto que
-- sabe el jugador, o nil si no sabe ninguno.
function Api.KnownSpell(ranks)
    for i = #ranks, 1, -1 do
        if Api.IsSpellKnown(ranks[i]) then return ranks[i] end
    end
end

-- Si se puede lanzar ya (sin contar el enfriamiento): las que solo valen tras
-- algo, como Revancha tras bloquear, esquivar o parar, lo dicen aquí. El
-- juego no lo oculta en combate (no es un valor secreto, ver la
-- documentación de C_Spell.IsSpellUsable).
function Api.IsSpellUsable(id)
    local f = apiFunction(C_Spell, "IsSpellUsable") or IsUsableSpell
    if not f then return false end
    local usable = f(id)
    if Api.IsSecret(usable) then return false end
    return usable and true or false
end

-- Enfriamiento de un hechizo: inicio y duración en segundos (0, 0 si está
-- listo), o nil si el juego no lo dice. En combate lo oculta (valor
-- secreto): quien lo usa debe tener su propia cuenta (Features/CooldownWarning.lua).
function Api.SpellCooldown(id)
    local info = call(C_Spell, "GetSpellCooldown", id)
    if type(info) ~= "table" then return nil end
    local start, duration = info.startTime, info.duration
    if anySecret(start, duration) or not start or not duration then return nil end
    return start, duration
end

-- Hora del juego en segundos (con decimales), la de los enfriamientos.
function Api.Time()
    return GetTime()
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

-- Llama a fn(tooltip, itemID) cada vez que el juego muestra el tooltip de un
-- objeto, para añadirle líneas. El cliente moderno avisa con
-- TooltipDataProcessor; los antiguos, con el script OnTooltipSetItem de cada
-- tooltip. El ID puede llegar oculto (valor secreto): entonces no se llama.
function Api.OnItemTooltip(fn)
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            local id = data and data.id
            if id and not Api.IsSecret(id) then fn(tooltip, id) end
        end)
        return
    end
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
        tooltip:HookScript("OnTooltipSetItem", function(self)
            local _, link = self:GetItem()
            local id = link and tonumber(link:match("item:(%d+)"))
            if id then fn(self, id) end
        end)
    end
end

--------------------------------------------------------------------------------
-- Profesiones
--------------------------------------------------------------------------------

local function linkID(link, kind)
    return link and tonumber(link:match(kind .. ":(%d+)"))
end

-- Cantidad que da una receta: algunas dan entre un mínimo y un máximo, y
-- para hacer cuentas vale la media.
local function averageMade(min, max)
    min = min or 1
    if not max or max == min then return min end
    return (min + max) / 2
end

-- Receta del cliente moderno a partir de su ID. Solo cuentan los
-- ingredientes obligatorios (los opcionales no hacen falta para hacerla).
-- Una receta rara no debe romper la lectura de las demás: va protegida.
local function modernRecipe(id)
    local ok, info, schematic = pcall(function()
        return C_TradeSkillUI.GetRecipeInfo(id), C_TradeSkillUI.GetRecipeSchematic(id, false)
    end)
    if not ok or not info then return nil end
    local recipe = { id = id, learned = info.learned == true, reagents = {} }
    if not schematic then return recipe end
    if schematic.outputItemID then
        recipe.output = { schematic.outputItemID, averageMade(schematic.quantityMin, schematic.quantityMax) }
    end
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local item = slot.reagents and slot.reagents[1] and slot.reagents[1].itemID
        if item and slot.required ~= false then
            recipe.reagents[#recipe.reagents + 1] = { item, slot.quantityRequired }
        end
    end
    return recipe
end

-- Receta de los clientes antiguos por su posición en la ventana (que solo
-- enseña las aprendidas, más las cabeceras de categoría, sin enlace).
local function classicRecipe(index)
    local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(index)
    local id = linkID(link, "enchant") or linkID(link, "spell")
    if not id then return nil end
    local recipe = { id = id, learned = true, reagents = {} }
    local output = linkID(GetTradeSkillItemLink(index), "item")
    if output then recipe.output = { output, averageMade(GetTradeSkillNumMade(index)) } end
    for r = 1, GetTradeSkillNumReagents(index) or 0 do
        local item = linkID(GetTradeSkillReagentItemLink(index, r), "item")
        local _, _, count = GetTradeSkillReagentInfo(index, r)
        if item then recipe.reagents[#recipe.reagents + 1] = { item, count } end
    end
    return recipe
end

-- Recetas de la ventana de profesión abierta, tal y como las da el juego, o
-- una lista vacía si no hay ninguna abierta. Cada una:
--   { id = hechizo, learned = si la sabe,
--     reagents = { { objeto, cantidad }, ... }, output = { objeto, cantidad } }
-- (output es nil si no da un objeto, como un encantamiento). El cliente
-- moderno las da todas con C_TradeSkillUI, también las que aún no sabe; los
-- antiguos, solo las aprendidas, una a una por su posición.
function Api.OpenTradeSkillRecipes()
    local recipes = {}
    local all = apiFunction(C_TradeSkillUI, "GetAllRecipeIDs")
    if all then
        for _, id in ipairs(all() or {}) do recipes[#recipes + 1] = modernRecipe(id) end
        return recipes
    end
    for i = 1, GetNumTradeSkills and GetNumTradeSkills() or 0 do
        recipes[#recipes + 1] = classicRecipe(i)
    end
    return recipes
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
