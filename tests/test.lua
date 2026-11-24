--[[
Pruebas de StreamDeckWoW
========================

Las ejecuta tests/run.js después de cargar la API simulada
(tests/api_stubs.lua) y el addon. Cada check() que pasa escribe "ok" y el
primero que falla para con un error. Al final, __SV guarda las
SavedVariables del personaje para revisarlas (tests/out/).
]]

local ns = StreamDeckWoW
local function check(cond, msg) if not cond then error("FALLO: " .. msg) end io.write("ok  ", msg, "\n") end
local K = function(n) return "ALT-CTRL-SHIFT-F" .. n end
local function hasPrinted(text) for _, l in ipairs(printed) do if l:find(text, 1, true) then return true end end end
-- error al cargar, antes de que el juego lea la variable de la cuenta
ns.Util.On("PRUEBA_TEMPRANA", function() error("prueba de error temprana") end)
fire("PRUEBA_TEMPRANA")
check(hasPrinted("se ha producido un error de Lua") , "aviso en el chat del primer error")
StreamDeckWoWLog = { entries = {} }
fire("ADDON_LOADED", "OtroAddon")
fire("ADDON_LOADED", __ADDON)
printed = {}

fire("PLAYER_LOGIN")
check(next(binds) == nil, "antes de cargar el personaje no se asigna nada")
loggedIn = true
printed = {}
fire("PLAYER_LOGIN")
check(binds[K(3)] == "spell:Llamar a mascota", "F3 = Llamar a mascota")
check(binds[K(6)] == "item:Poción de curación", "F6 = mejor poción que llevas")
check(binds[K(2)] == nil, "F2 sin asignar (guepardo no aprendido)")
check(printed[1] and printed[1]:find("7 de 12"), "resumen al entrar: " .. tostring(printed[1]))
local s = StreamDeckWoWChar.slots
check(s[3].active and s[3].kind == "spell" and s[3].id == 883 and s[3].short == "Llamar", "foto del hueco 3")
check(not s[2].active and s[2].kind == "spell" and s[2].id == 5118, "hueco 2 atenuado con icono del guepardo")
check(not s[12].active and s[12].kind == nil and s[12].name == "Campamento" and not s[12].empty, "hueco 12 Campamento sin icono")

-- cursor -> entrada
cursor = { "spell", 5, 0, 1494 }
local e = ns.Api.CursorEntry()
check(e and e.kind == "spell" and e.id == 1494, "cursor con hechizo")
cursor = { "macro", 1 }
e = ns.Api.CursorEntry()
check(e and e.kind == "macro" and e.name == "Trampa", "cursor con macro")
cursor = { "mount", 1 }
check(ns.Api.CursorEntry() == nil, "cursor con montura: no se admite")
cursor = nil

