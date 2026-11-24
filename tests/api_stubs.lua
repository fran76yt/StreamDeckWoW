--[[
API de WoW simulada para las pruebas
====================================

Archivo compartido: se edita en FranTools y se copia a los otros addons con
tools/sync_shared.py. tests/run.js lo carga antes que el addon.

Lo justo para que los addons carguen y se puedan probar fuera del juego:
frames que apuntan lo que se les hace (textos, scripts, si se ven), eventos
(fire), temporizadores (runTimers), y el estado del personaje en variables
globales que las pruebas cambian a voluntad: hechizos que sabe (known),
bolsas (bags), combate (combat), auras (playerBuffs), clase, dinero...

Lo que solo usa un addon (otro addon del que depende, por ejemplo) va en su
propio tests/stubs.lua.
]]

__SVNAME = __ADDON .. "Char"
known = { [883]=true, [982]=true, [6991]=true, [2550]=true, [3102]=true, [2383]=true }
bags  = { [6948]=1, [929]=3, [858]=2 }
names = { [6948]="Piedra de hogar", [929]="Poción de curación", [858]="Poción de Curación inferior", [4604]="Seta de bosque" }
icons = { [6948]=134414, [929]=134831, [858]=134830, [4604]=133970 }
spellnames = { [883]="Llamar a mascota", [982]="Revivir mascota", [6991]="Alimentar mascota",
  [3102]="Cocina", [2550]="Cocina", [2383]="Buscar hierbas", [5118]="Aspecto del guepardo", [1494]="Rastrear bestias" }
