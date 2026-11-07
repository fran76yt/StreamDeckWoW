--[[
Pestañas por clase
==================

Cada clase puede añadir una pestaña a la ventana de configuración con sus
opciones propias. Igual que los valores por defecto (Defaults/Classes), cada
clase va en su archivo y se registra aquí:

  ns.ClassTabs.Register("HUNTER", { title = "Cazador", rows = { ... } })

Las filas se describen como en UI/OptionsPage.lua. La ventana solo muestra la
pestaña de la clase del personaje con el que juegas: un guerrero no ve las
opciones del cazador.

Añadir una clase: crear UI/ClassTabs/<Clase>.lua y añadirlo al .toc.
]]

local _, ns = ...

local ClassTabs = {}
ns.ClassTabs = ClassTabs

local tabs = {}

-- class: clase en inglés y mayúsculas, como la devuelve Api.PlayerClass().
function ClassTabs.Register(class, tab)
    tabs[class] = tab
end

function ClassTabs.For(class)
    return tabs[class]
end
