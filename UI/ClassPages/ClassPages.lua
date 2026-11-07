--[[
Secciones por clase
===================

Cada clase puede añadir a la ventana de configuración un grupo de páginas
con sus opciones propias, que salen en la barra lateral bajo el nombre de la
clase. Igual que los valores por defecto (Defaults/Classes), cada clase va en
su archivo y se registra aquí:

  ns.ClassPages.Register("HUNTER", {
      title = "Cazador",
      pages = {
          { title = "Mascota", rows = { ... } },
          { title = "Munición", rows = { ... } },
      },
  })

Las filas se describen como en UI/OptionsPage.lua. La ventana solo muestra
la sección de la clase del personaje con el que juegas: un guerrero no ve las
opciones del cazador.

Añadir una clase: crear UI/ClassPages/<Clase>.lua y añadirlo al .toc.
]]

local _, ns = ...

local ClassPages = {}
ns.ClassPages = ClassPages

local sections = {}

-- class: clase en inglés y mayúsculas, como la devuelve Api.PlayerClass().
function ClassPages.Register(class, section)
    sections[class] = section
end

function ClassPages.For(class)
    return sections[class]
end
