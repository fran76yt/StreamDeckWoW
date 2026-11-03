--[[
Valores por defecto del cazador.
]]

local _, ns = ...

ns.Defaults.RegisterClass("HUNTER", {
    [2]  = { short = "Guepardo",   spells = { 5118 } },
    [3]  = { short = "Llamar",     spells = { 883 } },
    [4]  = { short = "Revivir",    spells = { 982 } },
    [5]  = { short = "Alimentar",  spells = { 6991 } },
    -- Profesiones: un ID por rango (artesano, experto, oficial, aprendiz).
    [8]  = { short = "Cocina",     spells = { 18260, 3413, 3102, 2550 } },
    [9]  = { short = "Peletería",  spells = { 10662, 3811, 3104, 2108 } },
    [10] = { short = "Hierbas",    spells = { 2383 } },
    [11] = { short = "Alquimia",   spells = { 11611, 3464, 3101, 2259 } },
})
