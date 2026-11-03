/*
 * WoW Deck - plugin de Stream Deck para el addon StreamDeck WoW
 * ==============================================================
 *
 * Punto de entrada: crea las piezas y las conecta entre sí. La lógica está en
 * lib/, cada parte en su archivo:
 *
 *   constants.js   valores fijos (rutas, tiempos, teclas, URLs)
 *   log.js         registro a archivo
 *   streamdeck.js  conexión con la aplicación de Stream Deck (genérico)
 *   helper.js      proceso auxiliar de Windows: teclas e imágenes (genérico)
 *   luatable.js    lector del formato de las SavedVariables (genérico)
 *   wow.js         localizar WoW y leer las SavedVariables del addon
 *   watcher.js     avisar cuando WoW reescribe las SavedVariables
 *   icons.js       iconos de Wowhead con caché en disco
 *   images.js      imágenes para las teclas
 *   text.js        utilidades de texto
 *   slotAction.js  la acción "Hueco WoW": pintar y pulsar
 *
 * Flujo:
 *   juego --(/reload escribe SavedVariables)--> watcher --> slotAction --> teclas
 *   tecla pulsada --> slotAction --> helper --(Ctrl+Alt+Mayús+Fn)--> juego --> addon
 */

const { VERSION, ACTION_SLOT, PATHS, POLL_MS } = require("./lib/constants");
const { createLogger } = require("./lib/log");
const { StreamDeck } = require("./lib/streamdeck");
const { Helper } = require("./lib/helper");
const { IconCache } = require("./lib/icons");
const { findForever } = require("./lib/wow");
const { SavedVariablesWatcher } = require("./lib/watcher");
const { SlotAction } = require("./lib/slotAction");

const log = createLogger(PATHS.LOG);
const sd = new StreamDeck();
const helper = new Helper(PATHS.HELPER, log);
const icons = new IconCache({
  dir: PATHS.ICON_DIR,
  namesFile: PATHS.ICON_NAMES,
  dim: (input, output) => helper.dimImage(input, output),
});
const slotAction = new SlotAction({ sd, icons, press: (vks) => helper.pressKeys(vks), log });

// Solo atendemos los mensajes de nuestra acción.
const forSlots = (handler) => (msg) => { if (msg.action === ACTION_SLOT) handler(msg); };

function startWatching() {
  const forever = findForever(__dirname);
  if (!forever) return log("no encuentro la carpeta _forever_ de WoW");
  log("WoW Forever en", forever);
  new SavedVariablesWatcher(forever, POLL_MS, log)
    .on("change", (data) => slotAction.setData(data))
    .start();
}

sd.on("connected", () => {
  log(`WoW Deck ${VERSION} conectado a Stream Deck (datos en ${PATHS.DATA_DIR})`);
  helper.start();
  startWatching();
});
sd.on("willAppear", forSlots((m) => slotAction.onAppear(m)));
sd.on("didReceiveSettings", forSlots((m) => slotAction.onAppear(m)));
sd.on("willDisappear", forSlots((m) => slotAction.onDisappear(m)));
sd.on("keyDown", forSlots((m) => slotAction.onKeyDown(m)));

// Stream Deck cierra el socket al salir o al desactivar el plugin: terminamos
// (y con nosotros el helper, que se cierra al perder su entrada estándar).
sd.on("closed", () => { log("Stream Deck cerró la conexión"); process.exit(0); });

// Cualquier error no previsto queda en el registro en lugar de tumbar el plugin.
process.on("uncaughtException", (e) => log("error:", e.stack || e.message));
process.on("unhandledRejection", (e) => log("error:", (e && e.stack) || e));

sd.connect();
