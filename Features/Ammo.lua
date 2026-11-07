--[[
Aviso de munición baja
======================

Un recuadro pequeño (UI/NoticeBox.lua) con el icono de la munición y cuántas
quedan, que aparece cuando bajan del umbral de aviso (borde ámbar) y se pone
rojo por debajo del umbral crítico. Sin sonido ni texto en el centro de la
pantalla: es un recordatorio para ir a comprar, no una alarma. Desaparece solo
en cuanto vuelves a tener suficiente.

Los umbrales van por tipo de munición (flechas para arco y ballesta, balas
para armas de fuego), porque no se gastan al mismo ritmo ni se compran igual.
Los valores por defecto están en Const.AMMO.TYPES; el jugador los cambia en la
sección Munición de /sdeck config. Un umbral de aviso 0 apaga el aviso de
ese tipo.

Qué munición se cuenta:
  * la que tienes equipada en la ranura de munición, si el cliente la tiene;
  * si no, todas las flechas o balas de las bolsas que sirvan para el arma a
    distancia que llevas.
Sin arma que gaste munición (o con varita o arrojadizas) no hay aviso.

Sin verificar en Forever: si su cliente tiene ranura de munición. Por eso se
cuentan también las bolsas, que funcionan en cualquier caso.
]]

local _, ns = ...
local Const, Util, Api, Storage = ns.Const, ns.Util, ns.Api, ns.Storage
local C = Const.AMMO

local Ammo = {}
ns.Ammo = Ammo

--------------------------------------------------------------------------------
-- Umbrales
--------------------------------------------------------------------------------
-- Se guardan por el nombre del tipo ("arrow", "bullet") y solo si difieren del
-- valor por defecto, para que cambiar el valor por defecto en una versión
-- nueva llegue a quien no lo ha tocado.

-- Umbral guardado, o nil. Solo lee: consultar no debe dejar tablas vacías
-- en el archivo de quien nunca ha tocado los umbrales.
local function savedThreshold(ammoType, which)
    local all = Storage.GetAmmo().thresholds
    local own = all and all[C.TYPES[ammoType].key]
    return own and own[which]
end

-- which = "low" (aviso) o "critical" (rojo).
function Ammo.GetThreshold(ammoType, which)
    return savedThreshold(ammoType, which) or C.TYPES[ammoType][which]
end

-- Guarda un umbral; las tablas se crean solo aquí, al escribir.
local function store(ammoType, which, value)
    local settings = Storage.GetAmmo()
    local key = C.TYPES[ammoType].key
    settings.thresholds = settings.thresholds or {}
    settings.thresholds[key] = settings.thresholds[key] or {}
    Util.SetOverride(settings.thresholds[key], which, value, C.TYPES[ammoType][which])
end

local function clamp(value)
    return math.max(0, math.min(C.MAX_THRESHOLD, math.floor(value)))
end

-- El crítico nunca puede quedar por encima del aviso: si se pide, se ajusta.
-- Al bajar el aviso por debajo del crítico, el crítico baja con él.
function Ammo.SetThreshold(ammoType, which, value)
    value = clamp(value)
    if which == "critical" then
        value = math.min(value, Ammo.GetThreshold(ammoType, "low"))
    elseif Ammo.GetThreshold(ammoType, "critical") > value then
        store(ammoType, "critical", value)
    end
    store(ammoType, which, value)
    Ammo.Check()
    Util.Fire(Const.MSG.SETTINGS_CHANGED)
end

--------------------------------------------------------------------------------
-- Recuento
--------------------------------------------------------------------------------

-- Subclase de munición que dispara el arma a distancia equipada, o nil.
local function ammoTypeForWeapon()
    local weapon = Api.EquippedItem(C.RANGED_SLOT)
    if not weapon then return nil end
    local class, subclass = Api.ItemClass(weapon)
    return class == C.WEAPON_CLASS and C.WEAPON_AMMO[subclass] or nil
end

local function isAmmoOfType(id, ammoType)
    local class, subclass = Api.ItemClass(id)
    return class == C.PROJECTILE_CLASS and subclass == ammoType
end

-- Total en las bolsas de la munición de ese tipo, y el icono de la primera
-- que se encuentre.
local function countInBags(ammoType)
    local total, icon = 0, nil
    for _, item in ipairs(Api.BagItems()) do
        if isAmmoOfType(item.id, ammoType) then
            total = total + item.count
            icon = icon or Api.ItemIcon(item.id)
        end
    end
    return total, icon
end

-- Munición disponible, icono y tipo, o nil si este personaje no gasta munición.
local function currentAmmo()
    if not C.CLASSES[Api.PlayerClass()] then return nil end
    local ammoType = ammoTypeForWeapon()
    if not ammoType then return nil end
    local equipped = Api.EquippedItem(C.AMMO_SLOT)
    local count, icon
    if equipped and isAmmoOfType(equipped, ammoType) then
        count, icon = Api.ItemCount(equipped), Api.ItemIcon(equipped)
    else
        count, icon = countInBags(ammoType)
    end
    return count, icon or C.TYPES[ammoType].icon, ammoType
end

--------------------------------------------------------------------------------
-- Aviso
--------------------------------------------------------------------------------

-- Nivel del aviso y texto para esa cantidad, o nil si hay de sobra.
local function noticeFor(count, ammoType)
    if count >= Ammo.GetThreshold(ammoType, "low") then return nil end
    if count == 0 then return "critical", "Sin munición" end
    if count < Ammo.GetThreshold(ammoType, "critical") then
        return "critical", ("Munición muy baja: %d"):format(count)
    end
    return "warning", ("Munición baja: %d"):format(count)
end

-- El marco del recuadro se crea al mostrar el primer aviso.
local box = ns.NoticeBox.Create({
    name = "StreamDeckWoWAmmoNotice",
    settings = Storage.GetAmmo,
    tooltip = {
        "Munición",
        "Ámbar: munición baja. Rojo: casi sin munición.",
        "Arrástralo para moverlo.",
        "Los umbrales se cambian en /sdeck config, sección Munición.",
    },
})

function Ammo.Check()
    local count, icon, ammoType = currentAmmo()
    local level, text
    if count and Ammo.IsEnabled() then level, text = noticeFor(count, ammoType) end
    box:ShowIf(icon, text, level)
end

-- Disparar gasta munición y lanza BAG_UPDATE_DELAYED a cada momento en combate:
-- se agrupa para no recontar las bolsas con cada flecha.
local checkSoon = Util.Debounce(C.CHECK_DELAY, Ammo.Check)

Util.On("PLAYER_ENTERING_WORLD", checkSoon)
Util.On("BAG_UPDATE_DELAYED", checkSoon)
Util.On("PLAYER_EQUIPMENT_CHANGED", checkSoon)   -- cambio de arma o de munición equipada

--------------------------------------------------------------------------------
-- API del módulo
--------------------------------------------------------------------------------

-- Encender o apagar el aviso: al cambiarlo se aplica enseguida (aparece o
-- desaparece el recuadro).
local switch = Util.Switch(Storage.GetAmmo, function() Ammo.Check() end)
Ammo.IsEnabled, Ammo.SetEnabled, Ammo.Toggle = switch.IsEnabled, switch.SetEnabled, switch.Toggle
