/*
 * Acceso a la instalación de WoW
 * ==============================
 * Localizar WoW Forever y sus SavedVariables, y leerlas.
 */

const fs = require("fs");
const path = require("path");
const { WOW } = require("./constants");
const { parseAssignment } = require("./luatable");

// Subcarpetas de una carpeta (vacío si no existe).
function subdirs(dir) {
  try {
    return fs.readdirSync(dir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name);
  } catch {
    return [];
  }
}

// Rutas candidatas a la carpeta _forever_, por orden de preferencia:
//   1. La variable de entorno WOWDECK_FOREVER (útil para pruebas).
//   2. Si el plugin está dentro de ...\_forever_\Interface\AddOns\..., esa
//      misma instalación (es el caso durante el desarrollo, con un enlace).
//   3. Las rutas de instalación habituales en cada unidad.
function candidateDirs(pluginDir) {
  const tries = [];
  if (process.env[WOW.ENV_OVERRIDE]) tries.push(process.env[WOW.ENV_OVERRIDE]);
  let real = pluginDir;
  try { real = fs.realpathSync(pluginDir); } catch {} // resuelve el enlace de desarrollo
  const m = new RegExp(`^(.*[\\\\/]${WOW.FLAVOR_DIR})[\\\\/]Interface[\\\\/]`, "i").exec(real);
  if (m) tries.push(m[1]);
  for (const drive of WOW.DRIVES) {
    for (const base of WOW.INSTALL_BASES) tries.push(path.join(`${drive}:\\`, base, "World of Warcraft", WOW.FLAVOR_DIR));
  }
  return tries;
}

// Primera candidata con carpeta WTF (la crea el juego al arrancar).
function findForever(pluginDir) {
  return candidateDirs(pluginDir).find((p) => fs.existsSync(path.join(p, "WTF")));
}

// Las SavedVariables por personaje viven en
//   WTF\Account\<cuenta>\<reino>\<personaje>\SavedVariables\StreamDeckWoW.lua
// Devuelve la guardada más recientemente ({ file, mtime, character }). Así un
// único perfil sirve para todas las clases. Ojo: WoW escribe el archivo de un
// personaje al recargar, cerrar sesión o salir, no al entrar; tras cambiar de
// personaje, hasta que el nuevo haga /reload se sigue viendo el anterior.
function newestSavedVariables(forever) {
  const accounts = path.join(forever, "WTF", "Account");
  let best = null;
  for (const account of subdirs(accounts)) {
    for (const realm of subdirs(path.join(accounts, account))) {
      for (const character of subdirs(path.join(accounts, account, realm))) {
        const file = path.join(accounts, account, realm, character, "SavedVariables", WOW.SAVED_VARIABLES_FILE);
        try {
          const { mtimeMs } = fs.statSync(file);
          if (!best || mtimeMs > best.mtime) best = { file, mtime: mtimeMs, character: `${character}-${realm}` };
        } catch {} // ese personaje no usa el addon
      }
    }
  }
  return best;
}

// Lee la variable del addon de un archivo de SavedVariables.
function readAddonData(file) {
  return parseAssignment(fs.readFileSync(file, "utf8"), WOW.SAVED_VARIABLE);
}

module.exports = { findForever, newestSavedVariables, readAddonData };
