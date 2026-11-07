--[[
Aviso de munición baja
======================

Un recuadro pequeño (UI/NoticeBox.lua) con el icono de la munición y cuántas
quedan, que aparece cuando bajan de Const.AMMO.LOW (borde ámbar) y se pone rojo
por debajo de Const.AMMO.CRITICAL. Sin sonido ni texto en el centro de la
pantalla: es un recordatorio para ir a comprar, no una alarma. Desaparece solo
en cuanto vuelves a tener suficiente.

Qué munición se cuenta:
  * la que tienes equipada en la ranura de munición, si el cliente la tiene;
  * si no, todas las flechas o balas de las bolsas que sirvan para el arma a
    distancia que llevas (arco y ballesta, flechas; arma de fuego, balas).
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

-- Munición disponible e icono, o nil si este personaje no gasta munición.
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
    return count, icon or C.ICONS[ammoType]
end

--------------------------------------------------------------------------------
-- Aviso
--------------------------------------------------------------------------------

-- Nivel del aviso y texto para esa cantidad, o nil si hay de sobra.
local function noticeFor(count)
    if count == 0 then return "critical", "Sin munición" end
    if count < C.CRITICAL then return "critical", ("Munición muy baja: %d"):format(count) end
    if count < C.LOW then return "warning", ("Munición baja: %d"):format(count) end
end

-- El recuadro se crea al usarlo por primera vez (UI/NoticeBox.lua se carga
-- después que este archivo).
local box
local function getBox()
    box = box or ns.NoticeBox.Create({
        name = "StreamDeckWoWAmmoNotice",
        settings = Storage.GetAmmo,
        tooltip = {
            "Munición",
            ("Aparece con menos de %d y se pone rojo con menos de %d."):format(C.LOW, C.CRITICAL),
            "Arrástralo para moverlo.",
            "Se apaga en /sdeck config o con /sdeck municion.",
        },
    })
    return box
end

function Ammo.Check()
    local count, icon = currentAmmo()
    local level, text
    if count and Ammo.IsEnabled() then level, text = noticeFor(count) end
    if level then
        getBox():ShowNotice(icon, text, level)
    elseif box then
        box:Hide()
    end
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
