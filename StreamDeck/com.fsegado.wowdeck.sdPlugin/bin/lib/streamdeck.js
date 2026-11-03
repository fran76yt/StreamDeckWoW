/*
 * Conexión con la aplicación de Stream Deck
 * =========================================
 * Envoltorio mínimo y reutilizable del protocolo de plugins (SDK 2), sin nada
 * específico de WoW. Sirve para cualquier plugin en Node.
 *
 * Cómo funciona el protocolo:
 *   1. La aplicación lanza el plugin con argumentos:
 *        -port 28196 -pluginUUID ... -registerEvent registerPlugin -info {...}
 *   2. El plugin abre un WebSocket a 127.0.0.1:<port> y lo primero que envía es
 *      { event: <registerEvent>, uuid: <pluginUUID> } para identificarse.
 *   3. A partir de ahí todo son mensajes JSON:
 *        aplicación -> plugin: willAppear, willDisappear, keyDown, didReceiveSettings...
 *        plugin -> aplicación: setImage, setTitle, showAlert...
 *      Cada tecla visible tiene un "context" (identificador opaco) que se usa
 *      para dirigirle los mensajes.
 *
 * Esta clase emite cada mensaje recibido como un evento con su nombre
 * (sd.on("keyDown", msg => ...)), además de "connected" y "closed".
 */

const { EventEmitter } = require("events");
const WebSocket = require("ws"); // Node 20 aún no trae cliente WebSocket estable

// Convierte ["-port", "123", "-info", "{}"] en { port: "123", info: "{}" }.
function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length - 1; i += 2) args[argv[i].replace(/^-/, "")] = argv[i + 1];
  return args;
}

class StreamDeck extends EventEmitter {
  constructor(argv = process.argv.slice(2)) {
    super();
    this.args = parseArgs(argv);
    this.ws = null;
  }

  // Conecta y se registra. Los mensajes llegan como eventos.
  connect() {
    this.ws = new WebSocket(`ws://127.0.0.1:${this.args.port}`);
    this.ws.on("open", () => {
      this.send({ event: this.args.registerEvent, uuid: this.args.pluginUUID });
      this.emit("connected");
    });
    this.ws.on("message", (raw) => {
      const msg = JSON.parse(raw);
      this.emit(msg.event, msg);
    });
    this.ws.on("close", () => this.emit("closed"));
    return this;
  }

  send(obj) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) this.ws.send(JSON.stringify(obj));
  }

  // target 0 = en el dispositivo y en la aplicación a la vez.
  setImage(context, image) {
    this.send({ event: "setImage", context, payload: { image, target: 0 } });
  }

  setTitle(context, title) {
    this.send({ event: "setTitle", context, payload: { title, target: 0 } });
  }

  // Triángulo amarillo de aviso sobre la tecla.
  showAlert(context) {
    this.send({ event: "showAlert", context });
  }
}

module.exports = { StreamDeck, parseArgs };
