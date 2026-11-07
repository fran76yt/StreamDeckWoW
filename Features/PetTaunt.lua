--[[
Aviso del taunt de la mascota
=============================

Avisa cuando el lanzamiento automático del taunt de la mascota (Bramido en el
cazador) no es el adecuado para donde estás:

  en mazmorra o banda, ACTIVADO     -> la mascota le quita los enemigos al tanque
  fuera de ellas, DESACTIVADO       -> la mascota no los aguanta y vienen a por ti

El aviso sale en el centro de la pantalla, en el chat y con un sonido, solo
para el jugador. Se da una vez cuando la situación pasa a estar mal (al entrar
o salir de una mazmorra, al invocar la mascota o al cambiar el automático) y,
si sigue mal, otra vez al entrar en combate. Cuando se corrige, una línea en
el chat lo confirma.

El addon solo avisa, no lo cambia él: activar o desactivar el automático de
una habilidad de la mascota es una acción protegida que exige que la haga el
jugador (clic derecho en la barra de la mascota).
]]

local _, ns = ...
local Const, Util, Api, Storage = ns.Const, ns.Util, ns.Api, ns.Storage
local C = Const.PET_TAUNT

local PetTaunt = {}
ns.PetTaunt = PetTaunt

-- true mientras la situación actual ya se ha avisado, para no repetirlo con
-- cada actualización de la barra de la mascota.
local warned = false

--------------------------------------------------------------------------------
-- Estado
--------------------------------------------------------------------------------

local tauntIDs = {}
for _, id in ipairs(C.SPELLS) do tauntIDs[id] = true end

-- Todos los rangos se llaman igual, así que basta el nombre del primero para
-- reconocerlo en clientes que no dan el ID en la barra de la mascota.
local function isTaunt(action)
    return tauntIDs[action.spellID] or action.name == Api.SpellName(C.SPELLS[1])
end

local function identity(v) return v end

-- El taunt en la barra de la mascota, o nil si no hay mascota o no lo tiene.
local function findTaunt()
    if not Api.HasPet() then return nil end
    return Util.FirstMatch(Api.PetActions(), isTaunt, identity)
end

-- Cómo debería estar el automático donde está el jugador ahora.
local function wantedAutoCast()
    return not C.OFF_IN[Api.InstanceType()]
end

--------------------------------------------------------------------------------
-- Mensajes
--------------------------------------------------------------------------------

local function problemText(name, wanted)
    if wanted then
        return ("%s de la mascota DESACTIVADO fuera de mazmorra: actívalo (clic derecho en la barra de la mascota) para que aguante a los enemigos."):format(name)
    end
    return ("%s de la mascota ACTIVADO en mazmorra o banda: desactívalo (clic derecho en la barra de la mascota) para no quitarle los enemigos al tanque."):format(name)
end

local function fixedText(name, wanted)
    return ("%s de la mascota %s: correcto."):format(name, wanted and "activado" or "desactivado")
end

local function alert(text)
    Api.ShowCenterWarning(text)
    Api.PlayWarningSound()
    Util.Print(Util.Colorize(Const.COLOR.MISSING, text))
end

--------------------------------------------------------------------------------
-- Comprobación
--------------------------------------------------------------------------------

-- remind = true repite el aviso aunque ya se hubiera dado (al entrar en combate).
local function check(remind)
    if Storage.GetPetTaunt().off then return end
    local taunt = findTaunt()
    -- Sin mascota no hay nada que avisar; al volver a invocarla se avisa de
    -- nuevo si sigue mal, porque es otro momento en que conviene saberlo.
    if not taunt then warned = false return end

    local wanted = wantedAutoCast()
    if taunt.autoCast == wanted then
        if warned then Util.Print(fixedText(taunt.name, wanted)) end
        warned = false
    elseif not warned or remind then
        warned = true
        alert(problemText(taunt.name, wanted))
    end
end

-- Las actualizaciones de la barra llegan en ráfagas (al invocar, al salir de
-- una pantalla de carga): se agrupan y se comprueba una vez.
local checkSoon = Util.Debounce(C.CHECK_DELAY, function() check(false) end)

Util.On("PLAYER_ENTERING_WORLD", checkSoon)   -- al entrar y tras cada pantalla de carga
Util.On("ZONE_CHANGED_NEW_AREA", checkSoon)
Util.On("PET_BAR_UPDATE", checkSoon)          -- también al cambiar el automático
Util.On("UNIT_PET", function(unit)
    if unit == "player" then checkSoon() end
end)
if C.REMIND_ON_COMBAT then
    Util.On("PLAYER_REGEN_DISABLED", function() check(true) end)
end

--------------------------------------------------------------------------------
-- API del módulo
--------------------------------------------------------------------------------

-- Encender o apagar el aviso. Al encenderlo se comprueba enseguida, para que
-- avise si ya está mal.
local switch = Util.Switch(Storage.GetPetTaunt, function(on)
    warned = false
    if on then check(false) end
end)
PetTaunt.IsEnabled, PetTaunt.SetEnabled, PetTaunt.Toggle = switch.IsEnabled, switch.SetEnabled, switch.Toggle