-- ventana y cambios de huecos
SlashCmdList.STREAMDECKWOW("config")
local win
for _, f in ipairs(frames) do if rawget(f, "_OnShow") and rawget(f, "_OnDragStart") then win = f end end
check(win and rawget(win, "_shown") == true, "el primer /sdeck config muestra la ventana")
SlashCmdList.STREAMDECKWOW("config")
check(rawget(win, "_shown") == false, "el segundo /sdeck config la oculta")
SlashCmdList.STREAMDECKWOW("config")
known[1494] = true
ns.Slots.Set(12, { kind = "spell", id = 1494 })
check(binds[K(12)] == "spell:Rastrear bestias", "F12 personalizado = Rastrear bestias")
ns.Slots.Set(7, { kind = "item", id = 4604 })
check(binds[K(7)] == "item:Seta de bosque", "F7 personalizado = objeto")
ns.Slots.Set(9, { kind = "macro", name = "Trampa" })
check(binds[K(9)] == "macro:Trampa", "F9 personalizado = macro")
spellnames[9999] = "Hechizo futuro"
ns.Slots.Set(10, { kind = "spell", id = 9999 })
check(binds[K(10)] == "spell:Hechizo futuro", "lo arrastrado que aún no tienes se asigna igual")
check(StreamDeckWoWChar.slots[10].active == false, "pero sale como no disponible (gris)")
printed = {}
SlashCmdList.STREAMDECKWOW("estado")
check(printed[11] and printed[11]:find("Hechizo futuro: no lo tienes", 1, true), "y en rojo en /sdeck")
ns.Slots.Set(4, { kind = "item", id = 7777 })
check(binds[K(4)] == "item:item:7777" and requested[7777], "objeto sin caché: se usa item:N y se piden sus datos")
check(StreamDeckWoWChar.slots[4].active == false, "objeto arrastrado que no llevas: no disponible")
check(StreamDeckWoWChar.slots[4].name == nil, "objeto sin cargar: no se enseña item:N")
printed = {}
SlashCmdList.STREAMDECKWOW("estado")
check(printed[5] and printed[5]:find("objeto 7777 (cargando datos)", 1, true), "/sdeck: objeto 7777 (cargando datos)")
timers = {}
fire("GET_ITEM_INFO_RECEIVED", 5555, true)
check(#timers == 0, "datos de un objeto que no pidió el addon: no recalcula")
fire("GET_ITEM_INFO_RECEIVED", 7777, false)
check(#timers == 0, "carga fallida: no recalcula (sin bucle)")
ns.Slots.Set(4, { kind = "item", id = 7777 })   -- se vuelve a pedir
names[7777] = "Objeto nuevo"
fire("GET_ITEM_INFO_RECEIVED", 7777, true)
check(#timers == 1, "datos del objeto pedido: recalcula")
runTimers()
check(StreamDeckWoWChar.slots[4].name == "Objeto nuevo" and binds[K(4)] == "item:Objeto nuevo", "al llegar los datos se usa el nombre")
ns.Slots.Set(4, nil)
ns.Slots.Set(10, nil)
ns.Slots.Set(11, false)
check(binds[K(11)] == nil and StreamDeckWoWChar.slots[11].empty, "F11 vaciado")
ns.Slots.Set(7, nil)
check(binds[K(7)] == nil and StreamDeckWoWChar.slots[7].name == "Maná", "F7 vuelve al valor por defecto")

-- botón del minimapa
local mb = _G.StreamDeckWoWMinimapButton
local function near(a, b) return math.abs(a - b) < 0.01 end
local function at(x, y) local p = rawget(mb, "_point") return p[2] == Minimap and near(p[4], x) and near(p[5], y) end
check(mb and rawget(mb, "_shown") ~= false, "al entrar aparece el botón del minimapa")
check(at(-75 * math.sqrt(0.5), -75 * math.sqrt(0.5)), "en su sitio por defecto (abajo a la izquierda, en el borde)")
cursorXY = { (500 + 100) * 2, 400 * 2 }
rawget(mb, "_OnDragStart")(mb)
check(rawget(mb, "_OnUpdate") ~= nil, "al arrastrar sigue al ratón")
rawget(mb, "_OnUpdate")(mb)
check(at(75, 0), "se mueve hacia donde está el ratón (teniendo en cuenta la escala)")
rawget(mb, "_OnDragStop")(mb)
check(rawget(mb, "_OnUpdate") == nil and near(StreamDeckWoWChar.minimap.angle, 0), "al soltar deja de seguirlo y guarda el ángulo")
GetMinimapShape = function() return "SQUARE" end
cursorXY = { (500 + 100) * 2, (400 + 100) * 2 }
rawget(mb, "_OnDragStart")(mb); rawget(mb, "_OnUpdate")(mb); rawget(mb, "_OnDragStop")(mb)
check(at(75, 75), "con minimapa cuadrado recorre el borde hasta la esquina")
GetMinimapShape = nil
local winShown = rawget(win, "_shown")
rawget(mb, "_OnClick")(mb, "LeftButton")
check(rawget(win, "_shown") ~= winShown, "clic: abre o cierra la ventana")
rawget(mb, "_OnClick")(mb, "LeftButton")
printed = {}
rawget(mb, "_OnClick")(mb, "RightButton")
check(printed[1] and printed[1]:find("estado de las teclas") and #printed == 13, "clic derecho: estado en el chat")
SlashCmdList.STREAMDECKWOW("minimapa")
check(rawget(mb, "_shown") == false and StreamDeckWoWChar.minimap.hidden == true, "/sdeck minimapa lo oculta y lo recuerda")
SlashCmdList.STREAMDECKWOW("Minimapa")
check(rawget(mb, "_shown") == true and StreamDeckWoWChar.minimap.hidden == nil, "otra vez lo muestra")

-- combate
combat = true; bags[929] = 0
fire("BAG_UPDATE_DELAYED"); fire("BAG_UPDATE_DELAYED"); runTimers()
check(binds[K(6)] == "item:Poción de curación", "en combate no se toca nada")
combat = false; fire("PLAYER_REGEN_ENABLED")
check(binds[K(6)] == "item:Poción de Curación inferior", "tras el combate pasa a la siguiente poción")

combat = true
local ran = false
ns.Util.OutOfCombat(function() error("fallo provocado") end)
ns.Util.OutOfCombat(function() ran = true end)
printed = {}
combat = false; fire("PLAYER_REGEN_ENABLED")
check(ran, "un fallo en una función aplazada no impide las demás")
check(printed[1] and printed[1]:find("fallo provocado"), "y el error se muestra")
printed = {}
SlashCmdList.STREAMDECKWOW("")
check(#printed == 13, "/sdeck muestra 12 líneas + cabecera")
for _, l in ipairs(printed) do io.write("    ", l, "\n") end
printed = {}
SlashCmdList.STREAMDECKWOW("loquesea")
check(printed[1] and printed[1]:find("Comandos"), "subcomando desconocido muestra la ayuda")
check(printed[1]:find("versión 0.1.0", 1, true), "la ayuda muestra la versión")
check(printed[1]:find("Media\\Icon:14:14", 1, true), "el prefijo del chat lleva el icono")

-- comandos que se mudaron a FranTools
local function hasPrinted(text) for _, l in ipairs(printed) do if l:find(text, 1, true) then return true end end end
printed = {}
SlashCmdList.STREAMDECKWOW("aviso")
check(hasPrinted("FranTools: /fran aviso"), "un comando que se mudó a FranTools dice dónde está")
check(StreamDeckWoWChar.petTaunt == nil, "y no guarda nada")
SlashCmdList.STREAMDECKWOW("ayuda")
check(not hasPrinted("/sdeck municion"), "la ayuda ya no lista los avisos")
-- registro de errores
local Log = ns.ErrorLog
local function ownErrors() local n = 0 for _, l in ipairs(printed) do if l:find("prueba de error", 1, true) then n = n + 1 end end return n end
check(Log.Entries()[1].message:find("prueba de error temprana", 1, true), "un error antes de cargar la variable se guarda al cargarla")
local base = #Log.Entries()
check(StreamDeckWoWLog.entries[1].count == 1 and StreamDeckWoWLog.entries[1].version == "0.1.0", "con cuántas veces y la versión")
local after = false
ns.Util.On("PRUEBA_ERROR", function() error("prueba de error en un evento") end)
ns.Util.On("PRUEBA_ERROR", function() after = true end)
printed = {}
fire("PRUEBA_ERROR")
check(after, "un error en una función de un evento no impide las demás")
check(ownErrors() >= 1, "el error sigue llegando al manejador de antes")
check(#Log.Entries() == base + 1 and Log.Entries()[base + 1].stack:find("Prueba.lua:7", 1, true), "se apunta con su pila")
check(not Log.Entries()[base + 1].stack:find("ErrorLog.lua", 1, true), "sin las líneas del propio registro")
fire("PRUEBA_ERROR")
check(#Log.Entries() == base + 1 and Log.Entries()[base + 1].count == 2, "el mismo error otra vez suma, no se repite")
local notices = 0 for _, l in ipairs(printed) do if l:find("/sdeck errores para verlo", 1, true) then notices = notices + 1 end end
check(notices == 0, "el aviso del chat solo sale una vez por sesión (ya salió con el primero)")
fakeStack = "Interface/AddOns/OtroAddon/Main.lua:3: in function <y>"
geterrorhandler()("Interface/AddOns/OtroAddon/Main.lua:3: prueba de error ajena")
check(#Log.Entries() == base + 1 and ownErrors() == 3, "los errores de otros addons no se apuntan, pero siguen su camino")
fakeStack = string.rep("Interface/AddOns/StreamDeckWoW/Core/Larga.lua:1: in function <z>\n", 100)
geterrorhandler()("prueba de error larga")
check(#Log.Entries()[base + 2].stack <= ns.FranLib.errorLog.MAX_STACK_CHARS, "la pila se recorta")
fakeStack = nil
printed = {}
SlashCmdList.STREAMDECKWOW("errores")
check(hasPrinted((base + 2) .. " errores apuntados") and hasPrinted("x2  ") and hasPrinted("prueba de error en un evento"), "/sdeck errores: la lista")
printed = {}
SlashCmdList.STREAMDECKWOW("errores " .. (base + 1))
check(hasPrinted("error " .. (base + 1) .. ", versión 0.1.0, 2 veces") and hasPrinted("Core/Prueba.lua:7"), "/sdeck errores <n>: uno con su pila, sin la ruta del addon")
printed = {}
SlashCmdList.STREAMDECKWOW("errores 9")
check(hasPrinted("no hay ningún error con el número 9"), "un número que no está")
for i = 1, 60 do geterrorhandler()("prueba de error número " .. i) end
check(#Log.Entries() == ns.FranLib.errorLog.MAX_ENTRIES and Log.Entries()[1].message == "prueba de error número 11", "como mucho 50: se van los más antiguos")
SlashCmdList.STREAMDECKWOW("errores borrar")
check(#Log.Entries() == 0 and #StreamDeckWoWLog.entries == 0, "/sdeck errores borrar vacía la lista")
local kept = {} for _, l in ipairs(printed) do if not l:find("prueba de error", 1, true) then kept[#kept + 1] = l end end
printed = kept

check(not hasPrinted("ERROR"), "sin errores de Lua")
__SV = dumpSV()
