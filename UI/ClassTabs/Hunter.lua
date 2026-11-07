--[[
Pestaña del cazador
===================

Opciones propias del cazador en /sdeck config: los avisos del taunt de la
mascota y de munición baja, y los umbrales de munición por tipo de arma.
Solo describe las filas (ver UI/OptionsPage.lua); el estado lo guardan los
módulos de Features/.
]]

local _, ns = ...
local AMMO = ns.Const.AMMO

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

local rows = {
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
    { kind = "columns", label = "Munición: avisar con menos de", columns = { "Ámbar", "Rojo" } },
}
for _, ammoType in ipairs(AMMO.TYPE_ORDER) do
    rows[#rows + 1] = ammoRow(ammoType)
end
rows[#rows + 1] = { kind = "note", text = "Pulsa Intro o haz clic fuera para aplicar. 0 en ámbar apaga el aviso de ese tipo." }

ns.ClassTabs.Register("HUNTER", { title = "Cazador", rows = rows })
