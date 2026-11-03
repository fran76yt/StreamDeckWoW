--[[
Valores por defecto de los huecos: registro
===========================================

Qué trae cada hueco si el jugador no lo ha cambiado. Este archivo solo tiene
el registro y la búsqueda; los datos están en Common.lua (todas las clases) y
en Classes\<Clase>.lua (uno por clase). Añadir una clase es crear su archivo
y listarlo en el .toc.

Cada hueco se define con un texto corto para la tecla ("short") y una de:

  items  = { id, ... }      Objetos del mejor al peor; se usa el primero que
                            lleves en las bolsas (la poción se adapta al nivel).
  spells = { id, ... }      Hechizos; se usa el primero que conozcas. Para las
                            profesiones se listan todos los rangos.
  names  = { "nombre", ...} Nombres a probar cuando aún no conocemos el ID
                            (habilidades nuevas de Forever).

Se usan IDs siempre que se puede: no cambian con el idioma del cliente.
]]

local _, ns = ...

local Defaults = {}
ns.Defaults = Defaults

local common = {}
local classes = {}   -- nombre interno de la clase en inglés (HUNTER, WARRIOR...) -> huecos

-- Huecos comunes a todas las clases.
function Defaults.RegisterCommon(slots)
    for n, entry in pairs(slots) do common[n] = entry end
end

-- Huecos de una clase. Tienen prioridad sobre los comunes con el mismo número.
function Defaults.RegisterClass(class, slots)
    classes[class] = classes[class] or {}
    for n, entry in pairs(slots) do classes[class][n] = entry end
end

-- Valor por defecto del hueco n para una clase (o nil si no hay ninguno).
function Defaults.For(class, n)
    local classSlots = classes[class]
    return (classSlots and classSlots[n]) or common[n]
end
