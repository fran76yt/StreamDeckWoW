/*
Pruebas del addon fuera del juego
=================================

Parte de FranLib: se edita en el repositorio FranLib y se copia a la carpeta
tests/ de cada addon con su tools/sync.py.

Carga el addon como lo hace WoW (los archivos del .toc en orden, cada uno
llamado con (nombre, ns)) sobre una API del juego simulada en Lua, ejecuta
sus pruebas y escribe las SavedVariables que quedarían, para revisarlas.

Por orden, en el mismo intérprete de Lua (fengari, Lua 5.3 en JavaScript):

  1. tests/api_stubs.lua   la API de WoW simulada (compartida)
  2. tests/stubs.lua       lo que solo usa este addon, si existe (otros addons
                           de los que depende, como TradeSkillMaster)
  3. los archivos del .toc
  4. tests/test.lua        las pruebas: cada check() que pasa escribe "ok"
                           y el primero que falla para con un error

Uso, desde la carpeta tests:

  npm install      una vez, instala fengari
  npm test         ejecuta las pruebas

Las SavedVariables simuladas quedan en tests/out/<Addon>.lua (no se suben).
Ojo: WoW usa Lua 5.1 y aquí corre Lua 5.3; lo que cambia entre ambos (los
números enteros y decimales, por ejemplo) puede comportarse distinto.
*/

const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const TESTS_DIR = __dirname;

function tocIn(dir) {
  return fs.existsSync(dir) ? fs.readdirSync(dir).find((f) => f.endsWith(".toc")) : undefined;
}

// Carpeta del addon que se prueba: la de encima de tests/ si tiene .toc (un
// addon). Si no, tests/fixture/, el addon de pruebas de la propia FranLib,
// que no es un addon de verdad y no debe tener .toc en su raíz (WoW lo
// cargaría).
function findAddonDir() {
  const parent = path.resolve(TESTS_DIR, "..");
  if (tocIn(parent)) return parent;
  const fixture = path.join(TESTS_DIR, "fixture");
  if (tocIn(fixture)) return fixture;
  throw new Error("No hay ningún .toc en " + parent + " ni en " + fixture);
}

const ADDON_DIR = findAddonDir();

// El .toc de la carpeta del addon: su nombre es el del addon.
function findToc() {
  return tocIn(ADDON_DIR);
}

// Archivos que carga el .toc (las líneas que no son comentarios ni metadatos).
function tocFiles(toc) {
  return fs.readFileSync(path.join(ADDON_DIR, toc), "utf8").split(/\r?\n/)
    .map((l) => l.trim()).filter((l) => l && !l.startsWith("#"))
    .map((l) => l.replace(/\\/g, "/"));
}

// Cadena larga de Lua ([==[ ... ]==]) que no se corta con lo que lleva dentro.
function luaLong(s) {
  let eq = "=";
  while (s.includes("]" + eq + "]")) eq += "=";
  return `[${eq}[\n${s}]${eq}]`;
}

// Código Lua que carga los archivos del addon como lo hace WoW: cada uno es
// un trozo que recibe (nombre del addon, tabla compartida). El nombre del
// trozo es la ruta que daría el juego, para que los errores y las pilas se
// parezcan a las reales (Core/ErrorLog.lua las reconoce por ella).
function addonLoader(addonName, files) {
  const sources = files.map((f) =>
    `{ name = ${JSON.stringify(f)}, src = ${luaLong(fs.readFileSync(path.join(ADDON_DIR, f), "utf8"))} },`);
  return `local ns = {}
for _, f in ipairs({\n${sources.join("\n")}\n}) do
  local chunk = assert(load(f.src, "@Interface/AddOns/" .. __ADDON .. "/" .. f.name))
  chunk(__ADDON, ns)
end
`;
}

// dumpSV(): las SavedVariables del personaje (__SVNAME) como las escribe WoW.
const SERIALIZER = `
local function ser(v, ind, out)
  local t = type(v)
  if t == "table" then
    out[#out+1] = "{\\n"
    local n = #v
    for i = 1, n do out[#out+1] = ind .. "\\t" ser(v[i], ind .. "\\t", out) out[#out+1] = ", -- [" .. i .. "]\\n" end
    local ks = {}
    for k in pairs(v) do if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then ks[#ks+1] = k end end
    table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(ks) do
      out[#out+1] = ind .. "\\t[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "] = "
      ser(v[k], ind .. "\\t", out) out[#out+1] = ",\\n"
    end
    out[#out+1] = ind .. "}"
  elseif t == "string" then out[#out+1] = string.format("%q", v)
  else out[#out+1] = tostring(v) end
end
function dumpSV() local out = { "\\n" .. __SVNAME .. " = " } ser(_G[__SVNAME], "", out) out[#out+1] = "\\n" return table.concat(out) end
`;

// Ejecuta un trozo de Lua; si falla, enseña el error y sale con código 1.
function run(L, code, chunkName) {
  const status = lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring("@" + chunkName));
  if (status !== lua.LUA_OK || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
    console.error("ERROR:", lua.lua_tojsstring(L, -1));
    process.exit(1);
  }
}

function readTestFile(name) {
  const file = path.join(TESTS_DIR, name);
  return fs.existsSync(file) ? fs.readFileSync(file, "utf8") : null;
}

function writeSavedVariables(L, addonName) {
  lua.lua_getglobal(L, to_luastring("__SV"));
  if (lua.lua_isnil(L, -1)) return;
  const outFile = path.join(TESTS_DIR, "out", addonName + ".lua");
  fs.mkdirSync(path.dirname(outFile), { recursive: true });
  fs.writeFileSync(outFile, lua.lua_tojsstring(L, -1));
  console.log("SavedVariables simuladas en", path.relative(path.resolve(TESTS_DIR, ".."), outFile));
}

function main() {
  const toc = findToc();
  const addonName = path.basename(toc, ".toc");
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  run(L, `__ADDON = ${JSON.stringify(addonName)}`, "tests/run.js");
  run(L, readTestFile("api_stubs.lua"), "tests/api_stubs.lua");
  const ownStubs = readTestFile("stubs.lua");
  if (ownStubs) run(L, ownStubs, "tests/stubs.lua");
  run(L, addonLoader(addonName, tocFiles(toc)), "tests/run.js (carga del .toc)");
  run(L, SERIALIZER, "tests/run.js (SavedVariables)");
  run(L, readTestFile("test.lua"), "tests/test.lua");
  writeSavedVariables(L, addonName);
}

main();
