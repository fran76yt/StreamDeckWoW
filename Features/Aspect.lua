--[[
Aviso de aspecto
================

Un recuadro discreto (UI/NoticeBox.lua), como el de la munición, cuando el
cazador no lleva ninguno de los aspectos que ha elegido en la ventana:

  sin aspecto                       -> borde ámbar, "Sin aspecto"
  con un aspecto no elegido         -> borde rojo, "Aspecto: Guepardo"
                                       (el típico: entrar en combate con el
                                       guepardo y quedarse aturdido)

El icono es el del primer aspecto elegido, el que toca ponerse. Por defecto
solo avisa en combate, para poder viajar con el guepardo sin que salte; se
puede hacer que avise siempre. No avisa muerto, ni de aspectos que aún no
has aprendido (a nivel bajo no hay nada que avisar).

Los aspectos que valen se eligen en /sdeck config, sección Aspectos. Por
defecto, los de combate: halcón y mono.
]]

local _, ns = ...
local Const, Util, Api, Storage = ns.Const, ns.Util, ns.Api, ns.Storage
local C = Const.ASPECT

local Aspect = {}
ns.Aspect = Aspect

--------------------------------------------------------------------------------
-- Preferencias
--------------------------------------------------------------------------------

local function changed()
    Aspect.Check()
    Util.Fire(Const.MSG.SETTINGS_CHANGED)
end

-- Si un aspecto cuenta como válido: lo elegido por el jugador o, si no lo ha
-- tocado, el valor por defecto. Solo lee, para no dejar tablas vacías.
function Aspect.IsChosen(aspect)
    local chosen = Storage.GetAspect().chosen
    local saved = chosen and chosen[aspect.key]
    if saved == nil then return aspect.default end
    return saved
end

function Aspect.SetChosen(aspect, on)
    local settings = Storage.GetAspect()
    settings.chosen = settings.chosen or {}
    Util.SetOverride(settings.chosen, aspect.key, on and true or false, aspect.default)
    changed()
end

-- Se guarda al revés (anytime) para que lo normal, solo en combate, no ocupe
-- nada en el archivo.
function Aspect.IsCombatOnly()
    return not Storage.GetAspect().anytime
end

function Aspect.SetCombatOnly(on)
    Storage.GetAspect().anytime = (not on) or nil
    changed()
end

--------------------------------------------------------------------------------
-- Reconocer el aspecto puesto
--------------------------------------------------------------------------------

-- Aspecto de cada ID de hechizo, de todos los rangos.
local byID = {}
for _, aspect in ipairs(C.LIST) do
    for _, id in ipairs(aspect.spells) do byID[id] = aspect end
end

-- Por nombre para clientes que no dan el ID del aura. El nombre sale del
-- juego (va en su idioma) y solo se puede pedir con el personaje cargado.
local function byName(name)
    for _, aspect in ipairs(C.LIST) do
        if Api.SpellName(aspect.spells[1]) == name then return aspect end
    end
end

-- Aspecto que lleva puesto el jugador, o nil.
local function activeAspect()
    for _, buff in ipairs(Api.PlayerBuffs()) do
        local aspect = byID[buff.spellID] or byName(buff.name)
        if aspect then return aspect end
    end
end

local function isKnown(aspect)
    for _, id in ipairs(aspect.spells) do
        if Api.IsSpellKnown(id) then return true end
    end
    return false
end

-- Aspectos elegidos que el jugador ya sabe usar, en el orden de la lista.
local function wantedAspects()
    local wanted = {}
    for _, aspect in ipairs(C.LIST) do
        if Aspect.IsChosen(aspect) and isKnown(aspect) then wanted[#wanted + 1] = aspect end
    end
    return wanted
end

--------------------------------------------------------------------------------
-- Aviso
--------------------------------------------------------------------------------

-- Si toca comprobar ahora: aviso encendido, cazador, vivo y, salvo que avise
-- siempre, en combate.
local function shouldCheck()
    return Aspect.IsEnabled() and C.CLASSES[Api.PlayerClass()] and not Api.IsDead()
        and (not Aspect.IsCombatOnly() or Util.InCombat())
end

-- Icono, texto y nivel del aviso, o nil si no hay nada que avisar.
local function notice()
    if not shouldCheck() then return nil end
    local wanted = wantedAspects()
    if #wanted == 0 then return nil end
    local active = activeAspect()
    if active and Aspect.IsChosen(active) then return nil end
    local icon = Api.SpellIcon(wanted[1].spells[1])
    if active then return icon, ("Aspecto: %s"):format(active.label), "critical" end
    return icon, "Sin aspecto", "warning"
end

local box = ns.NoticeBox.Create({
    name = "StreamDeckWoWAspectNotice",
    settings = Storage.GetAspect,
    tooltip = {
        "Aspecto",
        "Ámbar: no llevas ningún aspecto.",
        "Rojo: llevas uno que no has elegido (por ejemplo, el guepardo en combate).",
        "Arrástralo para moverlo.",
        "Los aspectos que valen se eligen en /sdeck config, sección Aspectos.",
    },
})

function Aspect.Check()
    box:ShowIf(notice())
end

local checkSoon = Util.Debounce(C.CHECK_DELAY, Aspect.Check)

Util.On("UNIT_AURA", function(unit)
    if unit == "player" then checkSoon() end
end)
-- Al entrar y salir de combate (aparece o desaparece el aviso), al aprender
-- un aspecto nuevo y al morir o revivir.
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                         "SPELLS_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
    Util.On(event, checkSoon)
end

--------------------------------------------------------------------------------
-- API del módulo
--------------------------------------------------------------------------------

local switch = Util.Switch(Storage.GetAspect, function() Aspect.Check() end)
Aspect.IsEnabled, Aspect.SetEnabled, Aspect.Toggle = switch.IsEnabled, switch.SetEnabled, switch.Toggle
