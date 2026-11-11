--[[
Vendedor: reparar y vender la basura
====================================

Al abrir un vendedor, sin tener que tocar nada:

  1. Vende la basura (los objetos grises) en tandas (Const.MERCHANT).
  2. Repara todo el equipo, si el vendedor repara y te llega el dinero. Va
     después de vender para contar ya con lo que da la basura.

Cada cosa se cuenta en el chat ("basura vendida: 7 objetos por 1p 20c"). Las
dos son opciones generales, para cualquier clase, que se apagan en la página
General de /sdeck config o con /sdeck reparar y /sdeck basura. Si abres el
vendedor con Mayús pulsada, no hace nada: por si quieres vender a mano.

Solo se vende lo de calidad pobre que el vendedor compra; nunca nada blanco o
mejor, aunque valga poco.
]]

local _, ns = ...
local Const, Util, Api, Storage = ns.Const, ns.Util, ns.Api, ns.Storage
local C = Const.MERCHANT

local Merchant = {}
ns.Merchant = Merchant

--------------------------------------------------------------------------------
-- Interruptores
--------------------------------------------------------------------------------
-- Al cambiarlos no hay nada que comprobar: se aplican al próximo vendedor.

local function nothing() end

local repairSwitch = Util.Switch(Storage.GetRepair, nothing)
Merchant.IsRepairEnabled, Merchant.SetRepairEnabled, Merchant.ToggleRepair =
    repairSwitch.IsEnabled, repairSwitch.SetEnabled, repairSwitch.Toggle

local junkSwitch = Util.Switch(Storage.GetJunk, nothing)
Merchant.IsJunkEnabled, Merchant.SetJunkEnabled, Merchant.ToggleJunk =
    junkSwitch.IsEnabled, junkSwitch.SetEnabled, junkSwitch.Toggle

--------------------------------------------------------------------------------
-- Visita al vendedor
--------------------------------------------------------------------------------
-- Cada vez que se abre un vendedor empieza una visita nueva. Las tandas de
-- venta van con pausas, así que una tanda pendiente de una visita anterior
-- (cerrar y abrir enseguida) se reconoce por su número y no hace nada.

local visit = { id = 0, open = false }

local function startVisit()
    visit = { id = visit.id + 1, open = true, count = 0, value = 0, tried = {} }
end

local function isCurrent(id)
    return visit.open and visit.id == id
end

--------------------------------------------------------------------------------
-- Reparar
--------------------------------------------------------------------------------

local function repair()
    if not Merchant.IsRepairEnabled() or not Api.MerchantCanRepair() then return end
    local cost = Api.RepairCost()
    if cost <= 0 then return end
    if Api.Money() < cost then
        Util.Print("reparar cuesta %s y no te llega.", Api.MoneyText(cost))
        return
    end
    Api.RepairAll()
    Util.Print("equipo reparado por %s.", Api.MoneyText(cost))
end

--------------------------------------------------------------------------------
-- Vender la basura
--------------------------------------------------------------------------------

-- Clave de un hueco con su objeto, para no intentar dos veces la misma venta.
local function slotKey(item)
    return ("%d:%d:%d"):format(item.bag, item.slot, item.id)
end

-- Basura que se puede vender ahora. Lo bloqueado se está vendiendo (o
-- moviendo) y lo ya intentado en esta visita no se repite: si el vendedor
-- rechaza un objeto, no se insiste con él en cada tanda.
local function sellableJunk()
    local junk = {}
    for _, item in ipairs(Api.BagSlots()) do
        if item.quality == C.JUNK_QUALITY and not item.noValue and not item.locked
            and not visit.tried[slotKey(item)] then
            junk[#junk + 1] = item
        end
    end
    return junk
end

local function sell(item)
    visit.tried[slotKey(item)] = true
    Api.SellBagItem(item.bag, item.slot)
    visit.count = visit.count + 1
    visit.value = visit.value + Api.SellPrice(item.id) * item.count
end

local function reportSales()
    if visit.count == 0 then return end
    Util.Print("basura vendida: %d %s por %s.", visit.count,
        visit.count == 1 and "objeto" or "objetos", Api.MoneyText(visit.value))
end

-- Vende una tanda y, si queda basura, programa la siguiente. Al terminar
-- cuenta lo vendido y repara.
local function sellBatch(id)
    if not isCurrent(id) then return end
    local junk = sellableJunk()
    for i = 1, math.min(#junk, C.SELL_BATCH) do sell(junk[i]) end
    if #junk > C.SELL_BATCH then
        Util.After(C.SELL_INTERVAL, function() sellBatch(id) end)
    else
        reportSales()
        repair()
    end
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------

Util.On("MERCHANT_SHOW", function()
    startVisit()
    if Api.IsShiftDown() then return end
    if Merchant.IsJunkEnabled() then
        sellBatch(visit.id)
    else
        repair()
    end
end)

Util.On("MERCHANT_CLOSED", function()
    visit.open = false
end)
