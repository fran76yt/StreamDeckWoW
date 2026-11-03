--[[
Valores por defecto comunes a todas las clases.
]]

local _, ns = ...

ns.Defaults.RegisterCommon({
    [1] = { short = "Hogar", items = { 6948 } },
    -- Pociones de curación y de maná, de sublime a menor.
    [6] = { short = "Vida",  items = { 13446, 3928, 1710, 929, 858, 118 } },
    [7] = { short = "Maná",  items = { 13444, 13443, 6149, 3827, 3385, 2455 } },
    -- Sistema de acampada de Forever, disponible para todas las clases. Aún no
    -- conocemos el ID de la habilidad: se prueban sus posibles nombres.
    [12] = { short = "Campamento", names = { "Campamento", "Acampar", "Montar campamento" } },
})
