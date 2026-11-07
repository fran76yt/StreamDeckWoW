--[[
Sección del cazador
===================

Opciones propias del cazador en /sdeck config, en tres páginas:
  Mascota    aviso del taunt de la mascota
  Munición   aviso de munición baja y sus umbrales por tipo de arma
  Aspectos   aviso de aspecto y qué aspectos valen
Solo describe las filas (ver UI/OptionsPage.lua); el estado lo guardan los
módulos de Features/.
]]

local _, ns = ...
local Const, Util = ns.Const, ns.Util
local AMMO, ASPECT, UI = Const.AMMO, Const.ASPECT, Const.UI

--------------------------------------------------------------------------------
-- Mascota
--------------------------------------------------------------------------------

local petPage = {
    title = "Mascota",
    rows = {
        {
            kind = "check",
            label = "Avisar del taunt de la mascota (Bramido)",
            tooltip = {
                "Aviso del taunt de la mascota",
                "Avisa si el Bramido automático está activado en mazmorra o banda",
                "(le quita los enemigos al tanque) o desactivado fuera de ellas.",
                "También con /sdeck aviso.",
            },
            get = function() return ns.PetTaunt.IsEnabled() end,
            set = function(on) ns.PetTaunt.SetEnabled(on) end,
        },
        { kind = "note", text = "En mazmorra y banda el Bramido automático debe ir desactivado; fuera, activado, para que la mascota aguante a los enemigos. El aviso sale en el centro de la pantalla, con sonido." },
    },
}

--------------------------------------------------------------------------------
-- Munición
--------------------------------------------------------------------------------

-- Fila de umbrales de un tipo de munición: dos cajas, aviso y crítico.
local function ammoRow(ammoType)
    local info = AMMO.TYPES[ammoType]
    local function field(which)
        return {
            get = function() return ns.Ammo.GetThreshold(ammoType, which) end,
            set = function(value) ns.Ammo.SetThreshold(ammoType, which, value) end,
        }
    end
    return {
        kind = "numbers",
        label = info.label,
        tooltip = {
            info.label,
            "Ámbar: avisa con menos de esta cantidad.",
            "Rojo: casi sin munición (no puede ser mayor que el ámbar).",
            ("Por defecto %d y %d. Intro para aplicar; 0 en ámbar apaga el aviso de este tipo."):format(info.low, info.critical),
        },
        fields = { field("low"), field("critical") },
    }
end

local ammoRows = {
    {
        kind = "check",
        label = "Avisar de munición baja",
        tooltip = {
            "Aviso de munición baja",
            "Un recuadro discreto cuando quedan pocas flechas o balas,",
            "según los umbrales de abajo. Se puede mover arrastrándolo.",
            "También con /sdeck municion.",
        },
        get = function() return ns.Ammo.IsEnabled() end,
        set = function(on) ns.Ammo.SetEnabled(on) end,
    },
    { kind = "columns", label = "Avisar con menos de", columns = { "Ámbar", "Rojo" } },
}
for _, ammoType in ipairs(AMMO.TYPE_ORDER) do
    ammoRows[#ammoRows + 1] = ammoRow(ammoType)
end
ammoRows[#ammoRows + 1] = { kind = "note", text = "Pulsa Intro o haz clic fuera para aplicar. 0 en ámbar apaga el aviso de ese tipo." }

--------------------------------------------------------------------------------
-- Aspectos
--------------------------------------------------------------------------------

-- Casilla de un aspecto, con su icono (que se pide al juego al dibujar la
-- ventana, cuando ya está cargado).
local function aspectCheck(aspect)
    return {
        label = aspect.label,
        icon = function() return ns.Api.SpellIcon(aspect.spells[1]) end,
        tooltip = {
            ns.Api.SpellName(aspect.spells[1]) or aspect.label,
            "Marcado: llevarlo cuenta como aspecto puesto.",
            "Sin marcar: si lo llevas, el aviso sale en rojo.",
        },
        get = function() return ns.Aspect.IsChosen(aspect) end,
        set = function(on) ns.Aspect.SetChosen(aspect, on) end,
    }
end

local aspectRows = {
    {
        kind = "check",
        label = "Avisar si no llevo un aspecto de los marcados",
        tooltip = {
            "Aviso de aspecto",
            "Un recuadro discreto si no llevas aspecto (ámbar) o si llevas",
            "uno sin marcar, como el guepardo en combate (rojo).",
            "También con /sdeck aspecto.",
        },
        get = function() return ns.Aspect.IsEnabled() end,
        set = function(on) ns.Aspect.SetEnabled(on) end,
    },
    {
        kind = "check",
        label = "Solo en combate",
        tooltip = {
            "Solo en combate",
            "Fuera de combate no avisa: puedes viajar con el guepardo.",
            "Desmárcala para que avise siempre.",
        },
        get = function() return ns.Aspect.IsCombatOnly() end,
        set = function(on) ns.Aspect.SetCombatOnly(on) end,
    },
    { kind = "header", label = "Aspectos que valen" },
}
local aspectChecks = {}
for i, aspect in ipairs(ASPECT.LIST) do aspectChecks[i] = aspectCheck(aspect) end
for _, items in ipairs(Util.Chunk(aspectChecks, UI.CHECKS_PER_ROW)) do
    aspectRows[#aspectRows + 1] = { kind = "checks", items = items }
end
aspectRows[#aspectRows + 1] = { kind = "note", text = "Ámbar: no llevas aspecto. Rojo: llevas uno sin marcar. El recuadro se puede mover arrastrándolo." }

--------------------------------------------------------------------------------
-- Registro
--------------------------------------------------------------------------------

ns.ClassPages.Register("HUNTER", {
    title = "Cazador",
    pages = {
        petPage,
        { title = "Munición", rows = ammoRows },
        { title = "Aspectos", rows = aspectRows },
    },
})
