--[[
Asignación de atajos
====================

Convierte cada hueco resuelto en un atajo real del juego.

Usamos SetOverrideBinding* y no SetBinding*:
  * SetBinding cambia los atajos guardados del jugador (se sincronizan con el
    servidor) y el cambio se queda aunque se desinstale el addon.
  * SetOverrideBinding crea una capa temporal asociada a un frame "propietario",
    con prioridad sobre los atajos normales. No se guarda en ningún sitio y
    desaparece con ClearOverrideBindings o al desactivar el addon.

Cada vez se rehacen los 12 atajos desde cero: es más simple que calcular
diferencias y, con 12 huecos, el coste es despreciable.
]]

local _, ns = ...
local Const, Util, Api, Keys, Slots, Storage = ns.Const, ns.Util, ns.Api, ns.Keys, ns.Slots, ns.Storage

local Bindings = {}
ns.Bindings = Bindings

-- Frame propietario de los override bindings. No se muestra nunca.
local owner = CreateFrame("Frame")

-- Una función de asignación por tipo de resolución. El segundo parámetro
-- (isPriority = false) basta: cualquier override ya gana a los atajos normales.
local binders = {
    spell = function(key, target) SetOverrideBindingSpell(owner, false, key, target) end,
    item  = function(key, target) SetOverrideBindingItem(owner, false, key, target) end,
    macro = function(key, target) SetOverrideBindingMacro(owner, false, key, target) end,
}

-- Lo último asignado a cada hueco (para /sdeck).
local targets = {}

-- Asigna el hueco n y devuelve su foto y si quedó asignado.
local function bindSlot(n)
    local entry = Slots.Entry(n)
    local res = Slots.Resolve(entry)
    if res then binders[res.kind](Keys.For(n), res.target) end
    targets[n] = res and res.target
    return Slots.Snapshot(entry, res), res ~= nil
end

-- Recalcula y asigna todos los huecos, guarda la foto y avisa al resto.
local function bindAll()
    if not Api.IsLoggedIn() then return end   -- la clase aún no se conoce
    ClearOverrideBindings(owner)
    local snapshot, ready = {}, 0
    for n = 1, Const.NUM_SLOTS do
        local slot, bound = bindSlot(n)
        snapshot[n] = slot
        if bound then ready = ready + 1 end
    end
    Storage.SaveSnapshot(snapshot, Api.PlayerClass())
    Util.Fire(Const.MSG.SLOTS_UPDATED, ready)
end

--------------------------------------------------------------------------------
-- API del módulo
--------------------------------------------------------------------------------

-- Recalcular ya (o al salir de combate, si estamos en combate).
function Bindings.Refresh()
    Util.OutOfCombat(bindAll)
end

-- Recalcular agrupando ráfagas de eventos en una sola actualización.
Bindings.RefreshSoon = Util.Debounce(Const.REFRESH_DELAY, Bindings.Refresh)

-- Lo asignado al hueco n, o nil.
function Bindings.Target(n)
    return targets[n]
end

--------------------------------------------------------------------------------
-- Cuándo recalcular
--------------------------------------------------------------------------------
Util.On("PLAYER_LOGIN", Bindings.Refresh)
for _, event in ipairs(Const.REFRESH_EVENTS) do
    Util.On(event, Bindings.RefreshSoon)
end
Util.Listen(Const.MSG.SLOT_CHANGED, Bindings.Refresh)
