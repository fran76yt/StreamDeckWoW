/*
 * Constantes del plugin
 * =====================
 * Todos los valores fijos en un único sitio: identificadores, rutas, tiempos,
 * códigos de tecla, direcciones web y medidas de las imágenes.
 */

const path = require("path");
const os = require("os");

// manifest.json es la única fuente de la versión y de los identificadores.
const MANIFEST = require("../../manifest.json");
const VERSION = MANIFEST.Version;

// UUID de la acción, tal como está en manifest.json.
const ACTION_SLOT = MANIFEST.Actions[0].UUID;

// Número de huecos del addon (F1..F12).
const NUM_SLOTS = 12;

// Datos propios del plugin (registro y caché de iconos). Fuera de la carpeta
// del plugin para que sobrevivan a una reinstalación o actualización.
// Stream Deck 7.6 puede lanzar el plugin con un entorno reducido, sin APPDATA:
// en ese caso se construye a partir de la carpeta del usuario, que Node
// obtiene de Windows aunque falten las variables de entorno.
const APPDATA = process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming");
const DATA_DIR = path.join(APPDATA, "WoWDeck");
const PATHS = {
  DATA_DIR,
  ICON_DIR: path.join(DATA_DIR, "icons"),
  ICON_NAMES: path.join(DATA_DIR, "icon-names.json"),
  LOG: path.join(DATA_DIR, "plugin.log"),
  HELPER: path.join(__dirname, "..", "helper.ps1"),
};

// WoW Forever: carpeta, archivo y variable que escribe el addon.
const WOW = {
  FLAVOR_DIR: "_forever_",
  SAVED_VARIABLES_FILE: "StreamDeckWoW.lua",
  SAVED_VARIABLE: "StreamDeckWoWChar",
  // Unidades y carpetas donde se suele instalar el juego.
  DRIVES: "CDEFGH",
  INSTALL_BASES: ["Program Files (x86)", "Program Files", "Juegos", "Games", ""],
  ENV_OVERRIDE: "WOWDECK_FOREVER",   // variable de entorno para forzar la ruta (pruebas)
};

// Cada cuánto se comprueba si WoW ha reescrito el archivo. Un stat de disco
// cada 1,5 s es inapreciable y evita depender de fs.watch, que en Windows puede
// disparar varias veces o perder eventos según cómo se escriba el archivo.
const POLL_MS = 1500;

// Códigos de tecla virtual de Windows (VK_*). VK_MENU es la tecla Alt.
const VK = { SHIFT: 16, CTRL: 17, MENU: 18, F1: 112 };

// Modificadores que se mantienen pulsados con la tecla F. Tienen que coincidir
// con Const.KEY_MODIFIERS del addon (Core/Constants.lua).
const MODIFIERS = [VK.CTRL, VK.MENU, VK.SHIFT];

// Wowhead: API de tooltips (da el nombre del icono) y CDN de imágenes.
const WOWHEAD = {
  TOOLTIP_URL: (kind, id) => `https://nether.wowhead.com/forever/tooltip/${kind}/${id}`,
  ICON_URL: (name) => `https://wow.zamimg.com/images/wow/icons/large/${name}.jpg`,
  HEADERS: { "User-Agent": `WoWDeck-StreamDeck-plugin/${VERSION}` },
};

// Imágenes de las teclas.
const IMAGE = {
  SIZE: 144,                 // tamaño de tecla a doble resolución
  BLANK_COLOR: "#111",
  TEXT_BACKGROUND: "#1d1d24",
  TEXT_COLOR: "#cfcfd8",
};

// Títulos: caracteres por línea (las teclas son pequeñas).
const TITLE_LINE_LENGTH = 10;

module.exports = { VERSION, ACTION_SLOT, NUM_SLOTS, PATHS, WOW, POLL_MS, VK, MODIFIERS, WOWHEAD, IMAGE, TITLE_LINE_LENGTH };