combat, binds, printed, timers, cursor, loggedIn, frames = false, {}, {}, {}, nil, false, {}
unpack = unpack or table.unpack
function print(s) printed[#printed+1] = s end
function time() return 1762200000 end
-- Objeto de interfaz simulado (frame, textura, texto...): cualquier método
-- que se le llame funciona y apunta lo que interesa comprobar. Es global
-- porque las pruebas también crean objetos sueltos (placas de nombre).
function newObj()
  local o = { _shown = true }
  frames[#frames+1] = o
  return setmetatable(o, { __index = function(t, k)
    if k == "TitleText" or k == "Text" or k:match("^%l") then return nil end
    return function(self, ...)
      if k == "SetScript" then rawset(self, "_" .. select(1, ...), select(2, ...)) end
      if k == "RegisterEvent" and unknownEvents[(...)] then error("Attempt to register unknown event \"" .. (...) .. "\"") end
      if k == "IsShown" then return rawget(self, "_shown") end
      if k == "SetShown" then local was = rawget(self, "_shown"); rawset(self, "_shown", (...)) if (...) and not was and rawget(self, "_OnShow") then rawget(self, "_OnShow")(self) end end
      if k == "Hide" then rawset(self, "_shown", false) end
      if k == "Show" then local was = rawget(self, "_shown"); rawset(self, "_shown", true) if not was and rawget(self, "_OnShow") then rawget(self, "_OnShow")(self) end end
      if k == "SetPoint" then rawset(self, "_point", { ... }) end
      if k == "GetPoint" then local p = rawget(self, "_point") if p then return unpack(p) end end
      if k == "GetName" then return rawget(self, "_name") end
      if k == "GetText" then return rawget(self, "_text") end
      if k == "SetEnabled" then rawset(self, "_enabled", (...)) end
      if k == "SetChecked" then rawset(self, "_checked", (...)) end
      if k == "GetChecked" then return rawget(self, "_checked") end
      if k == "SetText" then rawset(self, "_text", (...)) end
      if k == "GetStringHeight" then local t = rawget(self, "_text") return t and math.ceil(#t / 60) * 12 or 0 end
      if k == "SetTexture" then rawset(self, "_tex", (...)) end
      if k == "SetColorTexture" then rawset(self, "_ctex", { ... }) end
      if k == "SetVertexColorFromBoolean" then
        if secretPaintRefused then error("SetVertexColorFromBoolean(): secret values not allowed") end
        rawset(self, "_vcb", { ... })
      end
      if k == "SetFormattedText" then rawset(self, "_fmt", { ... }) end
      if k == "SetValue" then rawset(self, "_value", (...)) end
      if k == "GetStatusBarTexture" then
        local t = rawget(self, "_bartex") or newObj()
        rawset(self, "_bartex", t)
        return t
      end
      if k == "SetTextColor" then rawset(self, "_color", { ... }) end
      if k == "GetParent" then return rawget(self, "_parent") end
      if k == "SetDesaturated" then rawset(self, "_desat", (...)) end
      if k == "SetFrameLevel" then rawset(self, "_level", (...)) end
      if k == "GetFrameLevel" then return rawget(self, "_level") or 1 end
      if k == "CreateTexture" or k == "CreateFontString" then return newObj() end
    end
  end })
end
-- Eventos que no tiene el cliente simulado (como Forever): registrarlos da
-- error, igual que en el juego.
unknownEvents = { TRADE_SKILL_UPDATE = true }
C_EventUtils = { IsEventValid = function(event) return not unknownEvents[event] end }
function CreateFrame(_, name, parent) local o = newObj() rawset(o, "_parent", parent) if name then _G[name] = o rawset(o, "_name", name) end return o end
Minimap = newObj()
rawset(Minimap, "GetWidth", function() return 140 end)
rawset(Minimap, "GetCenter", function() return 500, 400 end)
rawset(Minimap, "GetEffectiveScale", function() return 2 end)
cursorXY = { 0, 0 }
function GetCursorPosition() return cursorXY[1], cursorXY[2] end
UIParent, UISpecialFrames, GameTooltip = newObj(), {}, newObj()
Enum = { SpellBookSpellBank = { Player = 0 } }
C_SpellBook = { IsSpellKnown = function(id) return known[id] or false end }
C_Spell = { GetSpellName = function(id) return spellnames[id] end, GetSpellTexture = function(id) return 100000 + id end,
            GetSpellInfo = function(n) return nil end }
requested = {}
C_Item = { GetItemCount = function(id) return bags[id] or 0 end, GetItemNameByID = function(id) return names[id] end,
           GetItemIconByID = function(id) return icons[id] end, RequestLoadItemDataByID = function(id) requested[id] = true end,
           GetItemInfo = function(id) if prices[id] then return "x", nil, nil, nil, nil, nil, nil, nil, nil, nil, prices[id] end end,
           GetItemInfoInstant = function(id) local c = itemClass[id] if c then return id, nil, nil, nil, nil, c[1], c[2] end end }
itemClass, equip, bagSlots = {}, {}, {}
function GetInventoryItemID(_, slot) return equip[slot] end
C_Container = { GetContainerNumSlots = function(b) return bagSlots[b] and #bagSlots[b] or 0 end,
                GetContainerItemInfo = function(b, s) return bagSlots[b] and bagSlots[b][s] or nil end,
                UseContainerItem = function(b, s) local it = bagSlots[b][s] sold[#sold+1] = it.itemID if not rejected[it.itemID] then bagSlots[b][s] = false end end }
local errorHandler = function(e) printed[#printed+1] = "ERROR: " .. tostring(e) end
function geterrorhandler() return errorHandler end
function seterrorhandler(fn) errorHandler = fn end
fakeStack = nil
function debugstack() return fakeStack or "Interface/AddOns/" .. __ADDON .. "/Core/Prueba.lua:7: in function <x>\n[C]: in function 'xpcall'" end
function date() return "2026-11-12 20:00" end
C_Timer = { After = function(_, fn) timers[#timers+1] = fn end }
function GetCursorInfo() if cursor then return unpack(cursor) end end
function ClearCursor() cursor = nil end
function GetMacroInfo(x) if x == 1 or x == "Trampa" then return "Trampa", 136000 end end
shift = false
function IsShiftKeyDown() return shift end
money, repairCost, canRepair, repaired, sold, prices, rejected = 5000, 0, true, 0, {}, {}, {}
function GetMoney() return money end
plates, threat = {}, { player = {}, pet = {} }
C_NamePlate = { GetNamePlateForUnit = function(u) return plates[u] end,
                GetNamePlates = function() local t = {} for u, pl in pairs(plates) do if not rawget(pl, "_modern") then rawset(pl, "namePlateUnitToken", u) end t[#t+1] = pl end return t end }
unitNames = {}
function UnitName(u) return unitNames[u] end
function UnitDetailedThreatSituation(who, u) local t = threat[who][u] if t then return t[1], t[2], t[3] end end
function UnitCanAttack(_, u) return u:find("^nameplate") ~= nil or u == "target" end
function CanMerchantRepair() return canRepair end
function GetRepairAllCost() return repairCost end
function RepairAllItems() repaired = repaired + 1 money = money - repairCost repairCost = 0 end
function IsLoggedIn() return loggedIn end
function InCombatLockdown() return combat end
function UnitClass() return "Cazador", "HUNTER" end
function ClearOverrideBindings() binds = {} end
function SetOverrideBindingItem(_, _, k, t) binds[k] = "item:" .. t end
function SetOverrideBindingSpell(_, _, k, t) binds[k] = "spell:" .. t end
function SetOverrideBindingMacro(_, _, k, t) binds[k] = "macro:" .. t end
function ReloadUI() end
pet, instance, petBar, warnings, sounds = false, "none", {}, {}, 0
function UnitExists(u) return u == "player" or (u == "pet" and pet) end
function IsInInstance() return instance ~= "none", instance end
function GetPetActionInfo(i) local a = petBar[i] if a then return a[1], nil, false, false, true, a[3], a[2] end end
RaidWarningFrame, ChatTypeInfo = {}, { RAID_WARNING = {} }
function RaidNotice_AddMessage(_, text) warnings[#warnings+1] = text end
SOUNDKIT = { RAID_WARNING = 8959 }
function PlaySound() sounds = sounds + 1 end
function GameTooltip_Hide() end
SlashCmdList = {}
playerBuffs, dead = {}, false
-- Valores secretos del cliente moderno: en combate oculta auras y amenaza.
SECRET = setmetatable({}, { __tostring = function() return "secreto" end })
function issecretvalue(v) return v == SECRET end
-- Lo que acepta valores secretos para pintarlos: se apunta qué se le pasa.
-- Con secretPaintRefused, el juego no deja (para probar ese caso).
secretPaintRefused = false
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
C_CurveUtil = { EvaluateColorFromBoolean = function(v, ifTrue, ifFalse) return { fromBoolean = v, ifTrue = ifTrue, ifFalse = ifFalse } end }
aurasSecret, aurasByIdSecret = false, false
C_UnitAuras = {
  GetBuffDataByIndex = function(_, i)
    if aurasSecret then error("GetBuffDataByIndex(): Auras cannot be accessed when secret") end
    return playerBuffs[i]
  end,
  GetPlayerAuraBySpellID = function(id)
    if aurasByIdSecret == "nil" then return nil end
    if aurasByIdSecret then error("GetPlayerAuraBySpellID(): Auras cannot be accessed when secret") end
    for _, b in ipairs(playerBuffs) do if b.spellId == id then return b end end
  end,
}
function UnitIsDeadOrGhost() return dead end
RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 } }
inGroup, groupRole = false, "NONE"
function IsInGroup() return inGroup end
function UnitGroupRolesAssigned() return groupRole end
C_AddOns = { GetAddOnMetadata = function(name, f) if name == __ADDON and f == "Version" then return "0.1.0" end end }

-- Simula un evento de WoW: lo reciben los frames con OnEvent.
function fire(event, ...)
  for _, f in ipairs(frames) do local h = rawget(f, "_OnEvent") if h then h(f, event, ...) end end
end
function runTimers() local t = timers timers = {} for _, fn in ipairs(t) do fn() end end
